var desktop = new Activity
desktop.wallpaperPlugin = "org.kde.image"

// Top panel (menu bar)
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
dock.alignment = "center"
dock.floating = true
dock.hiding = "none"
dock.lengthMode = "custom"
dock.minimumLength = 0
dock.maximumLength = 3840
dock.height = 2 * Math.ceil(gridUnit * 3.5 / 2)

var tasks = dock.addWidget("org.kde.plasma.icontasks")
tasks.currentConfigGroup = ["General"]
tasks.writeConfig("launchers", "applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop,applications:org.kde.kwrite.desktop,applications:systemsettings.desktop,applications:trivalent.desktop,applications:org.kde.spectacle.desktop,applications:org.mozilla.Thunderbird.desktop,applications:com.vscodium.codium.desktop")
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
