hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )





-- Super+I: the stock bind runs `qs -p .../end4-pC/settings.qml`, which this fork doesn't have (it uses the
-- Windows-style settings window, settingsW11), so it did nothing. Open that window over IPC instead.
hl.unbind("SUPER + I")
hl.bind("SUPER + I", hl.dsp.exec_cmd("qs -c end4-pC ipc call settings toggle"), { description = "App: Settings app" })
