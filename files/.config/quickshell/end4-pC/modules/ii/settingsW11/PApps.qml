import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    Loader {
        anchors.fill: parent
        sourceComponent: ({ "installed": installed, "defaults": defaults, "startup": startup })[WState.sub] ?? overview
    }

    readonly property string helper: Quickshell.shellPath("modules/ii/settingsW11/defaultapps.py")

    component AppIconImage: IconImage {
        property string iconName
        implicitSize: 28
        source: Quickshell.iconPath(iconName, "application-x-executable")
    }

    // ── Overview ───────────────────────────────────────────────────
    Component {
        id: overview
        WPage {
            WSection {
                WLink { icon: "apps"; title: "Installed apps"; description: "Uninstall and open apps"; sub: "installed" }
                WLink { icon: "app_registration"; title: "Default apps"; description: "Defaults for files and links: browser, file manager, media"; sub: "defaults" }
                WLink { icon: "rocket_launch"; title: "Startup"; description: "Apps that start automatically when you sign in"; sub: "startup" }
            }
            WSection {
                title: "Related"
                WLink { icon: "storefront"; title: "Get more apps"; description: "Opens Discover if installed, otherwise the Arch package search"; chevronIcon: "open_in_new"; action: () => Quickshell.execDetached(["bash", "-c", "command -v plasma-discover >/dev/null && plasma-discover || xdg-open https://archlinux.org/packages/"]) }
                WLink { icon: "terminal"; title: "Default terminal"; description: Config.options.apps.terminal; sub: "defaults" }
            }
        }
    }

    // ── Installed apps ─────────────────────────────────────────────
    Component {
        id: installed
        WPage {
            id: ip
            property string query: ""
            property string sortMode: "name"
            readonly property var apps: {
                const q = ip.query.trim().toLowerCase();
                const l = AppSearch.list.filter(e => !e.noDisplay && (q === "" || e.name.toLowerCase().includes(q) || (e.genericName ?? "").toLowerCase().includes(q)));
                return l.sort((a, b) => a.name.localeCompare(b.name));
            }
            function uninstall(entry) {
                // pacman package (or flatpak) that owns the .desktop file; pacman/flatpak ask to confirm
                const script = `id='${entry.id}'
f=$(find ~/.local/share/applications /usr/share/applications /usr/local/share/applications /var/lib/flatpak/exports/share/applications ~/.local/share/flatpak/exports/share/applications -name "$id.desktop" 2>/dev/null | head -1)
echo "Uninstalling: ${entry.name.replace(/'/g, "")}"; echo "Desktop file: $f"; echo
if [ -z "$f" ]; then echo "Couldn't find its desktop file."; exit 1; fi
case "$f" in
  *flatpak*) flatpak uninstall "$id" ;;
  "$HOME"/*) echo "This is a user app (not from a package). Delete $f to remove it from menus."; ;;
  *) pkg=$(pacman -Qqo "$f") && sudo pacman -Rns "$pkg" ;;
esac`;
                Quickshell.execDetached(["kitty", "-1", "--hold", "bash", "-c", script]);
            }

            WCard {
                icon: "search"
                title: `${ip.apps.length} apps`
                Rectangle {
                    implicitWidth: 300; implicitHeight: 36
                    radius: Appearance.rounding.verysmall
                    color: Appearance.colors.colLayer3
                    border.width: appSearch.activeFocus ? 2 : 0
                    border.color: Appearance.colors.colPrimary
                    TextField {
                        id: appSearch
                        anchors.fill: parent
                        leftPadding: 10
                        background: null
                        placeholderText: "Search apps"
                        placeholderTextColor: Appearance.colors.colSubtext
                        color: Appearance.colors.colOnLayer3
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.small
                        onTextChanged: ip.query = text
                    }
                }
            }

            WSection {
                Repeater {
                    model: ip.apps
                    WCard {
                        id: appRow
                        required property var modelData
                        minHeight: 58
                        title: modelData.name
                        description: modelData.genericName || modelData.comment || ""
                        leading: Component { AppIconImage { iconName: appRow.modelData.icon } }
                        WButton { buttonText: "Open"; onClicked: { appRow.modelData.execute(); GlobalStates.settingsOpen = false; } }
                        WButton { buttonText: "Uninstall"; onClicked: ip.uninstall(appRow.modelData) }
                    }
                }
            }
        }
    }

    // ── Default apps ───────────────────────────────────────────────
    Component {
        id: defaults
        WPage {
            id: dp
            property var data: ({})
            Component.onCompleted: listProc.running = true
            Process {
                id: listProc
                command: ["python3", root.helper, "list"]
                stdout: StdioCollector { onStreamFinished: { try { dp.data = JSON.parse(text) } catch (e) {} } }
            }
            Process {
                id: setProc
                onExited: listProc.running = true
            }
            function setDefault(cat, id) {
                setProc.command = ["python3", root.helper, "set", cat, id];
                setProc.running = true;
            }
            function model(cat) {
                const d = dp.data[cat];
                if (!d) return [];
                const m = d.candidates.map(c => ({ displayName: c.name, value: c.id }));
                if (d.current && !m.some(x => x.value === d.current))
                    m.unshift({ displayName: `${d.current.replace(/\.desktop$/, "")} (current)`, value: d.current });
                if (!d.current) m.unshift({ displayName: "Not set", value: "" });
                return m;
            }

            WSection {
                title: "Set defaults for applications"
                Repeater {
                    model: [
                        ["browser", "Web browser", "language"],
                        ["files", "File manager", "folder"],
                        ["text", "Text editor", "description"],
                        ["image", "Photo viewer", "image"],
                        ["video", "Video player", "movie"],
                        ["music", "Music player", "music_note"],
                        ["pdf", "PDF reader", "picture_as_pdf"],
                        ["mail", "Email", "mail"],
                        ["archive", "Archive manager", "folder_zip"],
                    ]
                    WCombo {
                        required property var modelData
                        icon: modelData[2]
                        title: modelData[1]
                        fieldWidth: 300
                        model: dp.model(modelData[0])
                        currentValue: dp.data[modelData[0]]?.current ?? ""
                        onSelected: v => { if (v) dp.setDefault(modelData[0], v) }
                    }
                }
            }

            WSection {
                title: "Shell"
                WCombo {
                    icon: "terminal"
                    title: "Terminal"
                    description: "Used by the shell and keyboard shortcuts"
                    model: [
                        { displayName: "kitty", value: "kitty -1" },
                        { displayName: "Konsole", value: "konsole" },
                        { displayName: "Alacritty", value: "alacritty" },
                        { displayName: "foot", value: "foot" },
                        { displayName: "WezTerm", value: "wezterm" },
                    ].concat(["kitty -1", "konsole", "alacritty", "foot", "wezterm"].includes(Config.options.apps.terminal) ? [] : [{ displayName: Config.options.apps.terminal, value: Config.options.apps.terminal }])
                    currentValue: Config.options.apps.terminal
                    onSelected: v => Config.options.apps.terminal = v
                }
                WCombo {
                    icon: "monitoring"
                    title: "Task manager"
                    model: [
                        { displayName: "System Monitor (KDE)", value: "plasma-systemmonitor --page-name Processes" },
                        { displayName: "btop (in terminal)", value: "kitty -1 btop" },
                        { displayName: "htop (in terminal)", value: "kitty -1 htop" },
                        { displayName: "Mission Center", value: "missioncenter" },
                    ]
                    currentValue: Config.options.apps.taskManager
                    onSelected: v => Config.options.apps.taskManager = v
                }
            }
        }
    }

    // ── Startup ────────────────────────────────────────────────────
    Component {
        id: startup
        WPage {
            id: sp
            property var scriptApps: []
            Component.onCompleted: scriptProc.running = true
            Process {
                id: scriptProc
                // programs your Hyprland autostart script launches in the background
                command: ["bash", "-c", "grep -oE '^[[:space:]]*[A-Za-z][A-Za-z0-9_.-]+[^|#]*&[[:space:]]*$' ~/.config/hypr/custom/scripts/autostart.sh | awk '{print $1}' | sort -u"]
                stdout: StdioCollector { onStreamFinished: sp.scriptApps = text.trim().split("\n").filter(s => s) }
            }
            readonly property var apps: Config.options.hyprland.autostartApps.apps.filter(a => a.cmd && a.cmd.trim().length > 0)
            function setApps(l) {
                Config.options.hyprland.autostartApps.apps = l;
            }
            function nameFor(cmd) {
                const m = cmd.match(/^gtk-launch\s+(\S+)/);
                const id = m ? m[1] : cmd.split(/\s+/)[0].split("/").pop();
                const e = AppSearch.list.find(x => x.id === id) ?? DesktopEntries.heuristicLookup(id);
                return { name: e?.name ?? id, icon: e?.icon ?? AppSearch.guessIcon(id) };
            }

            WSection {
                WToggle {
                    icon: "rocket_launch"
                    title: "Start apps when I sign in"
                    description: "Apps below open automatically after login"
                    checked: Config.options.hyprland.autostartApps.enable
                    onToggled: v => Config.options.hyprland.autostartApps.enable = v
                }
            }

            WSection {
                title: "Startup apps"
                enabled: Config.options.hyprland.autostartApps.enable
                Repeater {
                    model: sp.apps
                    WCard {
                        id: su
                        required property var modelData
                        required property int index
                        readonly property var info: sp.nameFor(modelData.cmd)
                        minHeight: 58
                        title: info.name
                        description: `Workspace ${modelData.workspace ?? 1}` + ((modelData.delay ?? 0) > 0 ? ` · then wait ${modelData.delay}s` : "")
                        leading: Component { AppIconImage { iconName: su.info.icon } }
                        WButton {
                            buttonText: "Remove"
                            onClicked: sp.setApps(sp.apps.filter((_, k) => k !== su.index))
                        }
                    }
                }
                WCard {
                    visible: sp.apps.length === 0
                    icon: "inbox"
                    title: "No startup apps yet"
                }
                WCard {
                    icon: "add_circle"
                    title: "Add a startup app"
                    Rectangle {
                        implicitWidth: 280; implicitHeight: 36
                        radius: Appearance.rounding.verysmall
                        color: Appearance.colors.colLayer3
                        border.width: addSearch.activeFocus ? 2 : 0
                        border.color: Appearance.colors.colPrimary
                        TextField {
                            id: addSearch
                            anchors.fill: parent
                            leftPadding: 10
                            background: null
                            placeholderText: "Type an app name"
                            placeholderTextColor: Appearance.colors.colSubtext
                            color: Appearance.colors.colOnLayer3
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
                Repeater {
                    model: addSearch.text.trim().length === 0 ? [] : AppSearch.fuzzyQuery(addSearch.text).filter(e => !e.noDisplay).slice(0, 6)
                    WCard {
                        id: cand
                        required property var modelData
                        Layout.leftMargin: 28
                        minHeight: 52
                        clickable: true
                        title: modelData.name
                        leading: Component { AppIconImage { iconName: cand.modelData.icon; implicitSize: 24 } }
                        onClicked: {
                            sp.setApps(sp.apps.concat([{ cmd: `gtk-launch ${modelData.id}`, delay: 0, workspace: 1 }]));
                            addSearch.text = "";
                        }
                        MaterialSymbol { text: "add"; iconSize: 20; color: Appearance.colors.colPrimary }
                    }
                }
            }

            WSection {
                title: "Also started by your autostart script"
                visible: sp.scriptApps.length > 0
                WCard {
                    icon: "description"
                    title: sp.scriptApps.join(", ")
                    description: "~/.config/hypr/custom/scripts/autostart.sh"
                    WButton { buttonText: "Edit script"; onClicked: Quickshell.execDetached(["xdg-open", `${FileUtils.trimFileProtocol(Directories.config)}/hypr/custom/scripts/autostart.sh`]) }
                }
            }
        }
    }
}
