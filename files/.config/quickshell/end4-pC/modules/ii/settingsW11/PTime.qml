import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    Loader {
        anchors.fill: parent
        sourceComponent: ({ "datetime": datetime, "language": language })[WState.sub] ?? overview
    }

    Component {
        id: overview
        WPage {
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                ColumnLayout {
                    spacing: 0
                    StyledText {
                        text: Qt.locale().toString(DateTime.clock.date, DateTime.use12HourFormat ? "h:mm AP" : "HH:mm")
                        font.pixelSize: 40
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        text: Qt.locale().toString(DateTime.clock.date, "dddd, MMMM d, yyyy")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
            WSection {
                WLink { icon: "schedule"; title: "Date & time"; description: "Time zone, automatic clock, 24-hour time, date format"; sub: "datetime" }
                WLink { icon: "translate"; title: "Language & region"; description: "Display language, first day of week"; sub: "language" }
            }
        }
    }

    // ── Date & time ────────────────────────────────────────────────
    Component {
        id: datetime
        WPage {
            id: dt
            property string timezone: ""
            property bool ntp: false
            property var zones: []
            function refresh() { tdProc.running = true; }
            Component.onCompleted: { refresh(); zonesProc.running = true; }
            Process {
                id: tdProc
                command: ["timedatectl", "show", "-p", "Timezone", "-p", "NTP", "--value"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const l = text.trim().split("\n");
                        dt.timezone = l[0] ?? "";
                        dt.ntp = (l[1] ?? "") === "yes";
                    }
                }
            }
            Process {
                id: zonesProc
                command: ["timedatectl", "list-timezones"]
                stdout: StdioCollector { onStreamFinished: dt.zones = text.trim().split("\n") }
            }
            Process { id: setProc; onExited: dt.refresh() }
            function run(cmd) { setProc.command = cmd; setProc.running = true; }

            WSection {
                WToggle {
                    icon: "sync"
                    title: "Set time automatically"
                    description: "Sync with internet time servers (NTP). You may be asked for your password."
                    checked: dt.ntp
                    onToggled: v => dt.run(["timedatectl", "set-ntp", v ? "true" : "false"])
                }
                WCard {
                    icon: "public"
                    title: "Time zone"
                    description: `Current: ${dt.timezone}. Type a city or region, e.g. America/Chicago`
                    Rectangle {
                        implicitWidth: 260; implicitHeight: 34
                        radius: Appearance.rounding.verysmall
                        color: Appearance.colors.colLayer3
                        border.width: tzField.activeFocus ? 2 : 0
                        border.color: Appearance.colors.colPrimary
                        TextField {
                            id: tzField
                            anchors.fill: parent
                            leftPadding: 10
                            background: null
                            placeholderText: dt.timezone
                            placeholderTextColor: Appearance.colors.colSubtext
                            color: Appearance.colors.colOnLayer3
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
                Repeater {
                    model: tzField.text.trim().length < 2 ? [] : dt.zones.filter(z => z.toLowerCase().includes(tzField.text.trim().toLowerCase().replace(/ /g, "_"))).slice(0, 6)
                    WCard {
                        required property string modelData
                        Layout.leftMargin: 28
                        minHeight: 48
                        clickable: true
                        title: modelData.replace(/_/g, " ")
                        onClicked: { dt.run(["timedatectl", "set-timezone", modelData]); tzField.text = ""; }
                        MaterialSymbol { text: modelData === dt.timezone ? "check" : "arrow_forward"; iconSize: 20; color: Appearance.colors.colPrimary }
                    }
                }
            }

            WSection {
                title: "Formats"
                WToggle {
                    icon: "schedule"
                    title: "24-hour time"
                    description: DateTime.use12HourFormat ? "Example: 2:30 PM" : "Example: 14:30"
                    checked: !DateTime.use12HourFormat
                    onToggled: v => Config.options.time.format = v ? "hh:mm" : "h:mm AP"
                }
                WCombo {
                    icon: "calendar_today"
                    title: "Date on the taskbar"
                    fieldWidth: 280
                    model: ["ddd, dd/MM", "ddd, MM/dd", "ddd, MMM d", "dddd, MMMM d", "dd/MM", "MM/dd"].map(f => ({ displayName: `${Qt.locale().toString(DateTime.clock.date, f)}   (${f})`, value: f }))
                        .concat(["ddd, dd/MM", "ddd, MM/dd", "ddd, MMM d", "dddd, MMMM d", "dd/MM", "MM/dd"].includes(Config.options.time.dateFormat) ? [] : [{ displayName: Config.options.time.dateFormat, value: Config.options.time.dateFormat }])
                    currentValue: Config.options.time.dateFormat
                    onSelected: v => Config.options.time.dateFormat = v
                }
                WCombo {
                    icon: "event"
                    title: "Short date"
                    fieldWidth: 280
                    model: [["dd/MM/yyyy", "dd/MM"], ["MM/dd/yyyy", "MM/dd"], ["yyyy-MM-dd", "MM-dd"]].map(f => ({ displayName: `${Qt.locale().toString(DateTime.clock.date, f[0])}   (${f[0]})`, value: f[0] }))
                    currentValue: Config.options.time.dateWithYearFormat
                    onSelected: v => {
                        Config.options.time.dateWithYearFormat = v;
                        Config.options.time.shortDateFormat = v === "dd/MM/yyyy" ? "dd/MM" : v === "MM/dd/yyyy" ? "MM/dd" : "MM-dd";
                    }
                }
                WToggle {
                    icon: "today"
                    title: "Show the date on the taskbar"
                    checked: Config.options.time.showDate
                    onToggled: v => Config.options.time.showDate = v
                }
            }

            WSection {
                title: "Related"
                WLink { icon: "public"; title: "World clocks"; description: "Extra time zones on the desktop clock widget"; page: "personalization"; sub: "widgets" }
            }
        }
    }

    // ── Language & region ──────────────────────────────────────────
    Component {
        id: language
        WPage {
            WSection {
                title: "Language"
                WCombo {
                    icon: "translate"
                    title: "Display language"
                    description: "Language of the shell and settings"
                    model: Translation.allAvailableLanguages.map(l => ({ displayName: l, value: l }))
                    currentValue: Config.options.language.ui
                    onSelected: v => Config.options.language.ui = v
                }
            }
            WSection {
                title: "Region"
                WCombo {
                    icon: "calendar_view_week"
                    title: "First day of the week"
                    model: [{ displayName: "Monday", value: "en-GB" }, { displayName: "Sunday", value: "en-US" }]
                    currentValue: Config.options.calendar.locale
                    onSelected: v => Config.options.calendar.locale = v
                }
                WToggle {
                    icon: "straighten"
                    title: "Use US units for weather"
                    description: "Fahrenheit and miles"
                    checked: Config.options.bar.weather.useUSCS
                    onToggled: v => Config.options.bar.weather.useUSCS = v
                }
            }
        }
    }
}
