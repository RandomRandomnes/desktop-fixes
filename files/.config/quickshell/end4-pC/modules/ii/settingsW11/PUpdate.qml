import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Windows Update equivalent: pacman/AUR via ~/.local/bin/system-update, shell via hypr-guard.
WPage {
    id: page
    property string running: ""
    property string installed: ""
    property var history: []
    property string guardStatus: ""
    property string lastSync: ""

    function refreshInfo() { infoProc.running = true; }
    Component.onCompleted: { refreshInfo(); Updates.refresh(); whatsNewProc.running = true; }

    // "What's new": notes of the fixes installed since they were last read (custom-update whats-new)
    property var whatsNew: []
    Process {
        id: whatsNewProc
        command: ["bash", "-c", "~/.local/bin/custom-update whats-new"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const d = JSON.parse(text); page.whatsNew = d.unread ? d.items : [] } catch (e) { page.whatsNew = [] }
            }
        }
    }
    Connections {   // Settings keeps this page loaded: look again each time Settings opens
        target: GlobalStates
        function onSettingsOpenChanged() { if (GlobalStates.settingsOpen) whatsNewProc.running = true }
    }
    Process {
        id: whatsNewSeenProc
        command: ["bash", "-c", "~/.local/bin/custom-update whats-new --seen"]
        onExited: page.whatsNew = []
    }

    Process {
        id: infoProc
        // the running kernel's package (linux, linux-lts, linux-zen, …) and whether its modules are still there:
        // pacman removes /usr/lib/modules/<running version> when that kernel is upgraded (F19)
        command: ["bash", "-c", `uname -r
k=linux; for f in lts zen hardened rt; do case "$(uname -r)" in *-$f) k=linux-$f;; esac; done; pacman -Q $k 2>/dev/null | awk '{print $2}'
[ -d "/usr/lib/modules/$(uname -r)" ] && echo current || echo pending
grep -E '\\[ALPM\\] (upgraded|installed|removed) ' /var/log/pacman.log | tail -n 14 | tac
echo '---'
head -n 1 ~/hypr-guard/report.md 2>/dev/null
date -r /var/lib/pacman/sync/core.db '+%b %-d, %-I:%M %p' 2>/dev/null`]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n---\n");
                const head = parts[0].split("\n");
                page.running = head[0] ?? "";
                page.installed = head[1] ?? "";
                page.kernelState = head[2] ?? "";
                page.history = head.slice(3).filter(l => l).map(l => {
                    const m = l.match(/^\[([^\]]+)\] \[ALPM\] (\w+) (\S+) \((.*)\)$/);
                    return m ? { date: m[1].substring(0, 16).replace("T", " "), action: m[2], pkg: m[3], ver: m[4] } : null;
                }).filter(x => x);
                const tail = (parts[1] ?? "").split("\n");
                page.guardStatus = (tail[0] ?? "").trim();
                page.lastSync = (tail[1] ?? "").trim();
            }
        }
    }

    property string kernelState: ""
    readonly property bool rebootPending: kernelState === "pending"

    Process {
        id: updateProc
        command: ["kitty", "fish", "-i", "-l", "-c", "~/.local/bin/system-update"]
        onExited: { Updates.refresh(); page.refreshInfo(); whatsNewProc.running = true; }
    }
    Process {
        id: doctorProc
        command: ["bash", "-c", "~/.local/bin/hypr-guard doctor"]
        onExited: page.refreshInfo()
    }

    // Status banner
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 110
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        RowLayout {
            anchors { fill: parent; leftMargin: 24; rightMargin: 20 }
            spacing: 20
            MaterialSymbol {
                Layout.preferredWidth: 52
                horizontalAlignment: Text.AlignHCenter
                text: page.rebootPending ? "restart_alt" : Updates.count > 0 ? "download" : "check_circle"
                iconSize: 48
                fill: 1
                color: Appearance.colors.colPrimary
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    text: page.rebootPending ? "Restart required"
                        : Updates.checking ? "Checking for updates…"
                        : !Updates.available ? "Can't check for updates"
                        : Updates.count > 0 ? `${Updates.count} updates available` : "You're up to date"
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer2
                }
                StyledText {
                    text: page.rebootPending ? `A new kernel (${page.installed}) is installed. Restart to start using it.`
                        : `Last synced: ${page.lastSync || "unknown"}`
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }
            WButton {
                visible: page.rebootPending
                buttonText: "Restart now"
                onClicked: { GlobalStates.settingsOpen = false; GlobalStates.sessionOpen = true; }
            }
            WButton {
                buttonText: Updates.checking ? "Checking…" : "Check for updates"
                enabled: !Updates.checking
                onClicked: { Updates.refresh(); page.refreshInfo(); }
            }
            WButton {
                accent: true
                visible: Updates.count > 0 || updateProc.running
                buttonText: updateProc.running ? "Installing…" : "Install all"
                iconName: "download"
                enabled: !updateProc.running && Updates.count > 0
                onClicked: updateProc.running = true
            }
        }
    }

    WSection {
        visible: page.whatsNew.length > 0
        title: "What's new"
        Repeater {
            model: page.whatsNew.slice().reverse()   // newest first
            WCard {
                required property var modelData
                icon: modelData.line === "system" ? "build" : "new_releases"
                title: (modelData.line === "system" ? "System fix " : "Phoenix ") + modelData.label
                    + (modelData.date ? ` · ${modelData.date}` : "")
                description: modelData.notes.map(n => "• " + n).join("\n")
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            WButton { buttonText: "Got it"; accent: true; onClicked: whatsNewSeenProc.running = true }
        }
    }

    WSection {
        title: "What gets updated"
        WCard {
            icon: "deployed_code_update"
            title: "System packages"
            description: "Arch Linux packages and AUR apps (pacman + yay). You'll be asked for your password once."
        }
        WCard {
            icon: "shield"
            title: "Shell (illogical-impulse)"
            description: page.guardStatus ? `Updated safely by hypr-guard, which keeps your customizations · ${page.guardStatus.replace(/^#+\s*/, "")}` : "Updated safely by hypr-guard, which keeps your customizations"
            WButton { buttonText: doctorProc.running ? "Checking…" : "Run health check"; enabled: !doctorProc.running; onClicked: doctorProc.running = true }
            WButton { buttonText: "View report"; onClicked: Quickshell.execDetached(["xdg-open", `${Quickshell.env("HOME")}/hypr-guard/report.md`]) }
        }
        WCard {
            icon: "memory"
            title: "Kernel"
            description: `Running ${page.running}` + (page.rebootPending ? ` · ${page.installed} installed` : "")
        }
    }

    // ── custom bug fixes + major versions (~/.local/bin/custom-update, custom-publish; 2026-10-03) ──
    // Bug fixes (x.1 / x.01) for the installed version install with the normal updates. A new major version is
    // only offered here, explained, with a warning, and installed when the person asks (two clicks).
    property var offers: ({})            // custom-update offers --json
    readonly property var sysFixes: offers.system || ({})   // system line: pending / waiting / partial / applied
    property var preview: ({})           // the sandbox "friend's PC" (publisher only)
    property bool isPublisher: false
    property string previewMsg: ""
    readonly property string fixBin: `${Quickshell.env("HOME")}/.local/bin`

    function refreshFixes() {
        offersProc.running = true
        if (page.isPublisher) previewProc.running = true
    }
    function term(cmd, title) {
        Quickshell.execDetached(["kitty", "--title", title, "--", "bash", "-c", `${cmd}; echo; read -r -p 'Press Enter to close.'`])
    }

    Process {
        running: true
        command: ["test", "-d", `${Quickshell.env("HOME")}/.local/state/custom-fixes-publisher`]
        onExited: (code, status) => { page.isPublisher = code === 0; page.refreshFixes() }
    }
    Process {
        id: offersProc
        command: [`${page.fixBin}/custom-update`, "offers", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { page.offers = JSON.parse(text) } catch (e) { page.offers = ({}) } } }
    }
    Process {
        id: previewProc
        command: [`${page.fixBin}/custom-publish`, "preview", "offers"]
        stdout: StdioCollector { onStreamFinished: { try { page.preview = JSON.parse(text) } catch (e) { page.preview = ({}) } } }
    }
    Process {   // sandbox actions (preview PC): the last output line is shown under the preview
        id: previewRun
        stdout: StdioCollector { onStreamFinished: page.previewMsg = text.trim().split("\n").pop() }
        onExited: page.refreshFixes()
    }

    // "Version N is available" with what it is, what it changes and the risk; Upgrade needs a second click
    component UpgradeCard: Rectangle {
        id: up
        required property var info
        property bool sandbox: false
        property bool armed: false
        signal upgrade(string label)
        readonly property var u: info.upgrade || null
        visible: !!u
        Layout.fillWidth: true
        implicitHeight: upCol.implicitHeight + 36
        radius: Appearance.rounding.normal
        color: Appearance.colors.colPrimaryContainer
        border.width: 2
        border.color: Appearance.colors.colPrimary
        Timer { id: disarm; interval: 5000; onTriggered: up.armed = false }
        ColumnLayout {
            id: upCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 8
            RowLayout {
                spacing: 10
                MaterialSymbol { text: "new_releases"; fill: 1; iconSize: 26; color: Appearance.colors.colOnPrimaryContainer }
                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: up.u ? `Version ${up.u.major} is available${up.u.upgrade.title ? ": " + up.u.upgrade.title : ""}${up.u.test ? "  (test release)" : ""}` : ""
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: up.u ? (up.u.upgrade.summary || "") : ""
                color: Appearance.colors.colOnPrimaryContainer
            }
            StyledText {
                visible: !!(up.u && up.u.upgrade.details && up.u.upgrade.details.length)
                text: "Changes"
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnPrimaryContainer
            }
            Repeater {
                model: up.u && up.u.upgrade.details ? up.u.upgrade.details : []
                StyledText {
                    required property var modelData
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "•  " + modelData
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }
            Rectangle {   // the risk, impossible to miss
                Layout.fillWidth: true
                Layout.topMargin: 4
                implicitHeight: riskRow.implicitHeight + 20
                radius: Appearance.rounding.small
                color: Appearance.colors.colErrorContainer
                RowLayout {
                    id: riskRow
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                    spacing: 10
                    MaterialSymbol { text: "warning"; fill: 1; iconSize: 22; color: Appearance.colors.colOnErrorContainer }
                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: up.info.risk || ""
                        color: Appearance.colors.colOnErrorContainer
                    }
                }
            }
            RowLayout {
                Layout.topMargin: 4
                spacing: 10
                WButton {
                    accent: true
                    implicitHeight: 40
                    buttonText: up.armed ? `Click again to confirm${up.sandbox ? " (preview system)" : ""}`
                        : `Upgrade to version ${up.u ? up.u.major : ""}${up.sandbox ? " (preview system)" : ""}`
                    onClicked: {
                        if (!up.armed) { up.armed = true; disarm.restart(); return }
                        up.armed = false
                        up.upgrade(up.u.label)
                    }
                }
                StyledText {
                    text: up.u ? `Installs version ${up.u.label}. Without upgrading, bug fixes for the current version continue to be installed.` : ""
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.8
                }
            }
        }
    }

    WSection {
        // system fixes: needed because of Arch / Hyprland / illogical-impulse updates; always on, installed by the
        // update button right after the updates they belong to (custom-update system-apply)
        visible: !page.isPublisher
        title: "System fixes"
        WCard {
            icon: "health_and_safety"
            title: (page.sysFixes.pending || []).length > 0 ? `${page.sysFixes.pending.length} system fix(es) ready`
                : "System fixes are installed automatically"
            description: {
                const s = page.sysFixes
                if (s.error) return `Couldn't check: ${s.error}`
                const parts = []
                for (const r of (s.pending || [])) parts.push(`Ready: ${r.label}: ${(r.notes || []).join("; ")}`)
                for (const p of (s.partial || [])) parts.push(`System fix ${p.label} left ${p.skipped.length} file(s) unchanged; installing the latest custom fixes completes it`)
                for (const w of (s.waiting || [])) parts.push(`Waiting: ${w.label} (${w.reason})`)
                if (parts.length === 0) parts.push((s.applied || []).length > 0 ? `Up to date. Applied: ${s.applied.join(", ")}` : "Up to date")
                return parts.join("\n") + "\nThey fix problems caused by Arch, Hyprland or illogical-impulse updates and install with every update, only on systems with matching versions"
            }
            WButton { buttonText: offersProc.running ? "Checking…" : "Check now"; enabled: !offersProc.running; onClicked: page.refreshFixes() }
            WButton {
                visible: (page.sysFixes.pending || []).length > 0
                accent: true
                buttonText: "Install now"
                onClicked: page.term(`${page.fixBin}/custom-update system-apply`, "System fixes")
            }
        }
    }

    WSection {
        visible: !page.isPublisher
        title: "Custom bug fixes"
        WToggle {
            icon: "build_circle"
            title: "Receive custom bug fixes"
            description: "Signed fixes for the custom features of this system (hypr-guard, Wallpaper Engine, Settings, the setup assistant and others). Bug fixes are installed with regular updates; new major versions are only offered here"
            checked: Config.options.extras.customFixes
            onToggled: v => { Config.options.extras.customFixes = v; page.refreshFixes() }
        }
        WCard {
            visible: Config.options.extras.customFixes
            icon: "verified"
            title: page.offers.installed && page.offers.installed !== "0" ? `Installed: version ${page.offers.installed}` : "Installed: the version included at installation"
            description: page.offers.error ? `Couldn't check: ${page.offers.error}`
                : page.offers.fix ? `Bug fix ${page.offers.fix.label} is ready: ${(page.offers.fix.notes || []).join("; ")}`
                : page.offers.waiting ? `Bug fix ${page.offers.waiting.label} installs after the next update (it needs a newer illogical-impulse shell)`
                : "No bug fixes waiting"
            WButton { buttonText: offersProc.running ? "Checking…" : "Check now"; enabled: !offersProc.running; onClicked: page.refreshFixes() }
            WButton {
                visible: !!page.offers.fix
                accent: true
                buttonText: "Install fix"
                onClicked: page.term(`${page.fixBin}/custom-update apply --yes`, "Bug fixes")
            }
            WButton { buttonText: "Undo last"; onClicked: page.term(`${page.fixBin}/custom-update undo`, "Bug fixes") }
        }
        UpgradeCard {
            info: page.offers
            onUpgrade: label => page.term(`${page.fixBin}/custom-update upgrade ${label} --yes`, "Upgrade")
        }
        WToggle {
            visible: Config.options.extras.customFixes
            icon: "science"
            title: "Receive test releases"
            description: "Also offer test versions. Test versions may be incomplete"
            checked: Config.options.extras.customFixesTest ?? false
            onToggled: v => { Config.options.extras.customFixesTest = v; page.refreshFixes() }
        }
    }

    WSection {
        visible: page.isPublisher
        title: "Custom bug fixes"
        WCard {
            icon: "publish"
            title: "This system publishes the fixes"
            description: "Two release lines: custom fixes (custom-publish publish: --feature +1, --fix +0.1, --minor +0.01) and system fixes for Arch / Hyprland / illogical-impulse updates (custom-publish publish-system, checked against every custom version). Other systems install system fixes always and custom fixes when enabled"
        }
    }

    WSection {
        visible: page.isPublisher
        title: "Testing (publishing system only)"
        WCard {
            icon: "science"
            title: "Test release"
            description: "Publishes a test of the next major version. Only systems that receive test releases (such as the preview system below) are offered it"
            WButton { buttonText: "Publish test version"; onClicked: page.term(`${page.fixBin}/custom-publish make-test`, "Publish test") }
            WButton { buttonText: "Remove test releases"; onClicked: page.term(`${page.fixBin}/custom-publish clear-tests`, "Remove tests") }
        }
        WCard {
            icon: "devices"
            title: "Preview as a receiving system"
            description: (page.preview.installed ? `A simulated system in a sandbox folder, on version ${page.preview.installed}, with test releases enabled. ` : "")
                + "Only the sandbox is modified; the files of this system are not changed."
                + (page.previewMsg !== "" ? `\nLast: ${page.previewMsg}` : "")
                + (page.preview.fix ? `\nBug fix ${page.preview.fix.label} would be installed automatically.` : "")
            WButton { buttonText: previewProc.running ? "Checking…" : "Refresh"; enabled: !previewProc.running; onClicked: page.refreshFixes() }
            WButton {
                buttonText: "Start over"
                onClicked: { page.previewMsg = ""; previewRun.command = [`${page.fixBin}/custom-publish`, "preview", "setup"]; previewRun.running = true }
            }
        }
        UpgradeCard {
            info: page.preview
            sandbox: true
            onUpgrade: label => {
                page.previewMsg = "Upgrading the preview PC…"
                previewRun.command = [`${page.fixBin}/custom-publish`, "preview", "upgrade", label]
                previewRun.running = true
            }
        }
    }

    WSection {
        title: "Advanced options"
        WToggle {
            icon: "notifications_active"
            title: "Check for updates automatically"
            description: "Shows the update count on the taskbar"
            checked: Config.options.updates.enableCheck
            onToggled: v => Config.options.updates.enableCheck = v
        }
        WCombo {
            icon: "schedule"
            title: "Check every"
            model: [30, 60, 120, 240, 720, 1440].map(m => ({ displayName: m < 60 ? `${m} minutes` : m === 60 ? "1 hour" : m === 1440 ? "1 day" : `${m / 60} hours`, value: m }))
            currentValue: Config.options.updates.checkInterval
            onSelected: v => Config.options.updates.checkInterval = v
        }
    }

    WSection {
        title: "Update history"
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: histCol.implicitHeight + 24
            radius: Appearance.rounding.verysmall + 2
            color: Appearance.colors.colLayer2
            ColumnLayout {
                id: histCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: 18 }
                spacing: 6
                Repeater {
                    model: page.history
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 12
                        MaterialSymbol {
                            text: modelData.action === "removed" ? "remove_circle" : modelData.action === "installed" ? "add_circle" : "arrow_circle_up"
                            iconSize: 18
                            color: Appearance.colors.colPrimary
                        }
                        StyledText { Layout.preferredWidth: 230; text: modelData.pkg; color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.small; elide: Text.ElideRight }
                        StyledText { Layout.fillWidth: true; text: modelData.ver; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller; elide: Text.ElideRight }
                        StyledText { text: modelData.date; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
                    }
                }
            }
        }
    }
}
