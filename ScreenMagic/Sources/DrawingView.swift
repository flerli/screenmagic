import AppKit

/// A single segment of a stroke with its own width
struct StrokeSegment {
    let from: NSPoint
    let to: NSPoint
    let lineWidth: CGFloat
}

/// Represents a complete stroke made up of multiple segments
class DrawingStroke {
    var segments: [StrokeSegment] = []
    var strokeColor: NSColor
    var baseLineWidth: CGFloat
    var pressureFlow: CGFloat
    
    init(strokeColor: NSColor, baseLineWidth: CGFloat, pressureFlow: CGFloat = 1.0) {
        self.strokeColor = strokeColor
        self.baseLineWidth = baseLineWidth
        self.pressureFlow = pressureFlow
    }
    
    func addSegment(from: NSPoint, to: NSPoint, pressure: Float, lineWidthInImagePixels: CGFloat) {
        let effectivePressure = 1.0 - pressureFlow + (pressureFlow * CGFloat(max(0.1, pressure)))
        let width = lineWidthInImagePixels * effectivePressure
        segments.append(StrokeSegment(from: from, to: to, lineWidth: width))
    }
    
    func draw(viewScale: CGFloat, viewOffset: NSPoint) {
        guard !segments.isEmpty else { return }
        
        strokeColor.setStroke()
        strokeColor.setFill()
        
        for segment in segments {
            let path = NSBezierPath()
            path.lineWidth = segment.lineWidth * viewScale
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            
            let fromPoint = NSPoint(
                x: segment.from.x * viewScale + viewOffset.x,
                y: segment.from.y * viewScale + viewOffset.y
            )
            let toPoint = NSPoint(
                x: segment.to.x * viewScale + viewOffset.x,
                y: segment.to.y * viewScale + viewOffset.y
            )
            
            path.move(to: fromPoint)
            path.line(to: toPoint)
            path.stroke()
        }
    }
    
    func drawForExport(scale: CGFloat, offset: NSPoint) {
        strokeColor.setStroke()
        strokeColor.setFill()
        
        for segment in segments {
            let path = NSBezierPath()
            path.lineWidth = segment.lineWidth * scale
            path.lineCapStyle = .round
            path.move(to: NSPoint(
                x: segment.from.x * scale + offset.x,
                y: segment.from.y * scale + offset.y
            ))
            path.line(to: NSPoint(
                x: segment.to.x * scale + offset.x,
                y: segment.to.y * scale + offset.y
            ))
            path.stroke()
        }
    }
}

/// Represents a number badge annotation
struct NumberBadge {
    let number: Int
    let position: NSPoint  // In image coordinates
    let color: NSColor
    let size: CGFloat  // In image pixels
    
    func draw(viewScale: CGFloat, viewOffset: NSPoint) {
        let screenPos = NSPoint(
            x: position.x * viewScale + viewOffset.x,
            y: position.y * viewScale + viewOffset.y
        )
        let screenSize = size * viewScale
        
        // Draw filled circle
        let circleRect = NSRect(
            x: screenPos.x - screenSize/2,
            y: screenPos.y - screenSize/2,
            width: screenSize,
            height: screenSize
        )
        
        color.setFill()
        NSBezierPath(ovalIn: circleRect).fill()
        
        // Draw black border
        NSColor.black.setStroke()
        let borderPath = NSBezierPath(ovalIn: circleRect)
        borderPath.lineWidth = max(1, screenSize * 0.05)
        borderPath.stroke()
        
        // Draw number
        let fontSize = screenSize * 0.6
        let font = NSFont.boldSystemFont(ofSize: fontSize)
        let text = "\(number)"
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: screenPos.x - textSize.width/2,
            y: screenPos.y - textSize.height/2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
    }
    
    func drawForExport(scale: CGFloat, offset: NSPoint) {
        let exportPos = NSPoint(
            x: position.x * scale + offset.x,
            y: position.y * scale + offset.y
        )
        let exportSize = size * scale
        
        let circleRect = NSRect(
            x: exportPos.x - exportSize/2,
            y: exportPos.y - exportSize/2,
            width: exportSize,
            height: exportSize
        )
        
        color.setFill()
        NSBezierPath(ovalIn: circleRect).fill()
        
        NSColor.black.setStroke()
        let borderPath = NSBezierPath(ovalIn: circleRect)
        borderPath.lineWidth = max(1, exportSize * 0.05)
        borderPath.stroke()
        
        let fontSize = exportSize * 0.6
        let font = NSFont.boldSystemFont(ofSize: fontSize)
        let text = "\(number)"
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: exportPos.x - textSize.width/2,
            y: exportPos.y - textSize.height/2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
    }
}

/// Undo action types
enum UndoAction {
    case stroke(DrawingStroke)
    case badge(NumberBadge)
    case crop(previousImage: NSImage, previousStrokes: [DrawingStroke], previousBadges: [NumberBadge])
}

/// A custom view that supports drawing on top of a background image with zoom/pan
class DrawingView: NSView {
    
    // MARK: - Properties
    
    private var backgroundImage: NSImage?
    var currentColor: NSColor = .systemRed {
        didSet {
            updateCursor()
        }
    }
    var currentColorNumber: Int = 1  // Track which color number is selected (1-6)
    var brushSize: CGFloat = 3.0 {
        didSet {
            updateCursor()
        }
    }
    var pressureFlow: CGFloat = 1.0
    var numberBadgeSize: CGFloat = 32.0
    
    private var strokes: [DrawingStroke] = []
    private var badges: [NumberBadge] = []
    private var undoStack: [UndoAction] = []
    private var currentStroke: DrawingStroke?
    private var lastImagePoint: NSPoint?
    private var isDrawing = false
    
    // Crop mode
    var isCropMode = false {
        didSet {
            updateCursor()
            if !isCropMode {
                cropRect = nil
                needsDisplay = true
            }
        }
    }
    private var cropRect: NSRect?
    private var cropStartPoint: NSPoint?
    private var isCropping = false
    
    var onCropComplete: (() -> Void)?
    
    // Zoom and pan
    private var zoomScale: CGFloat = 1.0
    private var panOffset: NSPoint = .zero
    private var isPanning = false
    private var lastPanPoint: NSPoint = .zero
    
    private var lastMouseLocation: NSPoint = .zero
    
    // Cursors
    private var circleCursor: NSCursor?
    private var crosshairCursor: NSCursor?
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.darkGray.cgColor
        
        crosshairCursor = NSCursor.crosshair
        updateCursor()
        
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    private func updateCursor() {
        if isCropMode {
            circleCursor = crosshairCursor
        } else {
            let cursorSize = max(brushSize * 2 + 4, 16)
            let image = NSImage(size: NSSize(width: cursorSize, height: cursorSize))
            
            image.lockFocus()
            
            let circleRect = NSRect(x: 2, y: 2, width: cursorSize - 4, height: cursorSize - 4)
            
            // White circle outline
            let path = NSBezierPath(ovalIn: circleRect)
            path.lineWidth = 2
            NSColor.white.setStroke()
            path.stroke()
            
            // Black inner outline for visibility
            let innerRect = circleRect.insetBy(dx: 1, dy: 1)
            let innerPath = NSBezierPath(ovalIn: innerRect)
            innerPath.lineWidth = 1
            NSColor.black.withAlphaComponent(0.7).setStroke()
            innerPath.stroke()
            
            // Center dot in current color (50% larger: 3 -> 4.5)
            let dotSize: CGFloat = 4.5
            let dotRect = NSRect(x: cursorSize/2 - dotSize/2, y: cursorSize/2 - dotSize/2, width: dotSize, height: dotSize)
            currentColor.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            
            image.unlockFocus()
            
            circleCursor = NSCursor(image: image, hotSpot: NSPoint(x: cursorSize/2, y: cursorSize/2))
        }
    }
    
    private func isInDrawingArea(_ point: NSPoint) -> Bool {
        let imageRect = calculateImageRect()
        // Also check we're not in the top control bar area (top 100px of window)
        let controlBarHeight: CGFloat = 100
        let isInControlBar = point.y > bounds.height - controlBarHeight
        return imageRect.contains(point) && !isInControlBar
    }
    
    override func cursorUpdate(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if isInDrawingArea(point) {
            circleCursor?.set()
        } else {
            NSCursor.arrow.set()
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if isInDrawingArea(point) {
            circleCursor?.set()
        } else {
            NSCursor.arrow.set()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }
    
    override func mouseMoved(with event: NSEvent) {
        lastMouseLocation = convert(event.locationInWindow, from: nil)
        if isInDrawingArea(lastMouseLocation) {
            circleCursor?.set()
        } else {
            NSCursor.arrow.set()
        }
    }
    
    // MARK: - Key Events for Color Switching and Number Badges
    
    override var acceptsFirstResponder: Bool { true }
    
    // Callbacks
    var onColorSwitch: ((Int) -> Void)?
    var onCropToggle: (() -> Void)?
    
    // For double-press badge mode
    private var lastNumberKeyTime: Date?
    private var lastNumberKey: Int?
    private let doublePressThreshold: TimeInterval = 0.4
    
    override func keyDown(with event: NSEvent) {
        // Ignore if it's a repeat (key held down)
        if event.isARepeat { return }
        
        guard let characters = event.charactersIgnoringModifiers else {
            super.keyDown(with: event)
            return
        }
        
        // Check for 'c' key for crop
        if characters.lowercased() == "c",
           !event.modifierFlags.contains(.command) {
            onCropToggle?()
            return
        }
        
        // Check for number keys 1-9
        if let char = characters.first,
           let number = Int(String(char)),
           number >= 1 && number <= 9 {
            let now = Date()
            
            // Check for double-press
            if let lastTime = lastNumberKeyTime,
               let lastNum = lastNumberKey,
               lastNum == number,
               now.timeIntervalSince(lastTime) < doublePressThreshold {
                // Double press - add badge
                addNumberBadge(number: number)
                lastNumberKeyTime = nil
                lastNumberKey = nil
                return
            }
            
            // Single press - switch color if 1-6
            lastNumberKeyTime = now
            lastNumberKey = number
            
            if number >= 1 && number <= 6 {
                onColorSwitch?(number)
            }
            return
        }
        
        super.keyDown(with: event)
    }
    
    private func addNumberBadge(number: Int) {
        let imagePoint = viewToImageCoordinates(lastMouseLocation)
        let imageBadgeSize = screenBrushSizeToImageBrushSize(numberBadgeSize)
        
        let badge = NumberBadge(
            number: number,
            position: imagePoint,
            color: currentColor,
            size: imageBadgeSize
        )
        
        badges.append(badge)
        undoStack.append(.badge(badge))
        needsDisplay = true
    }
    
    // MARK: - Public Methods
    
    func setBackgroundImage(_ image: NSImage) {
        backgroundImage = image
        resetZoom()
        needsDisplay = true
    }
    
    func zoomIn() {
        zoomAtPoint(lastMouseLocation, factor: 1.25)
    }
    
    func zoomOut() {
        zoomAtPoint(lastMouseLocation, factor: 1.0 / 1.25)
    }
    
    func zoomAtPoint(_ point: NSPoint, factor: CGFloat) {
        let oldScale = zoomScale
        let newScale = min(max(zoomScale * factor, 1.0), 10.0)
        
        if newScale == oldScale { return }
        
        if newScale <= 1.0 {
            zoomScale = 1.0
            panOffset = .zero
            needsDisplay = true
            return
        }
        
        let imageRect = calculateImageRect()
        
        // Check if point is inside the image rect, if not use center of image
        let zoomPoint: NSPoint
        if imageRect.contains(point) {
            zoomPoint = point
        } else {
            zoomPoint = NSPoint(x: imageRect.midX, y: imageRect.midY)
        }
        
        let pointInImage = NSPoint(
            x: (zoomPoint.x - imageRect.origin.x) / oldScale,
            y: (zoomPoint.y - imageRect.origin.y) / oldScale
        )
        
        zoomScale = newScale
        
        let newImageRect = calculateImageRectWithScale(newScale)
        let newPointX = pointInImage.x * newScale + newImageRect.origin.x
        let newPointY = pointInImage.y * newScale + newImageRect.origin.y
        
        panOffset.x += zoomPoint.x - newPointX
        panOffset.y += zoomPoint.y - newPointY
        
        needsDisplay = true
    }
    
    func resetZoom() {
        zoomScale = 1.0
        panOffset = .zero
        needsDisplay = true
    }
    
    func undo() {
        guard let lastAction = undoStack.popLast() else { return }
        
        switch lastAction {
        case .stroke(_):
            if !strokes.isEmpty {
                strokes.removeLast()
            }
        case .badge(_):
            if !badges.isEmpty {
                badges.removeLast()
            }
        case .crop(let previousImage, let previousStrokes, let previousBadges):
            backgroundImage = previousImage
            strokes = previousStrokes
            badges = previousBadges
            resetZoom()
        }
        
        needsDisplay = true
    }
    
    func clearDrawings() {
        strokes.removeAll()
        badges.removeAll()
        undoStack.removeAll()
        needsDisplay = true
    }
    
    func compositeVisibleImage() -> NSImage? {
        guard let background = backgroundImage else { return nil }
        
        if zoomScale <= 1.0 {
            return compositeFullImage()
        }
        
        let imageRect = calculateImageRect()
        let baseRect = calculateBaseImageRect()
        let visibleRect = bounds
        
        let scale = imageRect.width / baseRect.width
        let imageToOriginalScale = background.size.width / baseRect.width
        
        var cropX = (visibleRect.minX - imageRect.minX) / scale * imageToOriginalScale
        var cropY = (visibleRect.minY - imageRect.minY) / scale * imageToOriginalScale
        var cropMaxX = (visibleRect.maxX - imageRect.minX) / scale * imageToOriginalScale
        var cropMaxY = (visibleRect.maxY - imageRect.minY) / scale * imageToOriginalScale
        
        cropX = max(0, cropX)
        cropY = max(0, cropY)
        cropMaxX = min(background.size.width, cropMaxX)
        cropMaxY = min(background.size.height, cropMaxY)
        
        let cropWidth = cropMaxX - cropX
        let cropHeight = cropMaxY - cropY
        
        if cropWidth <= 0 || cropHeight <= 0 {
            return compositeFullImage()
        }
        
        let outputSize = NSSize(width: cropWidth, height: cropHeight)
        
        let image = NSImage(size: outputSize)
        image.lockFocus()
        
        NSColor.white.setFill()
        NSRect(origin: .zero, size: outputSize).fill()
        
        let sourceRect = NSRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        let destRect = NSRect(origin: .zero, size: outputSize)
        background.draw(in: destRect, from: sourceRect, operation: .sourceOver, fraction: 1.0)
        
        let strokeScale = background.size.width / baseRect.width
        
        for stroke in strokes {
            stroke.strokeColor.setStroke()
            stroke.strokeColor.setFill()
            
            for segment in stroke.segments {
                let fromX = (segment.from.x - baseRect.origin.x) * strokeScale - cropX
                let fromY = (segment.from.y - baseRect.origin.y) * strokeScale - cropY
                let toX = (segment.to.x - baseRect.origin.x) * strokeScale - cropX
                let toY = (segment.to.y - baseRect.origin.y) * strokeScale - cropY
                
                let path = NSBezierPath()
                path.lineWidth = segment.lineWidth * strokeScale
                path.lineCapStyle = .round
                path.move(to: NSPoint(x: fromX, y: fromY))
                path.line(to: NSPoint(x: toX, y: toY))
                path.stroke()
            }
        }
        
        // Draw badges
        for badge in badges {
            badge.drawForExport(
                scale: strokeScale,
                offset: NSPoint(
                    x: -baseRect.origin.x * strokeScale - cropX,
                    y: -baseRect.origin.y * strokeScale - cropY
                )
            )
        }
        
        image.unlockFocus()
        
        return image
    }
    
    private func compositeFullImage() -> NSImage? {
        guard let background = backgroundImage else { return nil }
        
        let baseRect = calculateBaseImageRect()
        let outputSize = background.size
        
        let image = NSImage(size: outputSize)
        image.lockFocus()
        
        background.draw(in: NSRect(origin: .zero, size: outputSize), from: .zero, operation: .sourceOver, fraction: 1.0)
        
        let strokeScale = background.size.width / baseRect.width
        
        for stroke in strokes {
            stroke.strokeColor.setStroke()
            stroke.strokeColor.setFill()
            
            for segment in stroke.segments {
                let fromX = (segment.from.x - baseRect.origin.x) * strokeScale
                let fromY = (segment.from.y - baseRect.origin.y) * strokeScale
                let toX = (segment.to.x - baseRect.origin.x) * strokeScale
                let toY = (segment.to.y - baseRect.origin.y) * strokeScale
                
                let path = NSBezierPath()
                path.lineWidth = segment.lineWidth * strokeScale
                path.lineCapStyle = .round
                path.move(to: NSPoint(x: fromX, y: fromY))
                path.line(to: NSPoint(x: toX, y: toY))
                path.stroke()
            }
        }
        
        // Draw badges
        for badge in badges {
            badge.drawForExport(
                scale: strokeScale,
                offset: NSPoint(
                    x: -baseRect.origin.x * strokeScale,
                    y: -baseRect.origin.y * strokeScale
                )
            )
        }
        
        image.unlockFocus()
        
        return image
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if let background = backgroundImage {
            let imageRect = calculateImageRect()
            background.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        
        let imageRect = calculateImageRect()
        let baseRect = calculateBaseImageRect()
        let viewScale = imageRect.width / baseRect.width
        let viewOffset = NSPoint(
            x: imageRect.origin.x - baseRect.origin.x * viewScale,
            y: imageRect.origin.y - baseRect.origin.y * viewScale
        )
        
        for stroke in strokes {
            stroke.draw(viewScale: viewScale, viewOffset: viewOffset)
        }
        
        currentStroke?.draw(viewScale: viewScale, viewOffset: viewOffset)
        
        // Draw badges
        for badge in badges {
            badge.draw(viewScale: viewScale, viewOffset: viewOffset)
        }
        
        // Draw crop rectangle if active
        if let rect = cropRect {
            let dashPattern: [CGFloat] = [6, 3]
            
            NSColor.black.withAlphaComponent(0.4).setFill()
            
            NSRect(x: bounds.minX, y: rect.maxY, width: bounds.width, height: bounds.maxY - rect.maxY).fill()
            NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: rect.minY - bounds.minY).fill()
            NSRect(x: bounds.minX, y: rect.minY, width: rect.minX - bounds.minX, height: rect.height).fill()
            NSRect(x: rect.maxX, y: rect.minY, width: bounds.maxX - rect.maxX, height: rect.height).fill()
            
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 2
            path.setLineDash(dashPattern, count: 2, phase: 0)
            NSColor.white.setStroke()
            path.stroke()
            
            let innerPath = NSBezierPath(rect: rect.insetBy(dx: 1, dy: 1))
            innerPath.lineWidth = 1
            NSColor.black.setStroke()
            innerPath.stroke()
        }
    }
    
    private func calculateBaseImageRect() -> NSRect {
        guard let image = backgroundImage else { return bounds }
        
        let imageSize = image.size
        let viewSize = bounds.size
        
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var drawRect: NSRect
        
        if imageAspect > viewAspect {
            let height = viewSize.width / imageAspect
            let y = (viewSize.height - height) / 2
            drawRect = NSRect(x: 0, y: y, width: viewSize.width, height: height)
        } else {
            let width = viewSize.height * imageAspect
            let x = (viewSize.width - width) / 2
            drawRect = NSRect(x: x, y: 0, width: width, height: viewSize.height)
        }
        
        return drawRect
    }
    
    private func calculateImageRectWithScale(_ scale: CGFloat) -> NSRect {
        let baseRect = calculateBaseImageRect()
        
        let scaledWidth = baseRect.width * scale
        let scaledHeight = baseRect.height * scale
        
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2
        
        let x = centerX - scaledWidth / 2 + panOffset.x
        let y = centerY - scaledHeight / 2 + panOffset.y
        
        return NSRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
    }
    
    private func calculateImageRect() -> NSRect {
        return calculateImageRectWithScale(zoomScale)
    }
    
    private func viewToImageCoordinates(_ viewPoint: NSPoint) -> NSPoint {
        let imageRect = calculateImageRect()
        let baseRect = calculateBaseImageRect()
        let scale = imageRect.width / baseRect.width
        
        return NSPoint(
            x: baseRect.origin.x + (viewPoint.x - imageRect.origin.x) / scale,
            y: baseRect.origin.y + (viewPoint.y - imageRect.origin.y) / scale
        )
    }
    
    private func screenBrushSizeToImageBrushSize(_ screenSize: CGFloat) -> CGFloat {
        let imageRect = calculateImageRect()
        let baseRect = calculateBaseImageRect()
        let scale = imageRect.width / baseRect.width
        return screenSize / scale
    }
    
    // MARK: - Mouse/Tablet Events
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        lastMouseLocation = point
        
        // Check for double-click to add badge
        if event.clickCount == 2 {
            let imageRect = calculateImageRect()
            if imageRect.contains(point) {
                addNumberBadge(number: currentColorNumber)
                return
            }
        }
        
        if event.modifierFlags.contains(.option) {
            isPanning = true
            lastPanPoint = point
            NSCursor.closedHand.set()
            return
        }
        
        if isCropMode {
            startCrop(at: point)
            return
        }
        
        let imagePoint = viewToImageCoordinates(point)
        startDrawing(at: imagePoint, pressure: event.pressure)
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        lastMouseLocation = point
        
        if isPanning {
            let delta = NSPoint(x: point.x - lastPanPoint.x, y: point.y - lastPanPoint.y)
            panOffset.x += delta.x
            panOffset.y += delta.y
            lastPanPoint = point
            needsDisplay = true
            return
        }
        
        if isCropping {
            continueCrop(to: point)
            return
        }
        
        let imagePoint = viewToImageCoordinates(point)
        continueDrawing(to: imagePoint, pressure: event.pressure)
    }
    
    override func mouseUp(with event: NSEvent) {
        if isPanning {
            isPanning = false
            circleCursor?.set()
            return
        }
        
        if isCropping {
            finishCrop()
            return
        }
        
        finishDrawing()
    }
    
    override func scrollWheel(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        lastMouseLocation = point
        
        if event.modifierFlags.contains(.shift) {
            panOffset.x += event.deltaX * 2
            panOffset.y -= event.deltaY * 2
            needsDisplay = true
        } else {
            let delta = event.deltaY
            if delta > 0 {
                zoomAtPoint(point, factor: 1.1)
            } else if delta < 0 {
                zoomAtPoint(point, factor: 1.0 / 1.1)
            }
            if abs(event.deltaX) > 0.1 {
                panOffset.x += event.deltaX * 2
                needsDisplay = true
            }
        }
    }
    
    override func tabletPoint(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        lastMouseLocation = point
        
        if isDrawing {
            let imagePoint = viewToImageCoordinates(point)
            continueDrawing(to: imagePoint, pressure: event.pressure)
        }
    }
    
    // MARK: - Drawing Logic
    
    private func startDrawing(at imagePoint: NSPoint, pressure: Float = 1.0) {
        isDrawing = true
        lastImagePoint = imagePoint
        
        let imageBrushSize = screenBrushSizeToImageBrushSize(brushSize)
        
        currentStroke = DrawingStroke(strokeColor: currentColor, baseLineWidth: imageBrushSize, pressureFlow: pressureFlow)
        currentStroke?.addSegment(from: imagePoint, to: imagePoint, pressure: pressure, lineWidthInImagePixels: imageBrushSize)
        
        needsDisplay = true
    }
    
    private func continueDrawing(to imagePoint: NSPoint, pressure: Float = 1.0) {
        guard isDrawing, let last = lastImagePoint, let stroke = currentStroke else { return }
        
        let imageBrushSize = screenBrushSizeToImageBrushSize(brushSize)
        stroke.addSegment(from: last, to: imagePoint, pressure: pressure, lineWidthInImagePixels: imageBrushSize)
        lastImagePoint = imagePoint
        
        needsDisplay = true
    }
    
    private func finishDrawing() {
        guard isDrawing, let stroke = currentStroke else { return }
        
        strokes.append(stroke)
        undoStack.append(.stroke(stroke))
        currentStroke = nil
        lastImagePoint = nil
        isDrawing = false
        
        needsDisplay = true
    }
    
    // MARK: - Crop Logic
    
    private func startCrop(at point: NSPoint) {
        isCropping = true
        cropStartPoint = point
        cropRect = NSRect(origin: point, size: .zero)
        needsDisplay = true
    }
    
    private func continueCrop(to point: NSPoint) {
        guard let start = cropStartPoint else { return }
        
        let minX = min(start.x, point.x)
        let minY = min(start.y, point.y)
        let maxX = max(start.x, point.x)
        let maxY = max(start.y, point.y)
        
        cropRect = NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        needsDisplay = true
    }
    
    private func finishCrop() {
        isCropping = false
        
        guard let rect = cropRect, rect.width > 10, rect.height > 10 else {
            cropRect = nil
            needsDisplay = true
            return
        }
        
        applyCrop(viewRect: rect)
        
        cropRect = nil
        cropStartPoint = nil
        isCropMode = false
        onCropComplete?()
        
        needsDisplay = true
    }
    
    private func applyCrop(viewRect: NSRect) {
        guard let background = backgroundImage else { return }
        
        let previousImage = background
        let previousStrokes = strokes
        let previousBadges = badges
        
        let imageRect = calculateImageRect()
        let baseRect = calculateBaseImageRect()
        let scale = imageRect.width / baseRect.width
        let imageToOriginalScale = background.size.width / baseRect.width
        
        var cropX = (viewRect.minX - imageRect.minX) / scale * imageToOriginalScale
        var cropY = (viewRect.minY - imageRect.minY) / scale * imageToOriginalScale
        var cropMaxX = (viewRect.maxX - imageRect.minX) / scale * imageToOriginalScale
        var cropMaxY = (viewRect.maxY - imageRect.minY) / scale * imageToOriginalScale
        
        cropX = max(0, cropX)
        cropY = max(0, cropY)
        cropMaxX = min(background.size.width, cropMaxX)
        cropMaxY = min(background.size.height, cropMaxY)
        
        let cropWidth = cropMaxX - cropX
        let cropHeight = cropMaxY - cropY
        
        if cropWidth <= 0 || cropHeight <= 0 { return }
        
        let outputSize = NSSize(width: cropWidth, height: cropHeight)
        
        let croppedImage = NSImage(size: outputSize)
        croppedImage.lockFocus()
        
        let sourceRect = NSRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        let destRect = NSRect(origin: .zero, size: outputSize)
        background.draw(in: destRect, from: sourceRect, operation: .sourceOver, fraction: 1.0)
        
        let strokeScale = background.size.width / baseRect.width
        
        for stroke in strokes {
            stroke.strokeColor.setStroke()
            stroke.strokeColor.setFill()
            
            for segment in stroke.segments {
                let fromX = (segment.from.x - baseRect.origin.x) * strokeScale - cropX
                let fromY = (segment.from.y - baseRect.origin.y) * strokeScale - cropY
                let toX = (segment.to.x - baseRect.origin.x) * strokeScale - cropX
                let toY = (segment.to.y - baseRect.origin.y) * strokeScale - cropY
                
                let path = NSBezierPath()
                path.lineWidth = segment.lineWidth * strokeScale
                path.lineCapStyle = .round
                path.move(to: NSPoint(x: fromX, y: fromY))
                path.line(to: NSPoint(x: toX, y: toY))
                path.stroke()
            }
        }
        
        // Draw badges into cropped image
        for badge in badges {
            badge.drawForExport(
                scale: strokeScale,
                offset: NSPoint(
                    x: -baseRect.origin.x * strokeScale - cropX,
                    y: -baseRect.origin.y * strokeScale - cropY
                )
            )
        }
        
        croppedImage.unlockFocus()
        
        undoStack.append(.crop(previousImage: previousImage, previousStrokes: previousStrokes, previousBadges: previousBadges))
        
        backgroundImage = croppedImage
        strokes.removeAll()
        badges.removeAll()
        resetZoom()
    }
}
