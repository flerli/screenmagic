import AppKit

/// Custom color button with hover effect
class ColorButton: NSButton {
    var normalBorderWidth: CGFloat = 2
    var selectedBorderWidth: CGFloat = 4
    var isSelectedColor: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    private var dashedBorderLayer: CAShapeLayer?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }
    
    private func updateAppearance() {
        dashedBorderLayer?.removeFromSuperlayer()
        dashedBorderLayer = nil
        
        if isSelectedColor {
            layer?.borderWidth = selectedBorderWidth
        } else if isHovering {
            layer?.borderWidth = 0
            let dashLayer = CAShapeLayer()
            let path = CGPath(ellipseIn: bounds.insetBy(dx: 2, dy: 2), transform: nil)
            dashLayer.path = path
            dashLayer.fillColor = nil
            dashLayer.strokeColor = NSColor.white.cgColor
            dashLayer.lineWidth = 2
            dashLayer.lineDashPattern = [4, 4]
            layer?.addSublayer(dashLayer)
            dashedBorderLayer = dashLayer
        } else {
            layer?.borderWidth = normalBorderWidth
        }
    }
}

class DrawingWindowController: NSWindowController {
    private let screenshot: NSImage
    private var drawingView: DrawingView!
    private var colorButtons: [ColorButton] = []
    private var selectedColorTag: Int = 1
    private var cropButton: NSButton!
    
    init(screenshot: NSImage, position: CGPoint, size: CGSize) {
        self.screenshot = screenshot
        
        let windowRect = NSRect(origin: position, size: size)
        
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "ScreenMagic - Drawing"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        super.init(window: window)
        
        setupContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupContent() {
        guard let window = window else { return }
        
        // Main container
        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        
        // Create drawing view FIRST (bottom layer)
        drawingView = DrawingView(frame: .zero)
        drawingView.translatesAutoresizingMaskIntoConstraints = false
        drawingView.setBackgroundImage(screenshot)
        drawingView.onCropComplete = { [weak self] in
            self?.cropButton.state = .off
            self?.updateCropButtonAppearance()
        }
        drawingView.onColorSwitch = { [weak self] number in
            self?.selectColorByNumber(number)
        }
        drawingView.onCropToggle = { [weak self] in
            self?.toggleCropMode()
        }
        
        let config = ConfigManager.shared.config
        drawingView.brushSize = config.defaultBrushSize
        drawingView.pressureFlow = config.pressureFlow
        drawingView.numberBadgeSize = config.numberBadgeSize
        
        containerView.addSubview(drawingView)
        
        // Top blurred area (on top of drawing view) - less blurry
        let topBlurView = NSVisualEffectView(frame: .zero)
        topBlurView.translatesAutoresizingMaskIntoConstraints = false
        topBlurView.blendingMode = .withinWindow
        topBlurView.material = .headerView  // Less blurry than sidebar
        topBlurView.state = .active
        topBlurView.wantsLayer = true
        containerView.addSubview(topBlurView)
        
        // Create toolbar (on top of blur)
        let toolbar = createToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.wantsLayer = true
        toolbar.layer?.zPosition = 100
        containerView.addSubview(toolbar)
        
        NSLayoutConstraint.activate([
            // Drawing view - full size
            drawingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            drawingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            drawingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            drawingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Top blur area - covers top 100px
            topBlurView.topAnchor.constraint(equalTo: containerView.topAnchor),
            topBlurView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            topBlurView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            topBlurView.heightAnchor.constraint(equalToConstant: 100),
            
            // Toolbar - full width
            toolbar.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 35),
            toolbar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 80),
            toolbar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        window.contentView = containerView
        
        updateColorSelection()
    }
    
    private func createToolbar() -> NSView {
        let toolbar = NSVisualEffectView(frame: .zero)
        toolbar.blendingMode = .withinWindow
        toolbar.material = .headerView  // Less blur
        toolbar.state = .active
        toolbar.wantsLayer = true
        // No corner radius - full width toolbar
        
        // Left side: zoom controls
        let leftStack = NSStackView()
        leftStack.orientation = .horizontal
        leftStack.spacing = 8
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(leftStack)
        
        let zoomLabel = NSTextField(labelWithString: "Zoom:")
        leftStack.addArrangedSubview(zoomLabel)
        
        let zoomInButton = NSButton(title: "+", target: self, action: #selector(zoomIn))
        zoomInButton.bezelStyle = .rounded
        zoomInButton.toolTip = "Zoom In"
        leftStack.addArrangedSubview(zoomInButton)
        
        let zoomOutButton = NSButton(title: "-", target: self, action: #selector(zoomOut))
        zoomOutButton.bezelStyle = .rounded
        zoomOutButton.toolTip = "Zoom Out"
        leftStack.addArrangedSubview(zoomOutButton)
        
        let resetZoomButton = NSButton(title: "Fit", target: self, action: #selector(resetZoom))
        resetZoomButton.bezelStyle = .rounded
        resetZoomButton.toolTip = "Reset Zoom"
        leftStack.addArrangedSubview(resetZoomButton)
        
        let sep1 = NSBox()
        sep1.boxType = .separator
        sep1.widthAnchor.constraint(equalToConstant: 1).isActive = true
        leftStack.addArrangedSubview(sep1)
        
        cropButton = NSButton(title: "✂ Crop", target: self, action: #selector(toggleCropMode))
        cropButton.bezelStyle = .rounded
        cropButton.toolTip = "Crop Tool - Draw rectangle to crop"
        cropButton.setButtonType(.toggle)
        leftStack.addArrangedSubview(cropButton)
        
        // Center: Color buttons
        let centerStack = NSStackView()
        centerStack.orientation = .horizontal
        centerStack.spacing = 8
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(centerStack)
        
        let colors: [(NSColor, String, Int)] = [
            (.systemRed, "Red", 1),
            (.systemBlue, "Blue", 2),
            (.systemGreen, "Green", 3),
            (.systemYellow, "Yellow", 4),
            (.systemPurple, "Purple", 5),
            (.cyan, "Cyan", 6)
        ]
        
        for (color, name, number) in colors {
            let button = createColorButton(color: color, name: name, number: number)
            colorButtons.append(button)
            centerStack.addArrangedSubview(button)
        }
        
        // Right side: actions + stroke size
        let rightStack = NSStackView()
        rightStack.orientation = .horizontal
        rightStack.spacing = 8
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(rightStack)
        
        let undoButton = NSButton(title: "Undo", target: self, action: #selector(undoAction))
        undoButton.bezelStyle = .rounded
        undoButton.keyEquivalent = "z"
        undoButton.keyEquivalentModifierMask = .command
        rightStack.addArrangedSubview(undoButton)
        
        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearAction))
        clearButton.bezelStyle = .rounded
        rightStack.addArrangedSubview(clearButton)
        
        let separator1 = NSBox()
        separator1.boxType = .separator
        separator1.widthAnchor.constraint(equalToConstant: 1).isActive = true
        rightStack.addArrangedSubview(separator1)
        
        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyAction))
        copyButton.bezelStyle = .rounded
        copyButton.keyEquivalent = "c"
        copyButton.keyEquivalentModifierMask = .command
        rightStack.addArrangedSubview(copyButton)
        
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveAction))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = .command
        rightStack.addArrangedSubview(saveButton)
        
        let separator2 = NSBox()
        separator2.boxType = .separator
        separator2.widthAnchor.constraint(equalToConstant: 1).isActive = true
        rightStack.addArrangedSubview(separator2)
        
        let config = ConfigManager.shared.config
        let sizeLabel = NSTextField(labelWithString: "Stroke:")
        rightStack.addArrangedSubview(sizeLabel)
        
        let sizeSlider = NSSlider(value: Double(config.defaultBrushSize), minValue: 1.0, maxValue: 20.0, target: self, action: #selector(brushSizeChanged(_:)))
        sizeSlider.widthAnchor.constraint(equalToConstant: 80).isActive = true
        rightStack.addArrangedSubview(sizeSlider)
        
        NSLayoutConstraint.activate([
            leftStack.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            leftStack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 10),
            
            centerStack.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            centerStack.centerXAnchor.constraint(equalTo: toolbar.centerXAnchor),
            
            rightStack.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            rightStack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -10)
        ])
        
        return toolbar
    }
    
    private func createColorButton(color: NSColor, name: String, number: Int) -> ColorButton {
        let size: CGFloat = 54
        let button = ColorButton(frame: NSRect(x: 0, y: 0, width: size, height: size))
        button.title = ""
        button.bezelStyle = .smallSquare
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = color.cgColor
        button.layer?.cornerRadius = size / 2
        button.layer?.borderWidth = 2
        button.layer?.borderColor = NSColor.separatorColor.cgColor
        button.toolTip = "\(name) (\(number))"
        button.target = self
        button.action = #selector(colorSelected(_:))
        button.tag = number
        button.image = nil
        
        // Add number label
        let label = NSTextField(labelWithString: "\(number)")
        label.font = NSFont.boldSystemFont(ofSize: 18)
        label.textColor = (color == .systemYellow || color == .cyan) ? .black : .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        button.imagePosition = .noImage
        
        button.widthAnchor.constraint(equalToConstant: size).isActive = true
        button.heightAnchor.constraint(equalToConstant: size).isActive = true
        
        return button
    }
    
    private func updateColorSelection() {
        for button in colorButtons {
            let color = tagToColor(button.tag)
            if button.tag == selectedColorTag {
                button.isSelectedColor = true
                button.layer?.borderColor = darkerColor(color).cgColor
            } else {
                button.isSelectedColor = false
                button.layer?.borderColor = NSColor.separatorColor.cgColor
            }
        }
    }
    
    private func updateCropButtonAppearance() {
        if cropButton.state == .on {
            cropButton.contentTintColor = .systemBlue
        } else {
            cropButton.contentTintColor = nil
        }
    }
    
    private func darkerColor(_ color: NSColor) -> NSColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        let rgbColor = color.usingColorSpace(.deviceRGB) ?? color
        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return NSColor(hue: hue, saturation: min(saturation * 1.2, 1.0), brightness: brightness * 0.6, alpha: alpha)
    }
    
    private func colorToTag(_ color: NSColor) -> Int {
        switch color {
        case .systemRed: return 1
        case .systemBlue: return 2
        case .systemGreen: return 3
        case .systemYellow: return 4
        case .systemPurple: return 5
        case .cyan: return 6
        default: return 0
        }
    }
    
    func tagToColor(_ tag: Int) -> NSColor {
        switch tag {
        case 1: return .systemRed
        case 2: return .systemBlue
        case 3: return .systemGreen
        case 4: return .systemYellow
        case 5: return .systemPurple
        case 6: return .cyan
        default: return .systemRed
        }
    }
    
    func selectColorByNumber(_ number: Int) {
        guard number >= 1 && number <= 6 else { return }
        
        cropButton.state = .off
        updateCropButtonAppearance()
        drawingView.isCropMode = false
        
        selectedColorTag = number
        let color = tagToColor(number)
        drawingView.currentColor = color
        drawingView.currentColorNumber = number
        updateColorSelection()
    }
    
    // MARK: - Actions
    
    @objc private func colorSelected(_ sender: NSButton) {
        cropButton.state = .off
        updateCropButtonAppearance()
        drawingView.isCropMode = false
        
        selectedColorTag = sender.tag
        let color = tagToColor(sender.tag)
        drawingView.currentColor = color
        drawingView.currentColorNumber = sender.tag
        updateColorSelection()
    }
    
    @objc private func brushSizeChanged(_ sender: NSSlider) {
        drawingView.brushSize = CGFloat(sender.doubleValue)
    }
    
    @objc private func zoomIn() {
        drawingView.zoomIn()
    }
    
    @objc private func zoomOut() {
        drawingView.zoomOut()
    }
    
    @objc private func resetZoom() {
        drawingView.resetZoom()
    }
    
    @objc func toggleCropMode() {
        // When called from keyboard (c key), toggle the button state
        // When called from button click, button already toggled itself
        // Check if this is from keyboard by seeing if button state matches drawing view state
        if cropButton.state == .on && drawingView.isCropMode {
            // Called from keyboard while already on - turn off
            cropButton.state = .off
        } else if cropButton.state == .off && !drawingView.isCropMode {
            // Called from keyboard while already off - turn on
            cropButton.state = .on
        }
        // Now sync drawing view with button state
        drawingView.isCropMode = cropButton.state == .on
        updateCropButtonAppearance()
    }
    
    @objc private func undoAction() {
        drawingView.undo()
    }
    
    @objc private func clearAction() {
        drawingView.clearDrawings()
    }
    
    @objc private func copyAction() {
        copyToClipboard()
    }
    
    @objc private func saveAction() {
        saveToFile()
    }
    
    // MARK: - Public Methods
    
    func copyToClipboard() {
        guard let image = drawingView.compositeVisibleImage() else {
            print("Failed to create composite image")
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        
        close()
    }
    
    private func saveToFile() {
        guard let image = drawingView.compositeVisibleImage() else {
            print("Failed to create composite image")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "screenshot_\(dateString()).png"
        
        savePanel.beginSheetModal(for: window!) { response in
            if response == .OK, let url = savePanel.url {
                self.saveImage(image, to: url)
            }
        }
    }
    
    private func saveImage(_ image: NSImage, to url: URL) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("Failed to convert image to PNG")
            return
        }
        
        do {
            try pngData.write(to: url)
            print("Saved image to \(url.path)")
        } catch {
            print("Failed to save image: \(error)")
        }
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
}
