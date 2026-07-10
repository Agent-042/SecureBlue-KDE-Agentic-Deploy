var desktop = new Activity
desktop.wallpaperPlugin = "org.kde.image"

// Top panel (menu bar with window buttons for maximized windows)
var topPanel = new Panel
topPanel.location = "top"
topPanel.alignment = "left"
topPanel.floating = true
topPanel.height = 2 * Math.ceil(gridUnit * 2.5 / 2)

// Apple logo / Kickoff
topPanel.addWidget("org.kde.plasma.kickoff")

// Global Menu
topPanel.addWidget("org.kde.plasma.appmenu")

// Spacer
topPanel.addWidget("org.kde.plasma.panelspacer")

// Window buttons (for maximized windows — stoplights appear here when title bar is hidden)
var winButtons = topPanel.addWidget("org.kde.windowbuttons")
winButtons.currentConfigGroup = ["General"]
winButtons.writeConfig("spacing", 4)
winButtons.writeConfig("buttonSize", 14)

// System tray
topPanel.addWidget("org.kde.plasma.systemtray")

// Clock
topPanel.addWidget("org.kde.plasma.digitalclock")

// Bottom dock (already defined in defaultPanel layout.js, but we can add it here too)
// Actually, the defaultPanel layout.js is used when "Add Default Panel" is clicked.
// The desktop shell layout.js creates the initial panels on first login.
// We should define the dock here too for first-login creation.

var dock = new Panel
dock.location = "bottom"
dock.lengthMode = "fit"
dock.alignment = "center"
dock.floating = true
dock.hiding = "none"
dock.height = 2 * Math.ceil(gridUnit * 3.5 / 2)

var tasks = dock.addWidget("org.kde.plasma.icontasks")
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

var separator = dock.addWidget("org.kde.plasma.panelspacer")
separator.currentConfigGroup = ["Configuration", "General"]
separator.writeConfig("expanding", false)
separator.writeConfig("length", 20)

dock.addWidget("org.kde.plasma.trash")
