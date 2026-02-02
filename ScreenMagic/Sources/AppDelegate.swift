import AppKit
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var screenshotManager: ScreenshotManager!
    private var drawingWindowController: DrawingWindowController?
    private var configWindowController: ConfigWindowController?
    private var hotKeyRef: EventHotKeyRef?
    private var copyHotKeyRef: EventHotKeyRef?
    
    // Hot key IDs
    private let screenshotHotKeyID = UInt32(1)
    private let copyHotKeyID = UInt32(2)
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupScreenshotManager()
        setupHotKeys()
        
        // Request screen recording permission
        requestScreenCapturePermission()
        
        // Check accessibility permission
        checkAccessibilityPermission()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotKeys()
    }
    
    // MARK: - Status Bar Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "ScreenMagic")
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Take Screenshot", action: #selector(takeScreenshot), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Configuration...", action: #selector(openConfiguration), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About ScreenMagic", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit ScreenMagic", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    private func setupScreenshotManager() {
        screenshotManager = ScreenshotManager()
    }
    
    // MARK: - Hot Key Setup using Carbon
    
    private func setupHotKeys() {
        // Install event handler for hot keys
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            DispatchQueue.main.async {
                if hotKeyID.id == appDelegate.screenshotHotKeyID {
                    appDelegate.takeScreenshot()
                } else if hotKeyID.id == appDelegate.copyHotKeyID {
                    appDelegate.copyToClipboard()
                }
            }
            
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
        
        registerHotKeys()
    }
    
    func registerHotKeys() {
        unregisterHotKeys()
        
        let config = ConfigManager.shared.config
        
        // Register screenshot hotkey
        var screenshotHotKeyID = EventHotKeyID(signature: OSType(0x534D4147), id: self.screenshotHotKeyID) // "SMAG"
        let screenshotKeyCode = UInt32(config.screenshotKeyCode)
        let screenshotMods = config.screenshotModifiers
        
        let screenshotStatus = RegisterEventHotKey(screenshotKeyCode, screenshotMods, screenshotHotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if screenshotStatus != noErr {
            print("Failed to register screenshot hotkey: \(screenshotStatus)")
        } else {
            print("Registered screenshot hotkey with keycode: \(screenshotKeyCode), modifiers: \(screenshotMods)")
        }
        
        // Register copy hotkey
        var copyHotKeyID = EventHotKeyID(signature: OSType(0x534D4147), id: self.copyHotKeyID)
        let copyKeyCode = UInt32(config.copyKeyCode)
        let copyMods = config.copyModifiers
        
        let copyStatus = RegisterEventHotKey(copyKeyCode, copyMods, copyHotKeyID, GetApplicationEventTarget(), 0, &copyHotKeyRef)
        if copyStatus != noErr {
            print("Failed to register copy hotkey: \(copyStatus)")
        } else {
            print("Registered copy hotkey with keycode: \(copyKeyCode), modifiers: \(copyMods)")
        }
    }
    
    private func unregisterHotKeys() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = copyHotKeyRef {
            UnregisterEventHotKey(ref)
            copyHotKeyRef = nil
        }
    }
    
    // MARK: - Permissions
    
    private func requestScreenCapturePermission() {
        // Trigger permission dialog by attempting a capture
        let _ = CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )
    }
    
    private func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            print("Accessibility permission not granted. Some features may not work.")
        }
    }
    
    private func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = "ScreenMagic needs Screen Recording permission to capture screenshots with application windows.\n\nPlease go to:\nSystem Preferences → Privacy & Security → Screen Recording\n\nThen enable ScreenMagic and restart the app."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Preferences to Screen Recording
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    @objc func takeScreenshot() {
        let config = ConfigManager.shared.config
        
        let image: NSImage?
        
        // Get display list
        let displays = screenshotManager.getDisplayList()
        let isSingleDisplay = displays.count == 1
        
        // Use display 0 if only one display, otherwise use configured index
        let sourceIndex = isSingleDisplay ? 0 : min(config.sourceDisplayIndex, displays.count - 1)
        
        if config.useCustomCaptureArea {
            // Get display bounds to make capture area relative
            let displayID = displays[max(0, sourceIndex)]
            let displayBounds = CGDisplayBounds(displayID)
            
            // Capture custom area relative to selected display
            let rect = CGRect(
                x: Int(displayBounds.origin.x) + config.captureX,
                y: Int(displayBounds.origin.y) + config.captureY,
                width: config.captureWidth,
                height: config.captureHeight
            )
            image = screenshotManager.captureArea(rect: rect)
        } else {
            // Capture full display
            image = screenshotManager.captureDisplay(displayIndex: sourceIndex)
        }
        
        guard let capturedImage = image else {
            print("Failed to capture screenshot")
            showPermissionAlert()
            return
        }
        
        // Add border to the image
        let borderedImage = addBorder(to: capturedImage, border: config.borderSize)
        
        // Show drawing window at configured position
        showDrawingWindow(with: borderedImage, singleDisplay: isSingleDisplay)
    }
    
    private func addBorder(to image: NSImage, border: CGFloat) -> NSImage {
        guard border > 0 else { return image }
        
        let newSize = NSSize(
            width: image.size.width + (border * 2),
            height: image.size.height + (border * 2)
        )
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        
        // Fill with white background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: newSize).fill()
        
        // Draw original image centered
        let imageRect = NSRect(
            x: border,
            y: border,
            width: image.size.width,
            height: image.size.height
        )
        image.draw(in: imageRect)
        
        newImage.unlockFocus()
        
        return newImage
    }
    
    private func showDrawingWindow(with image: NSImage, singleDisplay: Bool = false) {
        let config = ConfigManager.shared.config
        
        // Close existing window if any
        drawingWindowController?.close()
        
        // Calculate window position
        let windowSize = config.windowSize
        
        // Create new drawing window first
        drawingWindowController = DrawingWindowController(
            screenshot: image,
            position: .zero,  // Will be set below
            size: windowSize
        )
        
        guard let window = drawingWindowController?.window else { return }
        
        if config.centerWindow {
            // Get target screen using NSScreen (proper coordinate system for windows)
            let screens = NSScreen.screens
            // Use screen 0 if only one display, otherwise use configured index
            let targetIndex = singleDisplay ? 0 : min(config.targetDisplayIndex, screens.count - 1)
            let targetScreen = screens[max(0, targetIndex)]
            let screenFrame = targetScreen.frame
            
            // Center on target screen
            let x = screenFrame.origin.x + (screenFrame.width - windowSize.width) / 2
            let y = screenFrame.origin.y + (screenFrame.height - windowSize.height) / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.setFrameOrigin(NSPoint(x: config.windowPosition.x, y: config.windowPosition.y))
        }
        
        drawingWindowController?.showWindow(nil)
        
        // Bring window to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func copyToClipboard() {
        drawingWindowController?.copyToClipboard()
    }
    
    @objc private func openConfiguration() {
        if configWindowController == nil {
            configWindowController = ConfigWindowController()
        }
        configWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "ScreenMagic"
        alert.informativeText = "A macOS screenshot annotation tool."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        // Create clickable link
        let linkText = "© by swaibian.com"
        let linkField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 20))
        linkField.isEditable = false
        linkField.isBordered = false
        linkField.isSelectable = true
        linkField.allowsEditingTextAttributes = true
        linkField.backgroundColor = .clear
        linkField.alignment = .center
        
        let attributedString = NSMutableAttributedString(string: linkText)
        let linkRange = (linkText as NSString).range(of: "swaibian.com")
        attributedString.addAttribute(.link, value: "https://www.swaibian.com", range: linkRange)
        attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 13), range: NSRange(location: 0, length: linkText.count))
        linkField.attributedStringValue = attributedString
        
        alert.accessoryView = linkField
        alert.runModal()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
