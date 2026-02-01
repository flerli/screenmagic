import AppKit

// Initialize the application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Run as a menu bar app (no dock icon)
app.setActivationPolicy(.accessory)

app.run()
