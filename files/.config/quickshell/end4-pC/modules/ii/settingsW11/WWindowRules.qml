import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Settings › Apps › Window rules (2026-10-08, ours): how an app's windows open (floating, size, position,
 * workspace, monitor, opacity, pinned, maximized/fullscreen, no title bar). The rules are stored and applied by
 * ~/.local/bin/window-rules (your own file, loaded after Phoenix's rules; updates never touch it).
 */
WPage {
    id: page

    readonly property string tool: `${Quickshell.env("HOME")}/.local/bin/window-rules`
    property var rules: []
    property var openWindows: []
    property var draft: null          // the rule being edited (a copy), null = list view
    property int draftIndex: -1       // -1 = new rule
    property string status: ""
    property bool statusError: false
    property bool saving: false
    property string lastAction: "edit"   // "edit" | "toggle" | "delete": for the status line

    readonly property var sizeOptions: [
        { displayName: "Don't change", value: "" }, { displayName: "Small (30 × 40 %)", value: "30x40" },
        { displayName: "Medium (50 × 60 %)", value: "50x60" }, { displayName: "Large (70 × 80 %)", value: "70x80" },
        { displayName: "Half the screen (50 × 90 %)", value: "50x90" }]
    readonly property var positionOptions: [
        { displayName: "Don't change", value: "" }, { displayName: "Center", value: "center" },
        { displayName: "Top left", value: "top-left" }, { displayName: "Top right", value: "top-right" },
        { displayName: "Bottom left", value: "bottom-left" }, { displayName: "Bottom right", value: "bottom-right" }]
    readonly property var stateOptions: [
        { displayName: "Normal", value: "" }, { displayName: "Maximized", value: "maximize" }, { displayName: "Fullscreen", value: "fullscreen" }]
    // 10 per screen: with "Own workspaces for each screen" the second screen uses 11-20, the third 21-30
    readonly property var workspaceOptions: [{ displayName: "Don't change", value: "" }].concat(
        Array.from({ length: 10 * Math.max(1, Hyprland.monitors.values.length) }, (_, i) => i + 1)
            .map(n => ({ displayName: `Workspace ${n}`, value: `${n}` })))
    readonly property var monitorOptions: [{ displayName: "Don't change", value: "" }].concat(
        Hyprland.monitors.values.map(m => ({ displayName: m.name, value: m.name })))

    Component.onCompleted: { listProc.running = true; windowsProc.running = true }

    function iconFor(cls) {
        const e = AppSearch.list.find(x => x.id === cls || (x.id ?? "").toLowerCase() === (cls ?? "").toLowerCase())
            ?? DesktopEntries.heuristicLookup(cls)
        return e?.icon ?? AppSearch.guessIcon(cls)
    }
    function summary(r) {
        const s = []
        if (r.fullscreen) s.push("fullscreen"); else if (r.maximize) s.push("maximized")
        else if (r.float || r.pin || r.position || r.center || r.width) s.push("floating")
        if (r.width) s.push(`${r.width} × ${r.height} %`)
        if (r.position) s.push(positionOptions.find(p => p.value === r.position)?.displayName.toLowerCase() ?? "")
        else if (r.center) s.push("centered")
        if (r.workspace) s.push(`workspace ${r.workspace}` + (r.silent ? " (background)" : ""))
        if (r.monitor) s.push(`on ${r.monitor}`)
        if (r.opacity) s.push(`${Math.round(r.opacity * 100)} % opacity`)
        if (r.pin) s.push("on every workspace")
        if (r.noTitleBar) s.push("no title bar")
        return s.length ? s.join(" · ") : "No changes yet"
    }
    function edit(i) {
        page.draftIndex = i
        page.draft = i >= 0 ? JSON.parse(JSON.stringify(page.rules[i])) : { enabled: true, matchBy: "class", match: "", app: "" }
        page.status = ""
        windowsProc.running = true
    }
    function setDraft(key, value) {
        const d = JSON.parse(JSON.stringify(page.draft))
        if (value === "" || value === false || value === null || value === undefined) delete d[key]; else d[key] = value
        page.draft = d
    }
    function save(list) {
        page.saving = true
        page.status = "Saving…"
        page.statusError = false
        saveProc.command = ["bash", "-c", `printf '%s' "$1" | "${page.tool}" save`, "_", JSON.stringify(list)]
        saveProc.running = true
    }
    function saveDraft() {
        if (!page.draft.match || !page.draft.match.trim()) { page.status = "Choose an app first."; page.statusError = true; return }
        page.lastAction = "edit"
        const l = page.rules.slice()
        if (page.draftIndex >= 0) l[page.draftIndex] = page.draft; else l.push(page.draft)
        page.save(l)
    }

    Process {
        id: listProc
        command: [page.tool, "list"]
        stdout: StdioCollector { onStreamFinished: { try { page.rules = JSON.parse(text) } catch (e) { page.rules = [] } } }
    }
    Process {
        id: windowsProc
        command: [page.tool, "windows"]
        stdout: StdioCollector { onStreamFinished: { try { page.openWindows = JSON.parse(text) } catch (e) { page.openWindows = [] } } }
    }
    Process {
        id: saveProc
        stdout: StdioCollector {
            onStreamFinished: {
                page.saving = false
                let r = { ok: false, errors: ["no answer from window-rules"] }
                try { r = JSON.parse(text) } catch (e) {}
                if (r.ok) {
                    // the message fits what was done (QA 2026-10-09: "follow the rule" stayed after a delete or switch-off)
                    page.status = r.note ? `Saved; ${r.note}.` : page.lastAction === "edit" ? "Saved and applied. New windows of this app follow the rule."
                        : page.lastAction === "delete" ? "Rule removed." : "Saved."
                    page.statusError = false
                    page.draft = null
                } else {
                    page.status = "Hyprland didn't accept the rule: " + (r.errors ?? []).join(" ")
                    page.statusError = true
                }
                listProc.running = true
            }
        }
    }

    // ── list ──
    WSection {
        visible: page.draft === null
        WCard {
            icon: "select_window"
            title: "Window rules"
            description: "Choose how an app's windows open: floating, size and position, workspace, monitor, transparency, or always maximized. Rules apply to windows opened after saving."
            WButton { buttonText: "Add rule"; iconName: "add"; accent: true; onClicked: page.edit(-1) }
        }
        StyledText {
            visible: page.status !== ""
            Layout.fillWidth: true
            Layout.leftMargin: 4
            wrapMode: Text.Wrap
            text: page.status
            color: page.statusError ? Appearance.colors.colError : Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }
    }
    WSection {
        visible: page.draft === null
        title: page.rules.length ? "Your rules" : ""
        StyledText {
            visible: page.rules.length === 0
            Layout.leftMargin: 4
            text: "No rules yet."
            color: Appearance.colors.colSubtext
        }
        Repeater {
            model: page.rules
            WCard {
                id: ruleCard
                required property var modelData
                required property int index
                title: modelData.app || modelData.match
                description: (modelData.enabled === false ? "Off · " : "") + page.summary(modelData)
                leading: Component {
                    IconImage { implicitSize: 28; source: Quickshell.iconPath(page.iconFor(ruleCard.modelData.match), "application-x-executable") }
                }
                StyledSwitch {
                    checked: ruleCard.modelData.enabled !== false
                    onClicked: {
                        // inside onClicked the switch has already flipped: `checked` is the new state (QA 2026-10-08:
                        // `!checked` saved the old one, so the switch never changed the rule)
                        const l = JSON.parse(JSON.stringify(page.rules))
                        l[ruleCard.index].enabled = checked
                        page.lastAction = "toggle"
                        page.save(l)
                        checked = Qt.binding(() => ruleCard.modelData.enabled !== false)
                    }
                }
                WButton { buttonText: "Edit"; onClicked: page.edit(ruleCard.index) }
                WButton {
                    iconName: "delete"; buttonText: ""
                    onClicked: { const l = page.rules.slice(); l.splice(ruleCard.index, 1); page.lastAction = "delete"; page.save(l) }
                }
            }
        }
    }

    // ── editor ──
    WSection {
        visible: page.draft !== null
        title: page.draftIndex >= 0 ? "Edit rule" : "New rule"
        WCombo {
            icon: "apps"
            title: "App"
            description: page.draft && page.draft.match ? (page.draft.matchBy === "title" ? `Windows whose title contains "${page.draft.match}"` : `App: ${page.draft.match}`)
                : "Pick an open window, or type the app below"
            fieldWidth: 260
            model: [{ displayName: "Pick an open window…", value: "" }].concat(page.openWindows.map(w => {
                const name = DesktopEntries.heuristicLookup(w.class)?.name
                return { displayName: name && name !== w.class ? `${name} (${w.class})` : w.class, value: w.class }
            }))
            currentValue: page.draft && page.draft.matchBy !== "title" && page.openWindows.some(w => w.class === page.draft.match) ? page.draft.match : ""
            onSelected: v => {
                if (!v) return
                const w = page.openWindows.find(x => x.class === v)
                const d = JSON.parse(JSON.stringify(page.draft))
                d.matchBy = "class"; d.match = v
                d.app = (DesktopEntries.heuristicLookup(v)?.name) || v
                page.draft = d
            }
        }
        WToggle {
            icon: "title"
            title: "Match the window title instead"
            description: "For apps whose windows all share one class: the rule applies to windows whose title contains the text below"
            checked: page.draft?.matchBy === "title"
            onToggled: v => page.setDraft("matchBy", v ? "title" : "class")
        }
        WCard {
            icon: "edit"
            title: page.draft?.matchBy === "title" ? "Title contains" : "Or type the app"
            description: page.draft?.matchBy === "title" ? "Text in the window title" : "The app's class, as shown by hyprctl clients"
            MaterialTextField {
                Layout.preferredWidth: 220
                placeholderText: "e.g. org.kde.dolphin"
                text: page.draft?.match ?? ""
                onEditingFinished: {
                    const d = JSON.parse(JSON.stringify(page.draft))
                    d.match = text.trim()
                    if (!d.app || d.app === page.draft.match) d.app = text.trim()
                    page.draft = d
                }
            }
        }
    }
    WSection {
        visible: page.draft !== null
        title: "Size and place"
        WToggle {
            icon: "picture_in_picture"
            title: "Floating"
            description: "A free-moving window (size, position and pinning make it floating too)"
            checked: !!page.draft?.float
            onToggled: v => page.setDraft("float", v)
        }
        WCombo {
            icon: "aspect_ratio"
            title: "Size"
            description: "Share of the screen"
            model: page.sizeOptions
            currentValue: page.draft?.width ? `${page.draft.width}x${page.draft.height}` : ""
            onSelected: v => {
                const d = JSON.parse(JSON.stringify(page.draft))
                if (v) { const p = v.split("x"); d.width = Number(p[0]); d.height = Number(p[1]) } else { delete d.width; delete d.height }
                page.draft = d
            }
        }
        WCombo {
            icon: "drag_pan"
            title: "Position"
            model: page.positionOptions
            currentValue: page.draft?.position ?? (page.draft?.center ? "center" : "")
            onSelected: v => {
                const d = JSON.parse(JSON.stringify(page.draft))
                delete d.position; delete d.center
                if (v === "center") d.center = true; else if (v) d.position = v
                page.draft = d
            }
        }
        WCombo {
            icon: "fullscreen"
            title: "Window state"
            model: page.stateOptions
            currentValue: page.draft?.fullscreen ? "fullscreen" : page.draft?.maximize ? "maximize" : ""
            onSelected: v => {
                const d = JSON.parse(JSON.stringify(page.draft))
                delete d.fullscreen; delete d.maximize
                if (v) d[v] = true
                page.draft = d
            }
        }
    }
    WSection {
        visible: page.draft !== null
        title: "Where it opens"
        WCombo {
            icon: "workspaces"
            title: "Workspace"
            model: page.workspaceOptions
            currentValue: page.draft?.workspace ?? ""
            onSelected: v => page.setDraft("workspace", v)
        }
        WToggle {
            visible: !!page.draft?.workspace
            icon: "visibility_off"
            title: "Open in the background"
            description: "Stay on the current workspace when the app opens"
            checked: !!page.draft?.silent
            onToggled: v => page.setDraft("silent", v)
        }
        WCombo {
            visible: page.monitorOptions.length > 2
            icon: "desktop_windows"
            title: "Monitor"
            model: page.monitorOptions
            currentValue: page.draft?.monitor ?? ""
            onSelected: v => page.setDraft("monitor", v)
        }
        WToggle {
            icon: "push_pin"
            title: "Show on every workspace"
            description: "Pinned: the window stays visible when switching workspaces"
            checked: !!page.draft?.pin
            onToggled: v => page.setDraft("pin", v)
        }
    }
    WSection {
        visible: page.draft !== null
        title: "Look"
        WSlider {
            icon: "opacity"
            title: "Opacity"
            from: 0.3; to: 1; stepSize: 0.05
            value: page.draft?.opacity ?? 1
            onMoved: v => page.setDraft("opacity", v >= 0.99 ? "" : Math.round(v * 100) / 100)
        }
        WToggle {
            visible: Config.options.extras.windowsStyle !== false
            icon: "title"
            title: "No title bar"
            description: "Hide the title bar with the close, maximize and minimize buttons for this app"
            checked: !!page.draft?.noTitleBar
            onToggled: v => page.setDraft("noTitleBar", v)
        }
    }
    WSection {
        visible: page.draft !== null
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: page.status
                color: page.statusError ? Appearance.colors.colError : Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
            WButton { buttonText: "Cancel"; onClicked: { page.draft = null; page.status = "" } }
            WButton { buttonText: page.saving ? "Saving…" : "Save"; accent: true; enabled: !page.saving; onClicked: page.saveDraft() }
        }
    }
}
