// Phoenix login screen (2026-10-08, ours). Runs under greetd as the "greeter" user inside the cage compositor:
//   cage -s -m last -- qs -p /usr/share/phoenix-greeter/greeter.qml      (set up by `phoenix login-screen install`)
// Look: the theme the last user's desktop copied to /var/lib/phoenix-greeter/theme (colors.json from Phoenix's
// wallpaper colors, the wallpaper, the account picture; written at each login by phoenix-greeter-theme).
// Remembers the last user and session in /var/lib/phoenix-greeter/state/last.json (owned by the greeter user).
// An empty password is never sent (each attempt counts towards the account lockout).
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

ShellRoot {
    id: root

    // PHOENIX_GREETER_THEME / _STATE: only for a preview outside greetd
    readonly property string themeDir: Quickshell.env("PHOENIX_GREETER_THEME") || "/var/lib/phoenix-greeter/theme"
    readonly property string stateFile: Quickshell.env("PHOENIX_GREETER_STATE") || "/var/lib/phoenix-greeter/state/last.json"
    property var colors: ({})
    function col(name, fallback) { return root.colors[name] || fallback }
    readonly property color cBg: col("surface", "#141218")
    readonly property color cCard: col("surface_container", "#211f26")
    readonly property color cCardHi: col("surface_container_high", "#2b2930")
    readonly property color cText: col("on_surface", "#e6e0e9")
    readonly property color cSub: col("on_surface_variant", "#cac4d0")
    readonly property color cPrimary: col("primary", "#d0bcff")
    readonly property color cOnPrimary: col("on_primary", "#381e72")
    // over the darkened wallpaper: always light text, and "fixed" accent colors (the same in light and dark schemes)
    readonly property color cOnWall: "#f4eff4"
    readonly property color cAccent: col("primary_fixed", "#eaddff")
    readonly property color cOnAccent: col("on_primary_fixed", "#21005d")
    readonly property color cError: col("error", "#f2b8b5")
    readonly property string fontMain: "Google Sans Flex"
    readonly property string fontIcons: "Material Symbols Rounded"

    property var users: []            // [{name, real}] from /etc/passwd: uid 1000-59999 with a login shell
    property int userIndex: 0
    readonly property var user: users[userIndex] ?? null
    property var sessions: [{ id: "hyprland", name: "Phoenix (Hyprland)" }]
    property int sessionIndex: 0
    property string message: ""
    property bool messageIsError: false
    property bool busy: false
    property string pendingPassword: ""
    property var last: ({})

    // ── data ──
    FileView {
        path: root.themeDir + "/colors.json"
        printErrors: false
        onLoaded: { try { root.colors = JSON.parse(text()) } catch (e) {} }
    }
    FileView {
        path: "/etc/passwd"
        onLoaded: {
            const list = []
            for (const line of text().split("\n")) {
                const f = line.split(":")
                const uid = Number(f[2])
                if (f.length >= 7 && uid >= 1000 && uid < 60000 && !/(nologin|false)$/.test(f[6]))
                    list.push({ name: f[0], real: (f[4] || "").split(",")[0] })
            }
            root.users = list
            root.pickLast()
        }
    }
    FileView {   // switch-desktop's choice for the next sign-in (Settings › "Switch to KDE"), else the last one used
        path: root.themeDir + "/next-session"
        printErrors: false
        onLoaded: { root.nextSession = text().trim(); root.pickLast() }
    }
    property string nextSession: ""
    property string clockFormat: "hh:mm"
    FileView {
        path: root.themeDir + "/clock.json"
        printErrors: false
        onLoaded: { try { root.clockFormat = JSON.parse(text()).format || "hh:mm" } catch (e) {} }
    }
    FileView {
        id: stateView
        path: root.stateFile
        printErrors: false
        onLoaded: { try { root.last = JSON.parse(text()) } catch (e) {} root.pickLast() }
    }
    Process {   // KDE Plasma is offered only where it's installed
        running: true
        command: ["test", "-x", "/usr/bin/startplasma-wayland"]
        onExited: code => {
            if (code === 0) root.sessions = root.sessions.concat([{ id: "plasma", name: "KDE Plasma" }])
            root.pickLast()
        }
    }
    function pickLast() {
        const ui = root.users.findIndex(u => u.name === root.last.user)
        if (ui >= 0) root.userIndex = ui
        const si = root.sessions.findIndex(s => s.id === (root.nextSession || root.last.session))
        if (si >= 0) root.sessionIndex = si
    }

    // ── signing in ──
    function signIn(fromButton = false) {
        if (!root.user || root.busy) return
        // an empty Enter is no attempt (each counts towards the lockout); the arrow button still signs in with an empty
        // password, for accounts that have none (QA 2026-10-08)
        if (passwordField.text.length === 0 && !fromButton) { passwordField.forceActiveFocus(); return }
        root.busy = true
        root.message = ""
        root.pendingPassword = passwordField.text
        Greetd.createSession(root.user.name)
    }
    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.pendingPassword)
                root.pendingPassword = ""
            } else if (message) {
                root.message = message
                root.messageIsError = error
            }
        }
        function onReadyToLaunch() {
            const s = root.sessions[root.sessionIndex]
            stateView.setText(JSON.stringify({ user: root.user.name, session: s.id }))
            root.message = "Signing in…"
            root.messageIsError = false
            Greetd.launch(["/usr/local/bin/phoenix-session", s.id], ["XDG_SESSION_TYPE=wayland"], true)
        }
        function onAuthFailure(message) {
            justFailed.restart()
            root.busy = false
            root.pendingPassword = ""
            // faillock answers every attempt while the account is locked; its notice came as an info message
            const locked = /lock/i.test(root.message)
            const mins = (root.message.match(/(\d+)\s*minute/) || [])[1]
            root.message = locked ? `Too many attempts. Try again in ${mins ? mins + " minute" + (mins === "1" ? "" : "s") : "a few minutes"}.`
                                  : "That password isn't right. Try again."
            root.messageIsError = true
            passwordField.text = ""
            passwordField.forceActiveFocus()
            shake.restart()
        }
        function onError(error) {
            // after a wrong password Quickshell cancels the session greetd already closed; that "error" isn't one
            if (justFailed.running) return
            root.busy = false
            root.pendingPassword = ""
            root.message = "Couldn't sign in: " + error
            root.messageIsError = true
            Greetd.cancelSession()
        }
    }

    Timer { id: justFailed; interval: 2000 }

    // ── screen ──
    FloatingWindow {
        id: win
        visible: true
        color: root.cBg

        Image {
            id: wallpaper
            anchors.fill: parent
            source: "file://" + root.themeDir + "/wallpaper"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: win.width   // no need to keep a 4K picture in memory for a blurred background
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.8
                blurMax: 48
                brightness: -0.25
            }
        }

        ColumnLayout {   // clock
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.12 }
            spacing: 0
            Text {
                id: clock
                Layout.alignment: Qt.AlignHCenter
                font { family: root.fontMain; pixelSize: 112; weight: Font.Medium }
                color: root.cOnWall
            }
            Text {
                id: date
                Layout.alignment: Qt.AlignHCenter
                font { family: root.fontMain; pixelSize: 24 }
                color: root.cOnWall
                opacity: 0.85
            }
            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    const now = new Date()
                    clock.text = now.toLocaleTimeString(Qt.locale(), root.clockFormat)
                    date.text = now.toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                }
            }
        }

        ColumnLayout {   // the user and the password
            id: card
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: parent.height * 0.08 }
            spacing: 14

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 120; implicitHeight: 120; radius: 60
                color: root.cAccent
                Text {
                    anchors.centerIn: parent
                    text: (root.user?.real || root.user?.name || "?").charAt(0).toUpperCase()
                    font { family: root.fontMain; pixelSize: 52; weight: Font.Medium }
                    color: root.cOnAccent
                }
                Image {   // the account picture, when there is one
                    id: face
                    anchors.fill: parent
                    // each user's own picture; the plain "face" (the last user's) only for that user (QA 2026-10-08)
                    source: root.user ? "file://" + root.themeDir + "/face-" + root.user.name : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                Rectangle { id: faceMask; anchors.fill: parent; radius: 60; visible: false; layer.enabled: true }
                MultiEffect {
                    anchors.fill: parent
                    source: face
                    visible: face.status === Image.Ready
                    maskEnabled: true
                    maskSource: faceMask
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.user ? (root.user.real || root.user.name) : "No users"
                font { family: root.fontMain; pixelSize: 30; weight: Font.Medium }
                color: root.cOnWall
            }

            Rectangle {
                id: field
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 340; implicitHeight: 52; radius: 26
                color: Qt.alpha(root.cCard, 0.9)
                border { width: passwordField.activeFocus ? 2 : 1; color: passwordField.activeFocus ? root.cPrimary : Qt.alpha(root.cText, 0.15) }
                transform: Translate { id: shakeX }
                SequentialAnimation {   // a wrong password shakes the field
                    id: shake
                    NumberAnimation { target: shakeX; property: "x"; to: -12; duration: 50 }
                    NumberAnimation { target: shakeX; property: "x"; to: 12; duration: 70 }
                    NumberAnimation { target: shakeX; property: "x"; to: -8; duration: 70 }
                    NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60 }
                }
                RowLayout {
                    anchors { fill: parent; leftMargin: 20; rightMargin: 6 }
                    TextField {
                        id: passwordField
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: "Password"
                        placeholderTextColor: root.cSub
                        color: root.cText
                        font { family: root.fontMain; pixelSize: 18 }
                        enabled: !root.busy
                        focus: true
                        background: null
                        onAccepted: root.signIn()
                        Component.onCompleted: forceActiveFocus()
                    }
                    Rectangle {
                        implicitWidth: 40; implicitHeight: 40; radius: 20
                        color: root.busy ? Qt.alpha(root.cPrimary, 0.5) : root.cPrimary
                        Text {
                            anchors.centerIn: parent
                            text: root.busy ? "hourglass_top" : "arrow_forward"
                            font { family: root.fontIcons; pixelSize: 24 }
                            color: root.cOnPrimary
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.signIn(true) }
                    }
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 420
                visible: root.message !== ""
                text: root.message
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font { family: root.fontMain; pixelSize: 16 }
                color: root.messageIsError ? "#ffb4ab" : root.cOnWall
            }
        }

        RowLayout {   // other users, bottom left
            visible: root.users.length > 1
            anchors { left: parent.left; bottom: parent.bottom; margins: 28 }
            spacing: 8
            Repeater {
                model: root.users
                Rectangle {
                    required property var modelData
                    required property int index
                    implicitHeight: 44; implicitWidth: userLabel.implicitWidth + 32; radius: 22
                    color: index === root.userIndex ? root.cAccent : Qt.alpha(root.cCard, 0.85)
                    Text {
                        id: userLabel
                        anchors.centerIn: parent
                        text: modelData.real || modelData.name
                        font { family: root.fontMain; pixelSize: 16 }
                        color: index === root.userIndex ? root.cOnAccent : root.cText
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.userIndex = index; root.message = ""; passwordField.text = ""; passwordField.forceActiveFocus() }
                    }
                }
            }
        }

        RowLayout {   // session and power, bottom right
            anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
            spacing: 10
            Rectangle {
                visible: root.sessions.length > 1
                implicitHeight: 44; implicitWidth: sessionLabel.implicitWidth + 64; radius: 22
                color: Qt.alpha(root.cCard, 0.85)
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "desktop_windows"; font { family: root.fontIcons; pixelSize: 20 } color: root.cText }
                    Text { id: sessionLabel; text: root.sessions[root.sessionIndex]?.name ?? ""; font { family: root.fontMain; pixelSize: 16 } color: root.cText }
                }
                MouseArea {   // click to switch between the sessions
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sessionIndex = (root.sessionIndex + 1) % root.sessions.length
                }
            }
            Repeater {
                model: [{ icon: "restart_alt", cmd: "reboot" }, { icon: "power_settings_new", cmd: "poweroff" }]
                Rectangle {
                    required property var modelData
                    implicitWidth: 44; implicitHeight: 44; radius: 22
                    color: Qt.alpha(root.cCard, 0.85)
                    Text { anchors.centerIn: parent; text: modelData.icon; font { family: root.fontIcons; pixelSize: 22 } color: root.cText }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["systemctl", modelData.cmd]) }
                }
            }
        }
    }
}
