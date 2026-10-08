import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Detailed resources popup (2026-10-03, ours; replaces the upstream card row). Data: services/SystemStats.qml.
 * Footer "System power" = CPU package (RAPL) + GPU board power + a fixed estimate for the unmetered rest.
 */
StyledPopup {
    id: root

    readonly property var cpu: SystemStats.cpu
    // the last GPU reading: a single missed sample used to hide the GPU rows for a second (the popup changed height)
    property var gpu: SystemStats.gpu
    // fixed card width: the popup keeps one size; longer values are shortened with … inside the card
    readonly property int cardWidth: 440
    readonly property var mem: SystemStats.mem
    readonly property var sys: SystemStats.sys
    readonly property var sample: SystemStats.sample

    component Card: Rectangle {
        id: card
        default property alias content: cardColumn.data
        required property string title
        required property string subtitle
        required property string iconName
        Layout.fillHeight: true
        Layout.preferredWidth: root.cardWidth
        Layout.minimumWidth: root.cardWidth
        Layout.maximumWidth: root.cardWidth
        implicitHeight: cardColumn.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: Appearance.colors.colSurfaceContainerLow

        ColumnLayout {
            id: cardColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            spacing: 6

            RowLayout {
                spacing: 9
                Layout.bottomMargin: 2
                MaterialShapeWrappedMaterialSymbol {
                    shape: MaterialShape.Shape.Cookie4Sided
                    text: card.iconName
                    iconSize: Appearance.font.pixelSize.large
                    implicitSize: 34
                    color: Appearance.colors.colTertiaryContainer
                    colSymbol: Appearance.colors.colOnTertiaryContainer
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -3
                    StyledText {
                        text: card.title
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnSurface
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: card.subtitle
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
        }
    }

    component BigValue: RowLayout {
        id: big
        required property string value
        property string note: ""
        property string template: "100%"   // widest value: fixed width, so the note beside it doesn't slide
        spacing: 10
        TextMetrics {
            id: bigMetrics
            text: big.template
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.huge
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.preferredWidth: bigMetrics.advanceWidth + 2
            text: big.value
            font.pixelSize: Appearance.font.pixelSize.huge
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Appearance.colors.colTertiary
        }
        StyledText {
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 3
            Layout.fillWidth: true
            text: big.note
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnSurfaceVariant
        }
    }

    component InfoRow: RowLayout {
        id: info
        required property string label
        required property string value
        property bool warning: false
        Layout.fillWidth: true
        spacing: 8
        StyledText {
            text: info.label
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: info.value
            elide: Text.ElideLeft
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: info.warning ? Appearance.colors.colError : Appearance.colors.colOnSurface
        }
    }

    component Meter: Rectangle {
        id: meter
        property real value: 0
        Layout.fillWidth: true
        implicitHeight: 6
        radius: 3
        color: Appearance.colors.colSecondaryContainer
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, meter.value))
            height: parent.height
            radius: 3
            color: meter.value >= 0.9 ? Appearance.colors.colError : Appearance.colors.colTertiary
            Behavior on width {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }

    component FooterItem: RowLayout {
        id: foot
        required property string iconName
        required property string label
        required property string value
        property string note: ""
        // widest value / note: fixed widths, so the items in this row don't slide when the numbers change
        property string valueTemplate: ""
        property string noteTemplate: ""
        spacing: 5
        TextMetrics { id: footValueMetrics; text: foot.valueTemplate; font.family: Appearance.font.family.main
                      font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.DemiBold }
        TextMetrics { id: footNoteMetrics; text: foot.noteTemplate; font.family: Appearance.font.family.main
                      font.pixelSize: Appearance.font.pixelSize.smaller }
        MaterialSymbol {
            text: foot.iconName
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnSurfaceVariant
        }
        StyledText {
            text: foot.label
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurfaceVariant
        }
        StyledText {
            Layout.preferredWidth: foot.valueTemplate ? footValueMetrics.advanceWidth + 2 : implicitWidth
            text: foot.value
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnSurface
        }
        StyledText {
            visible: foot.note !== ""
            Layout.preferredWidth: foot.noteTemplate ? footNoteMetrics.advanceWidth + 2 : implicitWidth
            text: foot.note
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnSurfaceVariant
            opacity: 0.75
        }
    }

    ColumnLayout {
        spacing: 8

        Connections {   // keeps root.gpu at the last reading (see above)
            target: SystemStats
            function onGpuChanged() { if (SystemStats.gpu) root.gpu = SystemStats.gpu }
        }

        StyledText {
            visible: !SystemStats.ready
            text: Translation.tr("Collecting system stats…")
            color: Appearance.colors.colOnSurfaceVariant
        }

        GridLayout {
            visible: SystemStats.ready
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            Card {
                title: "CPU"
                iconName: "planner_review"
                subtitle: root.cpu ? `${root.cpu.model} · ${root.cpu.cores} cores / ${root.cpu.threads} threads` : ""

                BigValue {
                    value: root.cpu ? `${Math.round(root.cpu.usage * 100)}%` : ""
                    note: root.cpu ? `avg ${SystemStats.ghz(root.cpu.freqAvg)} GHz` + (root.cpu.freqMax > 0 ? ` · max ${SystemStats.ghz(root.cpu.freqMax)} GHz` : "") : ""
                }
                RowLayout {
                    id: threadBars
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    spacing: 3
                    Repeater {
                        model: root.cpu?.freqs ?? []
                        Item {
                            required property real modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(3, parent.height * Math.min(1, modelData / Math.max(1, (root.cpu?.freqMax > 0 ? root.cpu.freqMax : Math.max(...(root.cpu?.freqs ?? [1]))))))
                                radius: 2
                                color: Appearance.colors.colTertiary
                                Behavior on height {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }
                            }
                        }
                    }
                }
                StyledText {
                    text: root.cpu && root.cpu.freqs.length > 0
                        ? `Clock per thread (${SystemStats.ghz(Math.min(...root.cpu.freqs))} to ${SystemStats.ghz(Math.max(...root.cpu.freqs))} GHz)`
                        : ""
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnSurfaceVariant
                }
                InfoRow {
                    label: "Temperature"
                    value: !root.cpu ? "" : root.cpu.temp == null ? "n/a (no sensor)"
                        : `${Math.round(root.cpu.temp)}°C` + (root.cpu.ccd.length ? ` (CCD ${root.cpu.ccd.map(t => Math.round(t)).join(" / ")}°C)` : "")
                    warning: (root.cpu?.temp ?? 0) >= 85
                }
                InfoRow {
                    label: "Package power"
                    value: root.cpu?.power != null ? `${root.cpu.power.toFixed(1)} W` : `n/a${root.cpu?.powerNote ? ` (${root.cpu.powerNote})` : ""}`
                }
                InfoRow {
                    label: "Load average"
                    value: root.cpu ? root.cpu.load.map(l => l.toFixed(2)).join(" · ") : ""
                }
                InfoRow {
                    label: "Governor"
                    value: root.cpu ? `${root.cpu.governor} (${root.cpu.driver})` : ""
                }
            }

            Card {
                // AMD, NVIDIA or Intel (scripts/gpu/gpustats.py): rows show only what the card reports
                title: "GPU"
                iconName: "developer_board"
                subtitle: root.gpu ? (root.gpu.name || `${root.gpu.vendor} GPU`) + (root.gpu.integrated ? " (integrated)" : "") : "No supported GPU found"

                BigValue {
                    value: root.gpu ? (root.gpu.sleeping ? "Off" : `${Math.round(root.gpu.busy * 100)}%`) : "--"
                    note: !root.gpu ? "" : root.gpu.sleeping ? "Powered down to save energy"
                        : root.gpu.sclk > 0 ? `core ${Math.round(root.gpu.sclk)} MHz` + (root.gpu.mclk > 0 ? ` · memory ${Math.round(root.gpu.mclk)} MHz` : "") : ""
                }
                InfoRow {
                    visible: !!root.gpu && root.gpu.vramTotal > 0
                    label: "VRAM"
                    value: root.gpu ? `${SystemStats.gb(root.gpu.vramUsed)} / ${SystemStats.gb(root.gpu.vramTotal, 0)} GB` : ""
                }
                Meter {
                    visible: !!root.gpu && root.gpu.vramTotal > 0
                    value: root.gpu && root.gpu.vramTotal > 0 ? root.gpu.vramUsed / root.gpu.vramTotal : 0
                }
                InfoRow {
                    visible: !!root.gpu && root.gpu.integrated && root.gpu.vramTotal === 0
                    label: "Memory"
                    value: "Shared with the system memory"
                }
                InfoRow {
                    visible: !!root.gpu && root.gpu.temps.length > 0
                    label: root.gpu && root.gpu.temps.length === 1 ? "Temperature" : "Temperatures"
                    value: root.gpu ? (root.gpu.temps.length === 1 ? `${Math.round(root.gpu.temps[0][1])}°C`
                        : root.gpu.temps.map(t => `${t[0]} ${Math.round(t[1])}`).join(" · ") + "°C") : ""
                    warning: !!root.gpu && root.gpu.temp >= root.gpu.tempWarn
                }
                InfoRow {
                    visible: !!root.gpu && (root.gpu.power > 0 || root.gpu.powerCap > 0)
                    label: "Power"
                    value: root.gpu ? `${Math.round(root.gpu.power)} W` + (root.gpu.powerCap > 0 ? ` of ${Math.round(root.gpu.powerCap)} W` : "") : ""
                }
                InfoRow {
                    visible: !!root.gpu && (root.gpu.fan !== null || root.gpu.fanPercent !== null)
                    label: "Fan"
                    value: !root.gpu ? "" : root.gpu.fan !== null ? (root.gpu.fan > 0 ? `${root.gpu.fan} rpm` : "0 rpm (idle stop)")
                        : root.gpu.fanPercent !== null ? `${Math.round(root.gpu.fanPercent)}%` : ""
                }
                InfoRow {
                    visible: !!root.gpu && root.gpu.mv !== null
                    label: "Core voltage"
                    value: root.gpu && root.gpu.mv !== null ? `${root.gpu.mv} mV` : ""
                }
            }

            Card {
                title: "Memory"
                iconName: "memory"
                // MemTotal excludes firmware-reserved RAM, so round up to the power of two that is actually installed
                subtitle: root.mem ? `${Math.pow(2, Math.ceil(Math.log2(root.mem.total / 1073741824)))} GB installed` : ""

                BigValue {
                    template: "000.0 GB"
                    value: root.mem ? `${SystemStats.gb(root.mem.used)} GB` : ""
                    note: root.mem ? `used of ${SystemStats.gb(root.mem.total)} GB` : ""
                }
                Meter {
                    value: SystemStats.memUsage
                }
                InfoRow {
                    label: "Available"
                    value: root.mem ? `${SystemStats.gb(root.mem.available)} GB` : ""
                }
                InfoRow {
                    label: "Cached"
                    value: root.mem ? `${SystemStats.gb(root.mem.cached)} GB` : ""
                }
                InfoRow {
                    visible: root.mem?.zram != null
                    label: "zram swap"
                    value: root.mem?.zram ? `${SystemStats.gb(root.mem.zram.orig)} GB → ${SystemStats.gb(root.mem.zram.compr)} GB (${root.mem.zram.algo})` : ""
                }
                InfoRow {
                    label: "Swap total"
                    value: root.mem ? `${SystemStats.gb(root.mem.swapUsed)} / ${SystemStats.gb(root.mem.swapTotal, 0)} GB` : ""
                }
            }

            Card {
                title: "Storage"
                iconName: "hard_drive"
                subtitle: root.sample ? `${root.sample.nvme.length} NVMe drives` : ""

                Repeater {
                    model: root.sample?.disks ?? []
                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 4
                        InfoRow {
                            label: modelData.path === "/" ? "/ (system)" : modelData.path
                            value: `${Math.round(modelData.used / 1073741824)} / ${Math.round(modelData.total / 1073741824)} GB`
                        }
                        Meter {
                            value: modelData.total > 0 ? modelData.used / modelData.total : 0
                        }
                    }
                }
                Repeater {
                    model: root.sample?.nvme ?? []
                    InfoRow {
                        required property var modelData
                        label: modelData.model
                        value: `${Math.round(modelData.temp)}°C`
                        warning: modelData.temp >= 70
                    }
                }
            }
        }

        RowLayout {
            visible: SystemStats.ready
            Layout.fillWidth: true
            Layout.maximumWidth: root.cardWidth * 2 + 8 - 12   // never wider than the cards above
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            spacing: 18

            FooterItem {
                iconName: "schedule"
                label: "Uptime"
                value: root.sys ? SystemStats.duration(root.sys.uptime) : ""
            }
            FooterItem {
                iconName: "account_tree"
                label: "Processes"
                value: root.sys ? `${root.sys.procs}` : ""
            }
            Item { Layout.fillWidth: true }
            FooterItem {
                iconName: "bolt"
                label: "System"
                valueTemplate: "≈ 0000 W"
                noteTemplate: "CPU 000 + GPU 000 + ~00 rest"
                value: root.sys ? `≈ ${Math.round(root.sys.powerEstimate)} W` : ""
                note: root.sys ? `CPU ${Math.round(root.cpu?.power ?? 0)} + GPU ${Math.round(root.gpu?.power ?? 0)} + ~${Math.round(root.sys.powerOther)} rest` : ""
            }
            Item { Layout.fillWidth: true }
            FooterItem {
                iconName: "swap_vert"
                label: ""
                valueTemplate: "↑ 000 KB/s  ↓ 000 KB/s"
                value: root.sample ? `↑ ${SystemStats.rate(root.sample.net.tx)}  ↓ ${SystemStats.rate(root.sample.net.rx)}` : ""
            }
        }
    }
}
