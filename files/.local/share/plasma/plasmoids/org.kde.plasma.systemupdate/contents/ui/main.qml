// KDE counterpart of the Quickshell bar's UpdatesCount.qml / Updates.qml.
// Badge = pending pacman + AUR updates. Left click runs ~/.local/bin/system-update in Konsole,
// middle click re-checks. Thresholds and interval match ~/.config/illogical-impulse/config.json.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property int adviseThreshold: 75
    readonly property int stronglyAdviseThreshold: 200
    readonly property int checkIntervalMin: 120
    readonly property string checkCmd: "command -v checkupdates >/dev/null || { echo missing; exit; }; "
        + "p=$(checkupdates 2>/dev/null | wc -l); a=$(yay -Qua 2>/dev/null | wc -l); echo \"$p $a\""
    readonly property string updateCmd: "konsole --separate --hide-menubar -p tabtitle='System update' -e \"$HOME/.local/bin/system-update\""

    property int pacmanCount: 0
    property int aurCount: 0
    property bool available: true
    property bool checking: false
    property bool updating: false
    property string lastChecked: ""
    readonly property int count: pacmanCount + aurCount

    function refresh() {
        if (checking || updating) return;
        checking = true;
        checker.connectSource(checkCmd);
    }
    function runUpdate() {
        if (updating) return;
        updating = true;
        updater.connectSource(updateCmd);
    }

    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: false
    Plasmoid.icon: "system-software-update"
    toolTipMainText: !available ? "System update"
        : updating ? "Updating…"
        : checking ? "Checking for updates…"
        : count === 0 ? "System up to date" : count + " updates available"
    toolTipSubText: !available ? "checkupdates not found (install pacman-contrib)"
        : (count > 0 ? pacmanCount + " pacman, " + aurCount + " AUR\n" : "")
          + (lastChecked ? "Checked " + lastChecked + "\n" : "")
          + "Click to update · Middle-click to check again"

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Update now"
            icon.name: "system-software-update"
            enabled: !root.updating
            onTriggered: root.runUpdate()
        },
        PlasmaCore.Action {
            text: "Check for updates"
            icon.name: "view-refresh"
            enabled: !root.checking && !root.updating
            onTriggered: root.refresh()
        }
    ]

    P5Support.DataSource {
        id: checker
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            root.checking = false;
            const out = (data["stdout"] || "").trim();
            root.lastChecked = Qt.formatTime(new Date(), Qt.locale().timeFormat(Locale.ShortFormat));
            if (out === "missing") { root.available = false; return; }
            root.available = true;
            const parts = out.split(/\s+/);
            root.pacmanCount = parseInt(parts[0]) || 0;
            root.aurCount = parseInt(parts[1]) || 0;
        }
    }

    P5Support.DataSource {
        id: updater
        engine: "executable"
        // Fires when the Konsole window closes. system-update sends its own summary notification.
        onNewData: (source, data) => {
            disconnectSource(source);
            root.updating = false;
            root.refresh();
        }
    }

    Timer {
        interval: 10 * 1000   // give the network a moment after login
        running: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: root.checkIntervalMin * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    compactRepresentation: MouseArea {
        id: compact
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        Layout.minimumWidth: Kirigami.Units.iconSizes.medium
        onClicked: (mouse) => mouse.button === Qt.MiddleButton ? root.refresh() : root.runUpdate()

        Kirigami.Icon {
            id: icon
            anchors.fill: parent
            source: "system-software-update"
            active: compact.containsMouse
            opacity: root.updating ? 0.5 : 1
        }

        PC3.BusyIndicator {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.8
            height: width
            running: root.checking || root.updating
            visible: running
        }

        Rectangle {
            id: badge
            visible: root.available && root.count > 0 && !root.checking && !root.updating
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(Kirigami.Units.gridUnit * 0.8, badgeText.implicitHeight)
            width: Math.max(height, badgeText.implicitWidth + Kirigami.Units.smallSpacing * 2)
            radius: height / 2
            color: root.count > root.stronglyAdviseThreshold ? Kirigami.Theme.negativeTextColor
                 : root.count > root.adviseThreshold ? Kirigami.Theme.neutralTextColor
                 : Kirigami.Theme.highlightColor
            PC3.Label {
                id: badgeText
                anchors.centerIn: parent
                text: root.count > 999 ? "999+" : root.count
                font.pixelSize: Math.max(Kirigami.Theme.smallFont.pixelSize * 0.85, 8)
                font.bold: true
                color: Kirigami.Theme.highlightedTextColor
            }
        }
    }

    fullRepresentation: Item {}
}
