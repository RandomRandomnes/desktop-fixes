import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Settings › System › Report a problem (2026-10-08, ours): you describe what went wrong, ~/.local/bin/phoenix-report
 * adds the system details (versions, phoenix/custom-update status, a desktop check) with personal data
 * removed, you read it, then it opens a new GitHub issue with everything filled in. Nothing is sent by Phoenix itself.
 */
WPage {
    id: page

    readonly property string tool: `${Quickshell.env("HOME")}/.local/bin/phoenix-report`
    property var report: null         // {path, title, body, url, paste} once made
    property bool busy: false
    property bool copied: false

    Process {
        id: makeProc
        stdout: StdioCollector {
            onStreamFinished: {
                page.busy = false
                try { page.report = JSON.parse(text) } catch (e) { page.report = null; errText.text = "Making the report failed." }
            }
        }
    }
    Timer { id: copiedTimer; interval: 1500; onTriggered: page.copied = false }

    WSection {
        WCard {
            icon: "bug_report"
            title: "Report a problem"
            description: "Describe what went wrong. Phoenix adds details about your system and removes personal data "
                + "(user name, computer name, network and drive names, addresses). You see the whole report before anything is posted."
        }
    }

    WSection {
        title: "What went wrong?"
        visible: page.report === null
        MaterialTextArea {
            id: noteInput
            Layout.fillWidth: true
            Layout.minimumHeight: 120
            wrapMode: TextEdit.Wrap
            placeholderText: "What happened, what you expected, and what you did just before (the first line becomes the title)"
        }
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                id: errText
                Layout.fillWidth: true
                color: Appearance.colors.colError
                font.pixelSize: Appearance.font.pixelSize.small
                text: ""
            }
            WButton {
                accent: true
                iconName: page.busy ? "hourglass_top" : "description"
                buttonText: page.busy ? "Checking the desktop…" : "Create report"
                enabled: !page.busy
                onClicked: {
                    errText.text = ""
                    page.busy = true
                    makeProc.command = ["bash", "-c", 'printf %s "$1" | "$0" make -', page.tool, noteInput.text]
                    makeProc.running = true
                }
            }
        }
    }

    WSection {
        title: "Your report"
        visible: page.report !== null
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 340
            radius: Appearance.rounding.verysmall + 2
            color: Appearance.colors.colLayer2
            StyledFlickable {
                id: flick
                anchors { fill: parent; margins: 12 }
                clip: true
                contentHeight: bodyText.implicitHeight
                TextEdit {
                    id: bodyText
                    width: flick.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    text: page.report ? `# ${page.report.title}\n\n${page.report.body}` : ""
                    color: Appearance.colors.colOnLayer2
                    selectionColor: Appearance.colors.colSecondaryContainer
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
        }
        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            text: "Open on GitHub starts a new public issue with this report filled in"
                + (page.report?.paste ? " (it's long, so it is copied to your clipboard: paste it into the issue)" : "")
                + ". Posting needs a free GitHub account. A copy is kept in ~/.local/state/phoenix/reports."
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            WButton {
                buttonText: "Start over"
                iconName: "arrow_back"
                onClicked: page.report = null
            }
            Item { Layout.fillWidth: true }
            WButton {
                buttonText: page.copied ? "Copied" : "Copy"
                iconName: page.copied ? "check" : "content_copy"
                onClicked: {
                    Quickshell.clipboardText = bodyText.text
                    page.copied = true
                    copiedTimer.restart()
                }
            }
            WButton {
                accent: true
                buttonText: "Open on GitHub"
                iconName: "open_in_new"
                onClicked: {
                    if (page.report.paste) Quickshell.clipboardText = page.report.body
                    Quickshell.execDetached(["xdg-open", page.report.url])
                }
            }
        }
    }
}
