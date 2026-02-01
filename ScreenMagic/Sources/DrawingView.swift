import AppKit

/// A single segment of a stroke with its own width (for pressure sensitivity)
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
    
    init(strokeColor: NSColor, baseLineWidth: CGFloat) {
        self.strokeColor = strokeColor
        self.baseLineWidth = baseLineWidth
    }
    
    func addSegment(from: NSPoint, to: NSPoint, pressure: Float) {
        let width = baseLineWidth * CGFloat(max(0.1, pressure))
        segments.append(StrokeSegment(from: from, to: to, lineWidth: width))
    }
    
    func draw() {
        strokeColor.setStroke()
        
        for segment in segments {
            let path = NSBezierPath()
            path.lineWidth = segment.lineWidth
            path.lineCapStyle = .round
            path.move(to: segment.from)
            path.line(to: segment.to)
            path.stroke()
        }
    }
    
    func draw(withOffset offset: NSPoint) {
        strokeColor.setStroke()
        
        for segment in segments {
            let path = NSBezierPath()
            path.lineWidth = segment.lineWidth
            path.lineCapStyle = .round
            path.move(to: NSPoint(x: segment.from.x - offset.x, y: segment.from.y - offset.y))
            path.line(to: NSPoint(x: segment.to.x - offset.x, y: segment.to.y - offset.y))
            path.stroke()
        }
    }
}

/// A custom view that supports drawing on top of a background image
class DrawingView: NSView {
    
    // MARK: - Properties
    
    /// The background screenshot image
    private var backgroundImage: NSImage?
    
    /// Current drawing color
    var currentColor: NSColor = .systemRed
    
    /// Current brush size
    var brushSize: CGFloat = 3.0
    
    /// All completed drawing strokes
    private var strokes: [DrawingStroke] = []
    
    /// Currently active stroke being drawn
    private var currentStroke: DrawingStroke?
    
    /// Last point for drawing segments
    private var lastPoint: NSPoint?
    
    /// Tracks if we're currently drawing
    private var isDrawing = false
    
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
    }
    
    // MARK: - Public Methods
    
    /// Sets the background image (screenshot)
    func setBackgroundImage(_ image: NSImage) {
        backgroundImage = image
        needsDisplay = true
    }
    
    /// Undoes the last stroke
    func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        needsDisplay = true
    }
    
    /// Clears all drawings (keeps background)
    func clearDrawings() {
        strokes.removeAll()
        needsDisplay = true
    }
    
    /// Returns a composite image with background and all drawings
    /// Only includes the actual image area, no transparent padding
    func compositeImage() -> NSImage? {
        guard let background = backgroundImage else { return nil }
        
        // Use the original background image size (not the view bounds)
        let imageRect = calculateImageRect()
        let outputSize = imageRect.size
        
        let image = NSImage(size: outputSize)
        
        image.lockFocus()
        
        // Draw background at origin (0,0) in the output image
        background.draw(in: NSRect(origin: .zero, size: outputSize), from: .zero, operation: .sourceOver, fraction: 1.0)
        
        // Draw all strokes with adjusted coordinates
        let offset = NSPoint(x: imageRect.origin.x, y: imageRect.origin.y)
        for stroke in strokes {
            stroke.draw(withOffset: offset)
        }
        
        image.unlockFocus()
        
        return image
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw background
        if let background = backgroundImage {
            let imageRect = calculateImageRect()
            background.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        
        // Draw all completed strokes
        for stroke in strokes {
            stroke.draw()
        }
        
        // Draw current stroke
        currentStroke?.draw()
    }
    
    /// Calculates the rect to draw the background image (aspect fit)
    private func calculateImageRect() -> NSRect {
        guard let image = backgroundImage else { return bounds }
        
        let imageSize = image.size
        let viewSize = bounds.size
        
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var drawRect: NSRect
        
        if imageAspect > viewAspect {
            // Image is wider - fit to width
            let height = viewSize.width / imageAspect
            let y = (viewSize.height - height) / 2
            drawRect = NSRect(x: 0, y: y, width: viewSize.width, height: height)
        } else {
            // Image is taller - fit to height
            let width = viewSize.height * imageAspect
            let x = (viewSize.width - width) / 2
            drawRect = NSRect(x: x, y: 0, width: width, height: viewSize.height)
        }
        
        return drawRect
    }
    
    // MARK: - Mouse/Tablet Events
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        startDrawing(at: point, pressure: event.pressure)
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        continueDrawing(to: point, pressure: event.pressure)
    }
    
    override func mouseUp(with event: NSEvent) {
        finishDrawing()
    }
    
    // Handle tablet events for pressure sensitivity
    override func tabletPoint(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        if isDrawing {
            continueDrawing(to: point, pressure: event.pressure)
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    // MARK: - Drawing Logic
    
    private func startDrawing(at point: NSPoint, pressure: Float = 1.0) {
        isDrawing = true
        lastPoint = point
        
        currentStroke = DrawingStroke(strokeColor: currentColor, baseLineWidth: brushSize)
        
        // Draw a dot at the starting point
        currentStroke?.addSegment(from: point, to: point, pressure: pressure)
        
        needsDisplay = true
    }
    
    private func continueDrawing(to point: NSPoint, pressure: Float = 1.0) {
        guard isDrawing, let last = lastPoint, let stroke = currentStroke else { return }
        
        // Add a new segment from last point to current point with current pressure
        stroke.addSegment(from: last, to: point, pressure: pressure)
        lastPoint = point
        
        needsDisplay = true
    }
    
    private func finishDrawing() {
        guard isDrawing, let stroke = currentStroke else { return }
        
        strokes.append(stroke)
        currentStroke = nil
        lastPoint = nil
        isDrawing = false
        
        needsDisplay = true
    }
}
