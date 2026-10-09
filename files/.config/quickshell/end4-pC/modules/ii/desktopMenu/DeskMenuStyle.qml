pragma Singleton
import QtQuick
import Quickshell
import qs.modules.common

// Colors and sizes of the Windows-style desktop menu (DesktopMenu.qml).
Singleton {
    readonly property color colMenu: Appearance.m3colors.m3surfaceContainer
    readonly property color colBorder: Appearance.colors.colOutlineVariant
    readonly property color colHover: Appearance.colors.colLayer2Hover
    readonly property color colPressed: Appearance.colors.colLayer2Active
    readonly property color colText: Appearance.m3colors.m3onSurface
    readonly property real rowHeight: 34
    readonly property real menuRadius: Appearance.rounding.verysmall
    readonly property real menuWidth: 264
}
