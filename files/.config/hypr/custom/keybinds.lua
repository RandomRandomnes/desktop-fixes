hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )





-- Super+I: the stock bind runs `qs -p .../end4-pC/settings.qml`, which this fork doesn't have (it uses the
-- Windows-style settings window, settingsW11), so it did nothing. Open that window over IPC instead.
hl.unbind("SUPER + I")
hl.bind("SUPER + I", hl.dsp.exec_cmd("qs -c end4-pC ipc call settings toggle"), { description = "App: Settings app" })

-- Shift+Super+Alt+/: the stock bind opens the upstream welcome window (welcome.qml); this desktop uses the setup
-- assistant instead (the same as Settings › Extras › Run the first-time setup again).
hl.unbind("SHIFT + SUPER + ALT + Slash")
hl.bind("SHIFT + SUPER + ALT + Slash", hl.dsp.exec_cmd("mkdir -p ~/.local/state/setup-wizard && touch ~/.local/state/setup-wizard/pending && qs -p ~/.config/quickshell/end4-pC/setup-wizard.qml"), { description = "Shell: Setup assistant" })
