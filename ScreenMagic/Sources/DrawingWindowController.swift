import AppKit

class DrawingWindowController: NSWindowController {
    private let screenshot: NSImage
    private var drawingView: DrawingView!
    
    init(screenshot: NSImage, position: CGPoint, size: CGSize) {
        self.screenshot = screenshot
        
        // Calculate window frame
        let windowRect = NSRect(origin: position, size: size)
        
        // Create window
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
        window.backgroundColor = NSColor.windowBackgroundColor
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
        
        // Create main container view
        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]
        
        // Create toolbar
        let toolbar = createToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(toolbar)
        
        // Create drawing view
        drawingView = DrawingView(frame: .zero)
        drawingView.translatesAutoresizingMaskIntoConstraints = false
        drawingView.setBackgroundImage(screenshot)
        
        // Set default brush size from config
        let config = ConfigManager.shared.config
        drawingView.brushSize = config.defaultBrushSize
        
        containerView.addSubview(drawingView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            toolbar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            toolbar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            toolbar.heightAnchor.constraint(equalToConstant: 40),
            
            drawingView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 10),
            drawingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            drawingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            drawingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10)
        ])
        
        window.contentView = containerView
    }
    
    private func createToolbar() -> NSView {
        let toolbar = NSView(frame: .zero)
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        toolbar.layer?.cornerRadius = 8
        
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(stackView)
        
        // Color buttons
        let colors: [(NSColor, String)] = [
            (.systemRed, "Red"),
            (.systemBlue, "Blue"),
            (.systemGreen, "Green"),
            (.systemYellow, "Yellow"),
            (.black, "Black"),
            (.white, "White")
        ]
        
        for (color, name) in colors {
            let button = createColorButton(color: color, name: name)
            stackView.addArrangedSubview(button)
        }
        
        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        stackView.addArrangedSubview(separator)
        
        // Brush size slider
        let sizeLabel = NSTextField(labelWithString: "Size:")
        stackView.addArrangedSubview(sizeLabel)
        
        let config = ConfigManager.shared.config
        let sizeSlider = NSSlider(value: Double(config.defaultBrushSize), minValue: 1.0, maxValue: 20.0, target: self, action: #selector(brushSizeChanged(_:)))
        sizeSlider.widthAnchor.constraint(equalToConstant: 80).isActive = true
        stackView.addArrangedSubview(sizeSlider)
        
        // Separator
        let separator2 = NSBox()
        separator2.boxType = .separator
        separator2.widthAnchor.constraint(equalToConstant: 1).isActive = true
        stackView.addArrangedSubview(separator2)
        
        // Undo button
        let undoButton = NSButton(title: "Undo", target: self, action: #selector(undoAction))
        undoButton.bezelStyle = .rounded
        undoButton.keyEquivalent = "z"
        undoButton.keyEquivalentModifierMask = .command
        stackView.addArrangedSubview(undoButton)
        
        // Clear button
        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearAction))
        clearButton.bezelStyle = .rounded
        stackView.addArrangedSubview(clearButton)
        
        // Separator
        let separator3 = NSBox()
        separator3.boxType = .separator
        separator3.widthAnchor.constraint(equalToConstant: 1).isActive = true
        stackView.addArrangedSubview(separator3)
        
        // Copy button
        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyAction))
        copyButton.bezelStyle = .rounded
        copyButton.keyEquivalent = "c"
        copyButton.keyEquivalentModifierMask = .command
        stackView.addArrangedSubview(copyButton)
        
        // Save button
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveAction))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = .command
        stackView.addArrangedSubview(saveButton)
        
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: toolbar.trailingAnchor, constant: -10)
        ])
        
        return toolbar
    }
    
    private func createColorButton(color: NSColor, name: String) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        button.title = ""  // Remove text
        button.bezelStyle = .smallSquare
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = color.cgColor
        button.layer?.cornerRadius = 12
        button.layer?.borderWidth = 2
        button.layer?.borderColor = NSColor.separatorColor.cgColor
        button.toolTip = name
        button.target = self
        button.action = #selector(colorSelected(_:))
        button.tag = colorToTag(color)
        
        // Use empty image to prevent default title
        button.image = nil
        button.imagePosition = .noImage
        
        button.widthAnchor.constraint(equalToConstant: 24).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        return button
    }
    
    private func colorToTag(_ color: NSColor) -> Int {
        switch color {
        case .systemRed: return 1
        case .systemBlue: return 2
        case .systemGreen: return 3
        case .systemYellow: return 4
        case .black: return 5
        case .white: return 6
        default: return 0
        }
    }
    
    private func tagToColor(_ tag: Int) -> NSColor {
        switch tag {
        case 1: return .systemRed
        case 2: return .systemBlue
        case 3: return .systemGreen
        case 4: return .systemYellow
        case 5: return .black
        case 6: return .white
        default: return .black
        }
    }
    
    // MARK: - Actions
    
    @objc private func colorSelected(_ sender: NSButton) {
        let color = tagToColor(sender.tag)
        drawingView.currentColor = color
    }
    
    @objc private func brushSizeChanged(_ sender: NSSlider) {
        drawingView.brushSize = CGFloat(sender.doubleValue)
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
        guard let image = drawingView.compositeImage() else {
            print("Failed to create composite image")
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Write both image and text "." to clipboard
        pasteboard.writeObjects([image])
        pasteboard.setString(".", forType: .string)
        
        // Close the window after copying
        close()
    }
    
    private func showCopyFeedback() {
        guard let window = window else { return }
        
        let feedbackView = NSView(frame: window.contentView!.bounds)
        feedbackView.wantsLayer = true
        feedbackView.layer?.backgroundColor = NSColor.green.withAlphaComponent(0.3).cgColor
        feedbackView.alphaValue = 1.0
        
        window.contentView?.addSubview(feedbackView)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            feedbackView.animator().alphaValue = 0.0
        } completionHandler: {
            feedbackView.removeFromSuperview()
        }
    }
    
    private func saveToFile() {
        guard let image = drawingView.compositeImage() else {
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
