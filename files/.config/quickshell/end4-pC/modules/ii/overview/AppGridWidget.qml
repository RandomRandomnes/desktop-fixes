pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root
    required property var screen

    function matches(e, id) {
        const l = id.toLowerCase();
        return e.id.toLowerCase() === l || (e.startupClass ?? "").toLowerCase() === l || e.id.toLowerCase().endsWith("." + l);
    }
    // Which apps to show: Settings > Personalization > Super menu apps (Config.options.overview.appGrid*)
    // Each entry: { app, key }; key is what gets saved when the apps are dragged into a new order.
    readonly property var entries: {
        const o = Config.options.overview;
        const all = AppSearch.list;
        if (!o.appGridShowAll)
            return o.appGridApps.map(id => ({ app: all.find(e => matches(e, id)), key: id })).filter(x => x.app);
        const shown = all.filter(e => !o.appGridHidden.some(id => matches(e, id)));
        const rank = e => {
            const i = o.appGridOrder.findIndex(id => matches(e, id));
            return i < 0 ? o.appGridOrder.length : i;
        };
        return shown.map((e, i) => ({ app: e, key: e.id, r: rank(e), i: i }))
            .sort((a, b) => a.r - b.r || a.i - b.i);
    }

    readonly property int cellWidth: 92
    readonly property int cellHeight: 104
    readonly property int cellSpacing: 16
    readonly property int columns: Math.max(1, Math.min(8, entries.length))

    // The grid shows appModel, not entries directly: a JS array model rebuilds every icon on any change (all of them
    // replay the fade-in, which flashed after each drop). appModel only gets moves, so a reorder keeps the icons alive.
    readonly property var appByKey: {
        const m = {};
        for (const x of entries) m[x.key] = x.app;
        return m;
    }
    ListModel { id: appModel }
    function syncModel() {
        const keys = entries.map(x => x.key);
        const cur = [];
        for (let i = 0; i < appModel.count; i++) cur.push(appModel.get(i).key);
        if (cur.length !== keys.length || !keys.every(k => cur.includes(k))) {
            appModel.clear();
            for (const k of keys) appModel.append({ key: k });
            return;
        }
        for (let i = 0; i < keys.length; i++) {
            if (cur[i] === keys[i]) continue;
            const j = cur.indexOf(keys[i], i + 1);
            appModel.move(j, i, 1);
            cur.splice(i, 0, cur.splice(j, 1)[0]);
        }
    }
    onEntriesChanged: syncModel()
    Component.onCompleted: syncModel()

    // Drag state: the app at dragFrom is shown at slot dragTo, the others shift to make room.
    property int dragFrom: -1
    property int dragTo: -1
    // True while a drop is saved: icons jump (no slide) so the model move and drag-state reset can't animate through stale slots.
    property bool committing: false

    function slotOf(i) {
        if (dragFrom < 0) return i;
        if (i === dragFrom) return dragTo;
        if (dragFrom < dragTo && i > dragFrom && i <= dragTo) return i - 1;
        if (dragFrom > dragTo && i >= dragTo && i < dragFrom) return i + 1;
        return i;
    }
    function slotX(s) { return (s % columns) * (cellWidth + cellSpacing); }
    function slotY(s) { return Math.floor(s / columns) * (cellHeight + cellSpacing); }
    function slotAt(px, py) {
        const c = Math.max(0, Math.min(columns - 1, Math.floor((px + cellSpacing / 2) / (cellWidth + cellSpacing))));
        const r = Math.max(0, Math.floor((py + cellSpacing / 2) / (cellHeight + cellSpacing)));
        return Math.min(entries.length - 1, r * columns + c);
    }
    function commitDrag() {
        const from = dragFrom, to = dragTo;
        committing = true;
        if (from >= 0 && from !== to)
            appModel.move(from, to, 1); // the config write below then finds the model already in order
        dragFrom = -1;
        dragTo = -1;
        committing = false;
        if (from < 0 || from === to) return;
        const keys = entries.map(x => x.key);
        keys.splice(to, 0, keys.splice(from, 1)[0]);
        const o = Config.options.overview;
        if (o.appGridShowAll) {
            o.appGridOrder = keys;
        } else {
            // Ids whose app isn't installed right now keep their place; the shown ones fill the other spots in the new order.
            let k = 0;
            o.appGridApps = o.appGridApps.map(id => keys.includes(id) ? keys[k++] : id);
        }
    }

    implicitWidth: gridBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: gridBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    StyledRectangularShadow {
        target: gridBackground
    }

    Rectangle {
        id: gridBackground
        property real padding: 24
        anchors.margins: Appearance.sizes.elevationMargin
        anchors.centerIn: parent
        implicitWidth: grid.width + padding * 2
        implicitHeight: grid.height + padding * 2
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer0

        Item {
            id: grid
            anchors.centerIn: parent
            // 8 columns max; narrower when fewer apps are shown, so short lists stay centered in the panel.
            width: root.columns * (root.cellWidth + root.cellSpacing) - root.cellSpacing
            height: Math.max(1, Math.ceil(root.entries.length / root.columns)) * (root.cellHeight + root.cellSpacing) - root.cellSpacing

            Repeater {
                model: appModel
                delegate: MouseArea {
                    id: appDelegate
                    required property string key
                    required property int index
                    readonly property var app: root.appByKey[key] ?? null
                    readonly property bool dragging: root.dragFrom === index
                    property point pressPos
                    property point grabOffset
                    property bool wasDragged: false
                    width: root.cellWidth
                    height: root.cellHeight
                    hoverEnabled: true
                    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    preventStealing: true
                    z: dragging ? 10 : 0

                    // Slot position; while dragged it follows the pointer instead.
                    x: root.slotX(root.slotOf(index))
                    y: root.slotY(root.slotOf(index))
                    Behavior on x {
                        enabled: !appDelegate.dragging && !root.committing
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveSmall.duration
                            easing.type: Appearance.animation.elementMoveSmall.type
                            easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
                        }
                    }
                    Behavior on y {
                        enabled: !appDelegate.dragging && !root.committing
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveSmall.duration
                            easing.type: Appearance.animation.elementMoveSmall.type
                            easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
                        }
                    }

                    opacity: 0
                    scale: 0.85
                    transformOrigin: Item.Center

                    Component.onCompleted: entranceAnim.start()

                    SequentialAnimation {
                        id: entranceAnim
                        PauseAnimation { duration: Math.min(appDelegate.index * 12, 300) }
                        ParallelAnimation {
                            NumberAnimation {
                                target: appDelegate
                                property: "opacity"
                                to: 1
                                duration: Appearance.animation.elementMoveEnter.duration
                                easing.type: Appearance.animation.elementMoveEnter.type
                                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                            }
                            NumberAnimation {
                                target: appDelegate
                                property: "scale"
                                to: appDelegate.containsMouse ? 1.08 : 1.0
                                duration: Appearance.animation.elementMoveEnter.duration
                                easing.type: Appearance.animation.elementMoveEnter.type
                                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                            }
                        }
                    }

                    Behavior on scale {
                        enabled: !entranceAnim.running
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveSmall.duration
                            easing.type: Appearance.animation.elementMoveSmall.type
                            easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
                        }
                    }

                    onContainsMouseChanged: {
                        if (!entranceAnim.running && !dragging)
                            scale = containsMouse ? 1.08 : 1.0
                    }
                    onPressed: mouse => {
                        pressPos = Qt.point(mouse.x, mouse.y);
                        wasDragged = false;
                        grabOffset = Qt.point(mouse.x, mouse.y);
                        if (!entranceAnim.running) scale = 0.92;
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        if (!dragging) {
                            if (Math.hypot(mouse.x - pressPos.x, mouse.y - pressPos.y) < 10) return;
                            wasDragged = true;
                            entranceAnim.stop();
                            opacity = 1;
                            scale = 1.12;
                            root.dragTo = index;
                            root.dragFrom = index;
                        }
                        const p = mapToItem(grid, mouse.x, mouse.y);
                        x = p.x - grabOffset.x;
                        y = p.y - grabOffset.y;
                        root.dragTo = root.slotAt(x + width / 2 - root.cellWidth / 2, y + height / 2 - root.cellHeight / 2);
                    }
                    onReleased: {
                        if (dragging) {
                            root.commitDrag();
                            // Rebind to the slot (the saved order rebuilds the grid anyway).
                            x = Qt.binding(() => root.slotX(root.slotOf(index)));
                            y = Qt.binding(() => root.slotY(root.slotOf(index)));
                        }
                        if (!entranceAnim.running) scale = containsMouse ? 1.08 : 1.0;
                    }
                    onCanceled: {
                        if (dragging) {
                            root.dragFrom = -1;
                            root.dragTo = -1;
                            x = Qt.binding(() => root.slotX(root.slotOf(index)));
                            y = Qt.binding(() => root.slotY(root.slotOf(index)));
                        }
                        scale = 1.0;
                    }

                    onClicked: mouse => {
                        // A drag ends with a release too; only launch on a real click.
                        if (wasDragged) return;
                        app.execute();
                        GlobalStates.overviewOpen = false;
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6
                        IconImage {
                            Layout.alignment: Qt.AlignHCenter
                            implicitSize: 52
                            source: Quickshell.iconPath(appDelegate.app?.icon ?? "", "image-missing")
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: 88
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: appDelegate.app?.name ?? ""
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
