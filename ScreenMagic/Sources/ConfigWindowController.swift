import AppKit

class ConfigWindowController: NSWindowController {
    
    private var sourceDisplayPopup: NSPopUpButton!
    private var customAreaCheckbox: NSButton!
    private var captureXField: NSTextField!
    private var captureYField: NSTextField!
    private var captureWidthField: NSTextField!
    private var captureHeightField: NSTextField!
    private var captureXLabel: NSTextField!
    private var captureYLabel: NSTextField!
    private var captureWidthLabel: NSTextField!
    private var captureHeightLabel: NSTextField!
    
    private var targetDisplayPopup: NSPopUpButton!
    private var centerCheckbox: NSButton!
    private var positionXLabel: NSTextField!
    private var positionXField: NSTextField!
    private var positionYLabel: NSTextField!
    private var positionYField: NSTextField!
    private var widthField: NSTextField!
    private var heightField: NSTextField!
    private var screenshotKeyButton: KeyCaptureButton!
    private var copyKeyButton: KeyCaptureButton!
    private var borderField: NSTextField!
    private var brushSizeField: NSTextField!
    
    private let screenshotManager = ScreenshotManager()
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "ScreenMagic Configuration"
        window.center()
        
        super.init(window: window)
        
        setupUI()
        loadCurrentConfig()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        let padding: CGFloat = 20
        var yOffset: CGFloat = 670
        
        // Title
        let titleLabel = NSTextField(labelWithString: "ScreenMagic Configuration")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: padding, y: yOffset, width: 400, height: 24)
        contentView.addSubview(titleLabel)
        
        yOffset -= 45
        
        // --- Screenshot Source Display ---
        let sourceSection = createSectionLabel("Screenshot Source")
        sourceSection.frame.origin = CGPoint(x: padding, y: yOffset)
        contentView.addSubview(sourceSection)
        
        yOffset -= 28
        
        let sourceLabel = NSTextField(labelWithString: "Capture Display:")
        sourceLabel.frame = NSRect(x: padding, y: yOffset, width: 110, height: 22)
        contentView.addSubview(sourceLabel)
        
        sourceDisplayPopup = NSPopUpButton(frame: NSRect(x: 140, y: yOffset, width: 300, height: 26))
        populateDisplayPopup(sourceDisplayPopup)
        contentView.addSubview(sourceDisplayPopup)
        
        yOffset -= 28
        
        customAreaCheckbox = NSButton(checkboxWithTitle: "Use custom capture area", target: self, action: #selector(customAreaCheckboxChanged))
        customAreaCheckbox.frame = NSRect(x: padding, y: yOffset, width: 250, height: 22)
        contentView.addSubview(customAreaCheckbox)
        
        yOffset -= 28
        
        captureXLabel = NSTextField(labelWithString: "X:")
        captureXLabel.frame = NSRect(x: padding + 20, y: yOffset, width: 25, height: 22)
        contentView.addSubview(captureXLabel)
        
        captureXField = NSTextField(frame: NSRect(x: padding + 45, y: yOffset, width: 70, height: 22))
        contentView.addSubview(captureXField)
        
        captureYLabel = NSTextField(labelWithString: "Y:")
        captureYLabel.frame = NSRect(x: padding + 125, y: yOffset, width: 25, height: 22)
        contentView.addSubview(captureYLabel)
        
        captureYField = NSTextField(frame: NSRect(x: padding + 150, y: yOffset, width: 70, height: 22))
        contentView.addSubview(captureYField)
        
        captureWidthLabel = NSTextField(labelWithString: "W:")
        captureWidthLabel.frame = NSRect(x: padding + 230, y: yOffset, width: 25, height: 22)
        contentView.addSubview(captureWidthLabel)
        
        captureWidthField = NSTextField(frame: NSRect(x: padding + 255, y: yOffset, width: 70, height: 22))
        contentView.addSubview(captureWidthField)
        
        captureHeightLabel = NSTextField(labelWithString: "H:")
        captureHeightLabel.frame = NSRect(x: padding + 335, y: yOffset, width: 25, height: 22)
        contentView.addSubview(captureHeightLabel)
        
        captureHeightField = NSTextField(frame: NSRect(x: padding + 360, y: yOffset, width: 70, height: 22))
        contentView.addSubview(captureHeightField)
        
        yOffset -= 40
        
        // --- Drawing Window Settings ---
        let windowSection = createSectionLabel("Drawing Window")
        windowSection.frame.origin = CGPoint(x: padding, y: yOffset)
        contentView.addSubview(windowSection)
        
        yOffset -= 28
        
        let targetLabel = NSTextField(labelWithString: "Target Display:")
        targetLabel.frame = NSRect(x: padding, y: yOffset, width: 110, height: 22)
        contentView.addSubview(targetLabel)
        
        targetDisplayPopup = NSPopUpButton(frame: NSRect(x: 140, y: yOffset, width: 300, height: 26))
        populateDisplayPopup(targetDisplayPopup)
        contentView.addSubview(targetDisplayPopup)
        
        yOffset -= 28
        
        centerCheckbox = NSButton(checkboxWithTitle: "Center window on display", target: self, action: #selector(centerCheckboxChanged))
        centerCheckbox.frame = NSRect(x: padding, y: yOffset, width: 250, height: 22)
        contentView.addSubview(centerCheckbox)
        
        yOffset -= 28
        
        positionXLabel = NSTextField(labelWithString: "X:")
        positionXLabel.frame = NSRect(x: padding, y: yOffset, width: 30, height: 22)
        contentView.addSubview(positionXLabel)
        
        positionXField = NSTextField(frame: NSRect(x: 55, y: yOffset, width: 80, height: 22))
        contentView.addSubview(positionXField)
        
        positionYLabel = NSTextField(labelWithString: "Y:")
        positionYLabel.frame = NSRect(x: 150, y: yOffset, width: 30, height: 22)
        contentView.addSubview(positionYLabel)
        
        positionYField = NSTextField(frame: NSRect(x: 180, y: yOffset, width: 80, height: 22))
        contentView.addSubview(positionYField)
        
        yOffset -= 28
        
        let widthLabel = NSTextField(labelWithString: "Width:")
        widthLabel.frame = NSRect(x: padding, y: yOffset, width: 50, height: 22)
        contentView.addSubview(widthLabel)
        
        widthField = NSTextField(frame: NSRect(x: 70, y: yOffset, width: 80, height: 22))
        contentView.addSubview(widthField)
        
        let heightLabel = NSTextField(labelWithString: "Height:")
        heightLabel.frame = NSRect(x: 165, y: yOffset, width: 50, height: 22)
        contentView.addSubview(heightLabel)
        
        heightField = NSTextField(frame: NSRect(x: 220, y: yOffset, width: 80, height: 22))
        contentView.addSubview(heightField)
        
        yOffset -= 40
        
        // --- Drawing Settings ---
        let drawingSection = createSectionLabel("Drawing Settings")
        drawingSection.frame.origin = CGPoint(x: padding, y: yOffset)
        contentView.addSubview(drawingSection)
        
        yOffset -= 28
        
        let borderLabel = NSTextField(labelWithString: "Border (px):")
        borderLabel.frame = NSRect(x: padding, y: yOffset, width: 80, height: 22)
        contentView.addSubview(borderLabel)
        
        borderField = NSTextField(frame: NSRect(x: 105, y: yOffset, width: 60, height: 22))
        contentView.addSubview(borderField)
        
        let brushLabel = NSTextField(labelWithString: "Stroke Size:")
        brushLabel.frame = NSRect(x: 180, y: yOffset, width: 80, height: 22)
        contentView.addSubview(brushLabel)
        
        brushSizeField = NSTextField(frame: NSRect(x: 265, y: yOffset, width: 60, height: 22))
        contentView.addSubview(brushSizeField)
        
        yOffset -= 40
        
        // --- Keyboard Shortcuts ---
        let keySection = createSectionLabel("Keyboard Shortcuts")
        keySection.frame.origin = CGPoint(x: padding, y: yOffset)
        contentView.addSubview(keySection)
        
        yOffset -= 28
        
        let screenshotKeyLabel = NSTextField(labelWithString: "Screenshot Key:")
        screenshotKeyLabel.frame = NSRect(x: padding, y: yOffset, width: 110, height: 22)
        contentView.addSubview(screenshotKeyLabel)
        
        screenshotKeyButton = KeyCaptureButton(frame: NSRect(x: 140, y: yOffset, width: 150, height: 26))
        contentView.addSubview(screenshotKeyButton)
        
        yOffset -= 28
        
        let copyKeyLabel = NSTextField(labelWithString: "Copy Key:")
        copyKeyLabel.frame = NSRect(x: padding, y: yOffset, width: 110, height: 22)
        contentView.addSubview(copyKeyLabel)
        
        copyKeyButton = KeyCaptureButton(frame: NSRect(x: 140, y: yOffset, width: 150, height: 26))
        contentView.addSubview(copyKeyButton)
        
        // --- Buttons ---
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveConfig))
        saveButton.frame = NSRect(x: 420, y: 20, width: 80, height: 32)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)
        
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelConfig))
        cancelButton.frame = NSRect(x: 330, y: 20, width: 80, height: 32)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)
    }
    
    private func createSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.sizeToFit()
        return label
    }
    
    private func populateDisplayPopup(_ popup: NSPopUpButton) {
        popup.removeAllItems()
        
        let displays = screenshotManager.getDisplayInfo()
        for display in displays {
            popup.addItem(withTitle: display.description)
            popup.lastItem?.tag = display.index
        }
    }
    
    private func loadCurrentConfig() {
        let config = ConfigManager.shared.config
        
        sourceDisplayPopup.selectItem(withTag: config.sourceDisplayIndex)
        customAreaCheckbox.state = config.useCustomCaptureArea ? .on : .off
        captureXField.stringValue = "\(config.captureX)"
        captureYField.stringValue = "\(config.captureY)"
        captureWidthField.stringValue = "\(config.captureWidth)"
        captureHeightField.stringValue = "\(config.captureHeight)"
        
        targetDisplayPopup.selectItem(withTag: config.targetDisplayIndex)
        centerCheckbox.state = config.centerWindow ? .on : .off
        positionXField.stringValue = "\(Int(config.windowPosition.x))"
        positionYField.stringValue = "\(Int(config.windowPosition.y))"
        widthField.stringValue = "\(Int(config.windowSize.width))"
        heightField.stringValue = "\(Int(config.windowSize.height))"
        screenshotKeyButton.keyCode = config.screenshotKeyCode
        screenshotKeyButton.modifiers = config.screenshotModifiers
        copyKeyButton.keyCode = config.copyKeyCode
        copyKeyButton.modifiers = config.copyModifiers
        borderField.stringValue = "\(Int(config.borderSize))"
        brushSizeField.stringValue = "\(Int(config.defaultBrushSize))"
        
        updatePositionFieldsVisibility()
        updateCaptureAreaFieldsVisibility()
    }
    
    @objc private func centerCheckboxChanged() {
        updatePositionFieldsVisibility()
    }
    
    @objc private func customAreaCheckboxChanged() {
        updateCaptureAreaFieldsVisibility()
    }
    
    private func updatePositionFieldsVisibility() {
        let isCentered = centerCheckbox.state == .on
        positionXLabel.isHidden = isCentered
        positionXField.isHidden = isCentered
        positionYLabel.isHidden = isCentered
        positionYField.isHidden = isCentered
    }
    
    private func updateCaptureAreaFieldsVisibility() {
        let useCustomArea = customAreaCheckbox.state == .on
        captureXLabel.isHidden = !useCustomArea
        captureXField.isHidden = !useCustomArea
        captureYLabel.isHidden = !useCustomArea
        captureYField.isHidden = !useCustomArea
        captureWidthLabel.isHidden = !useCustomArea
        captureWidthField.isHidden = !useCustomArea
        captureHeightLabel.isHidden = !useCustomArea
        captureHeightField.isHidden = !useCustomArea
    }
    
    @objc private func saveConfig() {
        ConfigManager.shared.update { config in
            config.sourceDisplayIndex = sourceDisplayPopup.selectedTag()
            config.useCustomCaptureArea = customAreaCheckbox.state == .on
            config.captureX = captureXField.integerValue
            config.captureY = captureYField.integerValue
            config.captureWidth = captureWidthField.integerValue
            config.captureHeight = captureHeightField.integerValue
            
            config.targetDisplayIndex = targetDisplayPopup.selectedTag()
            config.centerWindow = centerCheckbox.state == .on
            config.windowPosition = CGPoint(
                x: CGFloat(positionXField.intValue),
                y: CGFloat(positionYField.intValue)
            )
            config.windowSize = CGSize(
                width: CGFloat(widthField.intValue),
                height: CGFloat(heightField.intValue)
            )
            config.screenshotKeyCode = screenshotKeyButton.keyCode
            config.screenshotModifiers = screenshotKeyButton.modifiers
            config.copyKeyCode = copyKeyButton.keyCode
            config.copyModifiers = copyKeyButton.modifiers
            config.borderSize = CGFloat(borderField.intValue)
            config.defaultBrushSize = CGFloat(brushSizeField.intValue)
        }
        
        // Re-register hotkeys with new key codes
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.registerHotKeys()
        }
        
        close()
    }
    
    @objc private func cancelConfig() {
        close()
    }
}

// MARK: - Key Capture Button

/// A button that captures the next key press with modifiers
class KeyCaptureButton: NSButton {
    var keyCode: UInt16 = 0 {
        didSet {
            updateTitle()
        }
    }
    
    var modifiers: UInt32 = 0 {
        didSet {
            updateTitle()
        }
    }
    
    private var isCapturing = false
    private var eventMonitor: Any?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        bezelStyle = .rounded
        title = "Click to set"
        target = self
        action = #selector(startCapture)
    }
    
    private func updateTitle() {
        title = KeyCodeHelper.shortcutName(keyCode: keyCode, modifiers: modifiers)
    }
    
    @objc private func startCapture() {
        guard !isCapturing else { return }
        
        isCapturing = true
        title = "Press keys..."
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        keyCode = event.keyCode
        modifiers = KeyCodeHelper.carbonModifiers(from: event.modifierFlags)
        stopCapture()
    }
    
    private func stopCapture() {
        isCapturing = false
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    deinit {
        stopCapture()
    }
}
