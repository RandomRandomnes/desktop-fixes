import qs
import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Scope {
    id: root

    enum ActionEnum { Unlock, Poweroff, Reboot }

    signal shouldReFocus()
    signal unlocked(targetAction: var)
    signal failed()

    // These properties are in the context and not individual lock surfaces
    // so all surfaces can share the same state.
    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property bool fingerprintsConfigured: false
    // Phoenix (2026-10-08): what the system said when the last attempt failed, e.g. that the account is locked for
    // a few minutes after too many wrong passwords (pam_faillock); "" = just a wrong password
    property string failureMessage: ""
    property string lastPamInfo: ""
    property var targetAction: LockContext.ActionEnum.Unlock
    property bool alsoInhibitIdle: false

    function resetTargetAction() {
        root.targetAction = LockContext.ActionEnum.Unlock;
    }

    function clearText() {
        root.currentText = "";
    }

    function resetClearTimer() {
        passwordClearTimer.restart();
    }

    function reset() {
        root.resetTargetAction();
        root.clearText();
        root.unlockInProgress = false;
        stopFingerPam();
    }

    Timer {
        id: passwordClearTimer
        interval: 10000
        onTriggered: {
            root.reset();
        }
    }

    onCurrentTextChanged: {
        if (currentText.length > 0) {
            showFailure = false;
            GlobalStates.screenUnlockFailed = false;
        }
        GlobalStates.screenLockContainsCharacters = currentText.length > 0;
        passwordClearTimer.restart();
    }

    function tryUnlock(alsoInhibitIdle = false, allowEmpty = false) {
        // Phoenix (2026-10-08): Enter on an empty field (e.g. to wake the screen) isn't a login attempt. Each one used
        // to count as a wrong password, and three lock the account for 10 minutes (pam_faillock), even for the right one.
        // The arrow button still tries an empty password, for accounts that have none.
        if (root.currentText.length === 0 && !allowEmpty) return;
        root.alsoInhibitIdle = alsoInhibitIdle;
        root.lastPamInfo = "";
        root.unlockInProgress = true;

        stopFingerPam();

        pam.start();
    }

    function tryFingerUnlock() {
        if (root.fingerprintsConfigured) {
            fingerPam.start();
        }
    }

    function stopFingerPam() {
        if (fingerPam.active) {
            fingerPam.abort();
        }
    }

    Process {
        id: fingerprintCheckProc
        running: true
        command: ["bash", "-c", "fprintd-list $(whoami)"]
        stdout: StdioCollector {
            id: fingerprintOutputCollector
            onStreamFinished: {
                root.fingerprintsConfigured = fingerprintOutputCollector.text.includes("Fingerprints for user");
                root.tryFingerUnlock();
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // console.warn("[LockContext] fprintd-list command exited with error:", exitCode, exitStatus);
                root.fingerprintsConfigured = false;
            }
        }
    }
    
    PamContext {
        id: pam

        // pam_unix will ask for a response for the password prompt
        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentText);
            } else if (this.message) {
                root.lastPamInfo += " " + this.message;   // Phoenix: e.g. faillock's "The account is locked ..."
            }
        }

        // pam_unix won't send any important messages so all we need is the completion status.
        onCompleted: result => {
            if (result == PamResult.Success) {
                root.unlocked(root.targetAction);
            } else {
                root.clearText();
                root.unlockInProgress = false;
                // Phoenix: tell a lockout apart from a wrong password (faillock answers every attempt while it lasts)
                // Any notice that came with the failure means locked: pam_unix sends none for a wrong password, and the
                // notice is in the system's language (L22). Minutes: the number before "minute", else the last number
                // ("… due to 3 failed logins. (10 minutes left to unlock)").
                const info = root.lastPamInfo.trim();
                const nums = info.match(/\d+/g) || [];
                const mins = (info.match(/(\d+)\s*minute/i) || [])[1] ?? nums[nums.length - 1];
                root.failureMessage = info !== ""
                    ? (mins ? (mins === "1" ? Translation.tr("Too many attempts. Try again in 1 minute")
                                            : Translation.tr("Too many attempts. Try again in %1 minutes").arg(mins))
                            : Translation.tr("Too many attempts. Try again in a few minutes"))
                    : "";
                GlobalStates.screenUnlockFailed = true;
                root.showFailure = true;

                root.tryFingerUnlock();
            }
        }
    }

    PamContext {
        id: fingerPam

        configDirectory: "pam"
        config: "fprintd.conf"

        onCompleted: result => {
            if (result == PamResult.Success) {
                root.unlocked(root.targetAction);
                stopFingerPam();
            } else if (result == PamResult.Error) { // if timeout or etc..
                tryFingerUnlock()
            }
        }
    }
}
