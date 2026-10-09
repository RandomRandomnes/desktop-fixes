//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import qs.modules.ii.settings

// Windows 11 style settings window. Replaces modules/ii/settings/Settings.qml in the panel family;
// the original settings stay reachable as "Advanced settings" (embedded SettingsContent).
Scope {
    id: root

    // A normal app window (2026-10-03; was a full-screen overlay that closed when you clicked anywhere else):
    // it stays open while you use other windows, and moves/closes like any other window.
    FloatingWindow {
        id: panelWindow
        visible: GlobalStates.settingsOpen
        title: "Settings"
        color: Appearance.colors.colLayer0
        // fits smaller screens (2026-10-08): on a 1280×800 screen the 820 px window hid its header (back arrow) under the bar.
        // Worked out when Settings opens (not live: it resized when focus moved to another screen), with width and height
        // swapped on a rotated (portrait) screen.
        property real monW: 1920
        property real monH: 1080
        function measure() {
            const mon = Hyprland.focusedMonitor
            const o = mon?.lastIpcObject ?? {}
            if (!mon) return
            const portrait = [1, 3, 5, 7].includes(o.transform ?? 0)
            const scale = o.scale || mon.scale || 1
            const w = (o.width ?? mon.width) / scale, h = (o.height ?? mon.height) / scale
            panelWindow.monW = portrait ? h : w
            panelWindow.monH = portrait ? w : h
        }
        implicitWidth: Math.min(1240, monW - 40)
        implicitHeight: Math.min(820, monH - 120)
        // measured while Settings is closed, so the size is right before the window appears (measuring when it became
        // visible came too late: it stayed 1240×820 on an 800 px screen; QA 2026-10-09)
        Component.onCompleted: measure()
        Connections {
            target: Hyprland
            function onFocusedMonitorChanged() { if (!panelWindow.visible) panelWindow.measure() }
        }
        Connections {
            target: GlobalStates
            function onSettingsOpenChanged() { if (GlobalStates.settingsOpen) panelWindow.measure() }
        }

        function hide() {
            GlobalStates.settingsOpen = false;
        }

        onVisibleChanged: {
            if (visible) {
                win.forceActiveFocus();
            } else {
                GlobalStates.settingsOpen = false;   // closed by the window manager (title bar ✕, Super+Q)
                searchField.text = "";
            }
        }

        Rectangle {
            id: win
            anchors.fill: parent
            color: Appearance.colors.colLayer0
            clip: true
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (searchField.text.length > 0) searchField.text = "";
                    else panelWindow.hide();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Back || (event.key === Qt.Key_Left && (event.modifiers & Qt.AltModifier))) {
                    WState.back();
                    event.accepted = true;
                } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                    searchField.forceActiveFocus();
                    event.accepted = true;
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── Title bar ───────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 46

                    // The window has no system title bar (hypr/custom/rules.lua "settings-no-titlebar"): drag this
                    // header to move it (Wayland interactive move), double-click to maximize/restore.
                    MouseArea {
                        // the move starts only once the mouse moves, so a double-click still reaches onDoubleClicked
                        property point pressAt
                        anchors.fill: parent
                        onPressed: mouse => pressAt = Qt.point(mouse.x, mouse.y)
                        onPositionChanged: mouse => {
                            if (pressed && Math.abs(mouse.x - pressAt.x) + Math.abs(mouse.y - pressAt.y) > 4)
                                win.Window.window.startSystemMove()
                        }
                        onDoubleClicked: Quickshell.execDetached(["hyprctl", "dispatch",
                            'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })'])
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 8

                        RippleButton {
                            visible: WState.canGoBack
                            implicitWidth: 38
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.verysmall
                            onClicked: WState.back()
                            contentItem: MaterialSymbol {
                                text: "arrow_back"
                                iconSize: 20
                                horizontalAlignment: Text.AlignHCenter
                                color: Appearance.colors.colOnLayer0
                            }
                        }
                        MaterialSymbol {
                            Layout.leftMargin: WState.canGoBack ? 0 : 6
                            text: "settings"
                            iconSize: 18
                            fill: 1
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: WState.advanced ? "Settings  ·  Advanced" : "Settings"
                            font.pixelSize: Appearance.font.pixelSize.smallie
                            color: Appearance.colors.colOnLayer0
                        }
                        Item { Layout.fillWidth: true }
                        RippleButton {
                            implicitWidth: 44
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.verysmall
                            colBackgroundHover: Appearance.colors.colErrorContainer
                            onClicked: panelWindow.hide()
                            contentItem: MaterialSymbol {
                                text: "close"
                                iconSize: 20
                                horizontalAlignment: Text.AlignHCenter
                                color: Appearance.colors.colOnLayer0
                            }
                        }
                    }
                }

                // ── Body ─────────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.bottomMargin: 8
                        spacing: 0
                        visible: !WState.advanced

                        // Navigation pane
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 290
                            Layout.maximumWidth: 290
                            Layout.minimumWidth: 290
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            spacing: 6

                            // Profile card → Accounts
                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 82
                                buttonRadius: Appearance.rounding.small
                                onClicked: WState.go("accounts")
                                contentItem: RowLayout {
                                    spacing: 14
                                    UserAvatar {
                                        Layout.leftMargin: 6
                                        implicitWidth: 60
                                        implicitHeight: 60
                                    }
                                    ColumnLayout {
                                        spacing: 0
                                        Layout.fillWidth: true
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: Config.options.profile.displayName || SystemInfo.username
                                            font.pixelSize: Appearance.font.pixelSize.large
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colOnLayer0
                                            elide: Text.ElideRight
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: `Local account · ${SystemInfo.hostname || SystemInfo.distroName}`
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            // Search box
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                Layout.bottomMargin: 8
                                implicitHeight: 38
                                radius: Appearance.rounding.verysmall
                                color: Appearance.colors.colLayer1
                                border.width: searchField.activeFocus ? 2 : 0
                                border.color: Appearance.colors.colPrimary

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                                    spacing: 8
                                    TextField {
                                        id: searchField
                                        Layout.fillWidth: true
                                        placeholderText: "Find a setting"
                                        placeholderTextColor: Appearance.colors.colSubtext
                                        color: Appearance.colors.colOnLayer1
                                        font.family: Appearance.font.family.main
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        background: null
                                        selectByMouse: true
                                        Keys.onReturnPressed: {
                                            const r = searchPopup.results;
                                            if (r.length > 0) searchPopup.open(r[0]);
                                        }
                                        Keys.onEscapePressed: text = ""
                                    }
                                    MaterialSymbol {
                                        text: "search"
                                        iconSize: 18
                                        color: Appearance.colors.colSubtext
                                    }
                                }
                            }

                            // Categories
                            ListView {
                                id: navList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 2
                                boundsBehavior: Flickable.StopAtBounds
                                model: WState.categories
                                delegate: RippleButton {
                                    id: navItem
                                    required property var modelData
                                    readonly property bool current: WState.page === modelData.id
                                    width: navList.width
                                    implicitHeight: 40
                                    buttonRadius: Appearance.rounding.verysmall
                                    colBackground: current ? Appearance.colors.colLayer1 : "transparent"
                                    colBackgroundHover: current ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer0Hover
                                    onClicked: {
                                        WState.history = [];
                                        WState.go(modelData.id);
                                        WState.history = [];
                                    }
                                    contentItem: Item {
                                        // the Windows 11 accent pill on the selected item
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: -2
                                            width: 3
                                            height: navItem.current ? 16 : 0
                                            radius: 2
                                            color: Appearance.colors.colPrimary
                                            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        }
                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 12 }
                                            spacing: 14
                                            MaterialSymbol {
                                                text: navItem.modelData.icon
                                                iconSize: 20
                                                fill: navItem.current ? 1 : 0
                                                color: Appearance.colors.colPrimary
                                            }
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: navItem.modelData.name
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                font.weight: navItem.current ? Font.DemiBold : Font.Normal
                                                color: Appearance.colors.colOnLayer0
                                            }
                                        }
                                    }
                                }
                            }
                            // Way back to the full original illogical-impulse settings
                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 40
                                buttonRadius: Appearance.rounding.verysmall
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer0Hover
                                onClicked: WState.go("advanced")
                                contentItem: RowLayout {
                                    anchors { fill: parent; leftMargin: 12 }
                                    spacing: 14
                                    MaterialSymbol { text: "tune"; iconSize: 20; color: Appearance.colors.colSubtext }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: "Advanced settings"
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colSubtext
                                    }
                                    MaterialSymbol { text: "chevron_right"; iconSize: 18; color: Appearance.colors.colSubtext; Layout.rightMargin: 8 }
                                }
                            }
                        }

                        // Content pane
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.rightMargin: 22
                            spacing: 14

                            // Breadcrumb title
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                spacing: 10
                                StyledText {
                                    id: crumbRoot
                                    text: WState.categoryName(WState.page)
                                    font.pixelSize: 30
                                    font.weight: Font.DemiBold
                                    color: WState.sub ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer0
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: WState.sub !== ""
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: WState.go(WState.page, "")
                                        onContainsMouseChanged: crumbRoot.opacity = containsMouse ? 0.8 : 1
                                    }
                                }
                                MaterialSymbol {
                                    visible: WState.sub !== ""
                                    text: "chevron_right"
                                    iconSize: 26
                                    color: Appearance.colors.colSubtext
                                }
                                StyledText {
                                    visible: WState.sub !== ""
                                    Layout.fillWidth: true
                                    text: WState.subTitle(WState.page, WState.sub)
                                    font.pixelSize: 30
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                }
                                Item { Layout.fillWidth: WState.sub === "" }
                            }

                            Loader {
                                id: pageLoader
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                active: GlobalStates.settingsOpen || item !== null
                                source: {
                                    const p = WState.page;
                                    return `P${p.charAt(0).toUpperCase()}${p.slice(1)}.qml`;
                                }
                                opacity: status === Loader.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            }
                        }
                    }

                    // Advanced: the original illogical-impulse settings, untouched
                    SettingsContent {
                        id: legacy
                        anchors.fill: parent
                        anchors.margins: 4
                        visible: WState.advanced
                        enabled: visible
                    }

                    // Search results flyout
                    Rectangle {
                        id: searchPopup
                        property var results: WState.search(searchField.text)
                        function open(r) {
                            searchField.text = "";
                            WState.go(r.page, r.sub);
                        }
                        visible: searchField.text.length > 0 && !WState.advanced
                        x: 14
                        y: 136
                        z: 10
                        width: 290
                        height: resultsCol.implicitHeight + 12
                        radius: Appearance.rounding.verysmall
                        color: Appearance.colors.colLayer2
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant

                        ColumnLayout {
                            id: resultsCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                            spacing: 0
                            StyledText {
                                visible: searchPopup.results.length === 0
                                Layout.margins: 10
                                text: "No results"
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                            Repeater {
                                model: searchPopup.results
                                RippleButton {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 40
                                    buttonRadius: Appearance.rounding.verysmall
                                    onClicked: searchPopup.open(modelData)
                                    contentItem: RowLayout {
                                        spacing: 10
                                        MaterialSymbol {
                                            Layout.leftMargin: 6
                                            text: WState.categories.find(c => c.id === modelData.page)?.icon ?? "tune"
                                            iconSize: 18
                                            color: Appearance.colors.colPrimary
                                        }
                                        ColumnLayout {
                                            spacing: 0
                                            Layout.fillWidth: true
                                            StyledText {
                                                text: modelData.title
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: Appearance.colors.colOnLayer2
                                            }
                                            StyledText {
                                                text: modelData.page === "advanced" ? "Advanced"
                                                    : WState.categoryName(modelData.page) + (modelData.sub ? " › " + WState.subTitle(modelData.page, modelData.sub) : "")
                                                font.pixelSize: Appearance.font.pixelSize.smallest
                                                color: Appearance.colors.colSubtext
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { GlobalStates.settingsOpen = !GlobalStates.settingsOpen; }
        function open(): void   { GlobalStates.settingsOpen = true; }
        function close(): void  { GlobalStates.settingsOpen = false; }
        function go(page: string, sub: string): void { GlobalStates.settingsOpen = true; WState.go(page, sub); }
    }

    CompositorGlobalShortcut {
        name: "settingsToggle"
        description: "Toggles settings panel"
        onPressed: GlobalStates.settingsOpen = !GlobalStates.settingsOpen;
    }
}


