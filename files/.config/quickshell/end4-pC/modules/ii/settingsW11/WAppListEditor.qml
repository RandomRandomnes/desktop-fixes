import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Edits an ordered list of app ids (dock / Start pinned apps / Super menu apps): reorder, remove, add from installed apps.
// Emits edited(newList); the caller writes it to the config.
ColumnLayout {
    id: root
    property var apps: []
    property string addLabel: "Pin an app"
    property string emptyText: "Nothing pinned yet"
    property string addedText: "Already pinned"
    property bool reorderable: true
    signal edited(var newList)

    Layout.fillWidth: true
    spacing: 3

    function move(i, d) {
        const l = root.apps.slice();
        const j = i + d;
        if (j < 0 || j >= l.length) return;
        [l[i], l[j]] = [l[j], l[i]];
        root.edited(l);
    }
    // Desktop entry for a pinned id: exact desktop id, then window class, then Quickshell's heuristic.
    function lookup(id) {
        const l = id.toLowerCase();
        const apps = AppSearch.list;
        return apps.find(e => e.id.toLowerCase() === l)
            ?? apps.find(e => (e.startupClass ?? "").toLowerCase() === l)
            ?? apps.find(e => e.id.toLowerCase().endsWith("." + l))
            ?? DesktopEntries.heuristicLookup(id)
            ?? null;
    }
    function remove(i) {
        root.edited(root.apps.filter((_, k) => k !== i));
    }
    // Same id the dock uses to match open windows: the window class when the .desktop file names one.
    function idFor(entry) {
        return entry.startupClass && entry.startupClass.length > 0 ? entry.startupClass : entry.id;
    }
    function add(entry) {
        const id = root.idFor(entry);
        if (root.apps.some(a => a.toLowerCase() === id.toLowerCase())) return;
        root.edited(root.apps.concat([id]));
        search.text = "";
    }

    component AppIconImage: IconImage {
        required property string appId
        implicitSize: 28
        source: Quickshell.iconPath(AppSearch.guessIcon(appId), "image-missing")
    }

    component SmallIconButton: RippleButton {
        property string iconName
        implicitWidth: 34
        implicitHeight: 34
        buttonRadius: Appearance.rounding.verysmall
        colBackgroundHover: Appearance.colors.colLayer3Hover
        contentItem: MaterialSymbol {
            text: parent.iconName
            iconSize: 20
            horizontalAlignment: Text.AlignHCenter
            color: parent.enabled ? Appearance.colors.colOnLayer2 : Appearance.colors.colSubtext
        }
    }

    Repeater {
        model: root.apps
        WCard {
            id: row
            required property string modelData
            required property int index
            readonly property var entry: root.lookup(modelData)
            minHeight: 58
            title: entry?.name ?? modelData
            description: entry ? "" : `${modelData} · app not found (it may have been uninstalled)`
            leading: Component { AppIconImage { appId: row.modelData } }

            StyledText {
                visible: root.reorderable
                text: `${row.index + 1}`
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                Layout.rightMargin: 4
            }
            SmallIconButton { visible: root.reorderable; iconName: "arrow_upward"; enabled: row.index > 0; onClicked: root.move(row.index, -1) }
            SmallIconButton { visible: root.reorderable; iconName: "arrow_downward"; enabled: row.index < root.apps.length - 1; onClicked: root.move(row.index, 1) }
            SmallIconButton { iconName: "close"; onClicked: root.remove(row.index) }
        }
    }

    WCard {
        visible: root.apps.length === 0
        icon: "inbox"
        title: root.emptyText
    }

    // Add an app
    WCard {
        icon: "add_circle"
        title: root.addLabel
        description: "Search your installed apps"
        Rectangle {
            implicitWidth: 280
            implicitHeight: 36
            radius: Appearance.rounding.verysmall
            color: Appearance.colors.colLayer3
            border.width: search.activeFocus ? 2 : 0
            border.color: Appearance.colors.colPrimary
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                TextField {
                    id: search
                    Layout.fillWidth: true
                    background: null
                    placeholderText: "Type an app name"
                    placeholderTextColor: Appearance.colors.colSubtext
                    color: Appearance.colors.colOnLayer3
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    Keys.onReturnPressed: if (results.model.length > 0) root.add(results.model[0])
                }
                MaterialSymbol { text: "search"; iconSize: 18; color: Appearance.colors.colSubtext }
            }
        }
    }

    Repeater {
        id: results
        model: search.text.trim().length === 0 ? [] : AppSearch.fuzzyQuery(search.text).filter(e => !e.noDisplay).slice(0, 6)
        WCard {
            id: resultCard
            required property var modelData
            readonly property bool pinned: root.apps.some(a => a.toLowerCase() === root.idFor(modelData).toLowerCase())
            Layout.leftMargin: 28
            minHeight: 52
            clickable: !pinned
            title: modelData.name
            description: pinned ? root.addedText : (modelData.genericName || modelData.comment || "")
            leading: Component { AppIconImage { appId: root.idFor(modelData); implicitSize: 24 } }
            onClicked: root.add(modelData)
            MaterialSymbol { text: resultCard.pinned ? "check" : "add"; iconSize: 20; color: Appearance.colors.colPrimary }
        }
    }
}
