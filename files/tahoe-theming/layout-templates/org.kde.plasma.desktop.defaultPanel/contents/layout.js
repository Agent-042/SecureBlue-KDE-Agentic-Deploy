var panel = new Panel
var panelScreen = panel.screen

panel.location = "bottom"
panel.lengthMode = "fit"
panel.alignment = "center"
panel.floating = true
panel.hiding = "none"
panel.height = 2 * Math.ceil(gridUnit * 3.5 / 2)

// Task Manager — canonical 8 launchers, apps append to right
var tasks = panel.addWidget("org.kde.plasma.icontasks")
tasks.currentConfigGroup = ["General"]
tasks.writeConfig("launchers", "applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop,applications:org.kde.kwrite.desktop,applications:systemsettings.desktop,applications:trivalent.desktop,applications:org.kde.spectacle.desktop,applications:openwebui.desktop,applications:openhands.desktop")
tasks.writeConfig("sortingStrategy", 0)
tasks.writeConfig("groupingStrategy", 0)
tasks.writeConfig("separateLaunchers", false)
tasks.writeConfig("launchInPlace", true)
tasks.writeConfig("maxStripes", 1)
tasks.writeConfig("showOnlyCurrentDesktop", false)
tasks.writeConfig("showOnlyCurrentActivity", false)
tasks.writeConfig("wheelEnabled", "AllTask")
tasks.writeConfig("middleClickAction", "Close")

// Static spacer (visual separator, non-expanding)
var separator = panel.addWidget("org.kde.plasma.panelspacer")
separator.currentConfigGroup = ["Configuration", "General"]
separator.writeConfig("expanding", false)
separator.writeConfig("length", 20)

// Trashcan (pinned to absolute right)
var trash = panel.addWidget("org.kde.plasma.trash")
