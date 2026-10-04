import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Wallpaper Engine picker in the right sidebar (2026-10-03). Shows the active wallpaper with a shuffle button and
// expands into a searchable grid of the installed workshop wallpapers. Uses ~/.local/bin/wallpaper-engine-ctl
// (list / current / set / random), which keeps the Linux Wallpaper Engine app's own state in sync.
Rectangle {
    id: root

    readonly property string ctl: `${Quickshell.env("HOME")}/.local/bin/wallpaper-engine-ctl`
    property var wallpapers: []
    property string currentId: ""
    property string pendingId: ""
    property bool expanded: false
    property bool searchVisible: false
    property string query: ""
    readonly property var filtered: {
        const q = root.query.trim().toLowerCase();
        if (q === "") return root.wallpapers;
        return root.wallpapers.filter(w => w.title.toLowerCase().includes(q) || w.type === q || w.id === q);
    }
    readonly property var currentItem: root.wallpapers.find(w => w.id === root.currentId) ?? null

    implicitHeight: content.implicitHeight + 20
    // set by SidebarRightContent.qml: the most height this card may take; the grid shrinks to fit (one row minimum)
    property real availableHeight: Infinity
    readonly property real collapsedHeight: header.implicitHeight + 20
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1

    function apply(id) {
        if (id === root.currentId || setProc.running) return;
        root.pendingId = id;
        setProc.command = [root.ctl, "set", id];
        setProc.running = true;
    }

    Process {
        id: listProc
        command: [root.ctl, "list"]
        running: GlobalStates.sidebarRightOpen && root.visible && root.wallpapers.length === 0
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.wallpapers = JSON.parse(this.text) } catch (e) { root.wallpapers = [] }
            }
        }
    }
    Process {
        id: currentProc
        command: [root.ctl, "current"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentId = this.text.trim();
                if (root.currentId === root.pendingId) root.pendingId = "";
            }
        }
    }
    Process {
        id: setProc
        stdout: StdioCollector {}
        onExited: currentProc.running = true
    }
    Process {
        id: muteProc
        command: [root.ctl, "mute", "toggle"]
        stdout: StdioCollector {}
    }
    Process {
        id: randomProc
        command: [root.ctl, "random"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.pendingId = this.text.trim();
                currentProc.running = true;
            }
        }
    }
    // keep "current" fresh while the sidebar is open (also catches changes made in the app itself)
    Timer {
        interval: root.pendingId !== "" ? 1000 : 4000
        running: GlobalStates.sidebarRightOpen && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!currentProc.running) currentProc.running = true
    }
    // give up showing "Applying" after a while
    Timer {
        interval: 20000
        running: root.pendingId !== ""
        onTriggered: root.pendingId = ""
    }

    ColumnLayout {
        id: content
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 8

        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 30
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.currentItem ? `file://${root.currentItem.preview}` : ""
                    sourceSize.width: 96
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !root.currentItem
                    text: "wallpaper"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: "Wallpaper Engine"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.pendingId !== "" ? "Applying…"
                        : (root.currentItem ? root.currentItem.title : (root.currentId !== "" ? root.currentId : "No wallpaper"))
                    color: Appearance.colors.colOnLayer1
                }
            }

            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                toggled: GlobalStates.wallpaperEngineMuted
                enabled: !muteProc.running
                onClicked: muteProc.running = true
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: GlobalStates.wallpaperEngineMuted ? "volume_off" : "volume_up"
                    iconSize: Appearance.font.pixelSize.larger
                    color: GlobalStates.wallpaperEngineMuted ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                }
                StyledToolTip {
                    text: GlobalStates.wallpaperEngineMuted ? "Unmute wallpaper" : "Mute wallpaper"
                }
            }
            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                toggled: root.searchVisible
                onClicked: {
                    root.searchVisible = !root.searchVisible;
                    if (root.searchVisible) {
                        root.expanded = true; // the search filters the grid, so show it
                        search.forceActiveFocus();
                    } else {
                        search.text = "";
                    }
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "search"
                    iconSize: Appearance.font.pixelSize.larger
                    color: root.searchVisible ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                }
                StyledToolTip {
                    text: root.searchVisible ? "Hide search" : "Search wallpapers"
                }
            }
            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                enabled: !randomProc.running && !setProc.running
                onClicked: randomProc.running = true
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "shuffle"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer1
                }
                StyledToolTip {
                    text: "Random wallpaper"
                }
            }
            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                onClicked: root.expanded = !root.expanded
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: root.expanded ? "expand_less" : "expand_more"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer1
                }
                StyledToolTip {
                    text: root.expanded ? "Hide wallpapers" : "Browse wallpapers"
                }
            }
        }

        MaterialTextField {
            id: search
            Layout.fillWidth: true
            visible: root.expanded && root.searchVisible
            placeholderText: `Search ${root.wallpapers.length} wallpapers (or scene / video / web)`
            onTextChanged: root.query = text
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(grid.cellHeight + 4, Math.min(330,
                root.availableHeight - root.collapsedHeight - content.spacing - (search.visible ? search.implicitHeight + content.spacing : 0)))
            visible: root.expanded
            clip: true
            model: root.expanded ? root.filtered : []
            cellWidth: width / 3
            cellHeight: cellWidth * 0.62 + 22
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: StyledScrollBar {}

            delegate: Item {
                id: cell
                required property var modelData
                readonly property bool isCurrent: modelData.id === root.currentId
                readonly property bool isPending: modelData.id === root.pendingId
                width: grid.cellWidth
                height: grid.cellHeight

                RippleButton {
                    anchors {
                        fill: parent
                        margins: 3
                    }
                    buttonRadius: Appearance.rounding.small
                    onClicked: root.apply(cell.modelData.id)
                    contentItem: ColumnLayout {
                        spacing: 2
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer2
                            border.width: cell.isCurrent || cell.isPending ? 2 : 0
                            border.color: cell.isPending ? Appearance.colors.colSecondary : Appearance.colors.colPrimary
                            clip: true
                            Image {
                                anchors {
                                    fill: parent
                                    margins: parent.border.width
                                }
                                source: `file://${cell.modelData.preview}`
                                sourceSize.width: 192
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                            }
                            Rectangle {
                                anchors {
                                    right: parent.right
                                    bottom: parent.bottom
                                    margins: 4
                                }
                                radius: 4
                                color: "#99000000"
                                implicitWidth: typeLabel.implicitWidth + 8
                                implicitHeight: typeLabel.implicitHeight + 2
                                StyledText {
                                    id: typeLabel
                                    anchors.centerIn: parent
                                    text: cell.modelData.type
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: "white"
                                }
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: cell.modelData.title
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: cell.isCurrent ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                        }
                    }
                    StyledToolTip {
                        text: cell.modelData.title
                    }
                }
            }
        }
    }
}
