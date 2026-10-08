import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import QtQuick.Layouts

BarWidgetSwitcherArea {
    Component.onCompleted: ResourceUsage.consumers++
    Component.onDestruction: ResourceUsage.consumers--
    id: root
    property color contentColor: Appearance.colors.colOnSecondaryContainer
    property bool contentColorOverridden: false
    property bool alwaysShowAllResources: false
    horizontalExtraPadding: 12
    // The bar centers the clock on the screen, so on narrow screens the full widget would slide under it.
    // Full (graphs + details) from 2200 px wide, graphs only from 1700 px (1080p), values only below (4:3, 5:4).
    readonly property real screenWidth: root.QsWindow.window?.screen?.width ?? 2560
    readonly property int density: screenWidth >= 2200 ? 2 : screenWidth >= 1700 ? 1 : 0

    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    // Horizontal bar: CPU / GPU / RAM live graphs with details (2026-10-03, ours; services/SystemStats.qml)
    rowDefault: Config.options.extras.resourceGraphs ? graphRow : classicRowDefault
    rowMaterial: Config.options.extras.resourceGraphs ? graphRow : classicRowMaterial

    Component {
        id: graphRow
        RowLayout {
            spacing: root.density === 0 ? 8 : 12
            Layout.rightMargin: 4
            readonly property var cpu: SystemStats.cpu
            readonly property var gpu: SystemStats.gpu
            readonly property var mem: SystemStats.mem

            ResourceGraph {
                contentColor: root.contentColor
                density: root.density
                iconName: "planner_review"
                detailTemplate: "100°C · 100 W"
                history: SystemStats.cpuHistory
                valueText: parent.cpu ? `${Math.round(parent.cpu.usage * 100)}%` : "--"
                line1: parent.cpu ? `${SystemStats.ghz(parent.cpu.freqAvg)} GHz` : ""
                line2: parent.cpu ? `${Math.round(parent.cpu.temp)}°C · ${Math.round(parent.cpu.power ?? 0)} W` : ""
                warning: parent.cpu !== null && (parent.cpu.usage * 100 >= Config.options.bar.resources.cpuWarningThreshold || parent.cpu.temp >= 85)
            }
            ResourceGraph {
                visible: parent.gpu !== null && Config.options.bar.resources.alwaysShowGpu
                contentColor: root.contentColor
                density: root.density
                iconName: "developer_board"
                detailTemplate: "VRAM 16.0/16G"
                history: SystemStats.gpuHistory
                valueText: parent.gpu ? (parent.gpu.sleeping ? "Off" : `${Math.round(parent.gpu.busy * 100)}%`) : "--"
                // AMD, NVIDIA or Intel: temperature and power only when the card reports them
                line1: !parent.gpu ? "" : [parent.gpu.temp > 0 ? `${Math.round(parent.gpu.temp)}°C` : "",
                                           parent.gpu.power > 0 ? `${Math.round(parent.gpu.power)} W` : ""].filter(x => x).join(" · ")
                line2: !parent.gpu ? "" : parent.gpu.vramTotal > 0 ? `VRAM ${SystemStats.gb(parent.gpu.vramUsed)}/${SystemStats.gb(parent.gpu.vramTotal, 0)}G`
                    : parent.gpu.sclk > 0 ? `${(parent.gpu.sclk / 1000).toFixed(1)} GHz` : ""
                warning: parent.gpu !== null && parent.gpu.temp >= parent.gpu.tempWarn
            }
            ResourceGraph {
                contentColor: root.contentColor
                density: root.density
                iconName: "memory"
                detailTemplate: "zram 16.0G"
                history: SystemStats.memHistory
                valueText: parent.mem ? `${SystemStats.gb(parent.mem.used)}G` : "--"
                line1: parent.mem ? `of ${SystemStats.gb(parent.mem.total, 0)} GB` : ""
                line2: parent.mem ? (parent.mem.zram ? `zram ${SystemStats.gb(parent.mem.zram.orig)}G` : `swap ${SystemStats.gb(parent.mem.swapUsed)}G`) : ""
                warning: SystemStats.memUsage * 100 >= Config.options.bar.resources.memoryWarningThreshold
            }
        }
    }

    // Stock-style rows (circular gauges), used when Settings › Extras › resource graphs is off
    Component {
        id: classicRowDefault
        // (body unchanged from before 2026-10-03)
        RowLayout {
            spacing: 0
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "memory"
                shown: Config.options.bar.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.resources.memoryWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "planner_review"
                shown: Config.options.bar.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.cpuWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "thermostat"
                shown: Config.options.bar.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "hard_drive"
                shown: Config.options.bar.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "swap_horiz"
                shown: Config.options.bar.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.swapWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "developer_board"
                shown: Config.options.bar.resources.alwaysShowGpu && ResourceUsage.gpuAvailable
                percentage: ResourceUsage.gpuUsage
                Layout.leftMargin: shown ? 6 : 0
            }
        }
    }

    Component {
        id: classicRowMaterial
        RowLayout {
            spacing: 0
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "memory"
                shown: Config.options.bar.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.resources.memoryWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "planner_review"
                shown: Config.options.bar.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.cpuWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "thermostat"
                shown: Config.options.bar.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "hard_drive"
                shown: Config.options.bar.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "swap_horiz"
                shown: Config.options.bar.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.swapWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "developer_board"
                shown: Config.options.bar.resources.alwaysShowGpu && ResourceUsage.gpuAvailable
                percentage: ResourceUsage.gpuUsage
                Layout.leftMargin: shown ? 6 : 0
            }
        }
    }

    colDefault: Component {
        ColumnLayout {
            spacing: 7
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "memory"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.resources.memoryWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "planner_review"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                warningThreshold: Config.options.bar.resources.cpuWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "thermostat"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "hard_drive"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "swap_horiz"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                warningThreshold: Config.options.bar.resources.swapWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "developer_board"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowGpu && ResourceUsage.gpuAvailable
                percentage: ResourceUsage.gpuUsage
            }
        }
    }

    colMaterial: Component {
        ColumnLayout {
            spacing: 7
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "memory"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.resources.memoryWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "planner_review"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                warningThreshold: Config.options.bar.resources.cpuWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "thermostat"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "hard_drive"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "swap_horiz"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                warningThreshold: Config.options.bar.resources.swapWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "developer_board"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowGpu && ResourceUsage.gpuAvailable
                percentage: ResourceUsage.gpuUsage
            }
        }
    }

    ResourcesPopup {
        hoverTarget: Config.options.extras.resourceGraphs ? root : null
    }
    ResourcesPopupClassic {
        hoverTarget: Config.options.extras.resourceGraphs ? null : root
    }
}