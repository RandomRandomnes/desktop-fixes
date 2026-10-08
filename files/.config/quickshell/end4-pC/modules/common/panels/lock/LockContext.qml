import qs
import qs.modules.common
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

    function tryUnlock(alsoInhibitIdle = false) {
        // Phoenix (2026-10-08): Enter on an empty field (e.g. to wake the screen) isn't a login attempt. Each one used
        // to count as a wrong password, and three lock the account for 10 minutes (pam_faillock), even for the right one.
        if (root.currentText.length === 0) return;
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
                const info = root.lastPamInfo;
                const mins = (info.match(/(\d+)\s*minute/) || [])[1];
                root.failureMessage = /lock/i.test(info)
                    ? `Too many attempts. Try again in ${mins ? mins + " minute" + (mins === "1" ? "" : "s") : "a few minutes"}`
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
