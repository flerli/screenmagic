import AppKit
import CoreGraphics

class ScreenshotManager {
    
    /// Check if screen recording permission is granted
    func hasScreenRecordingPermission() -> Bool {
        // Try to capture a 1x1 pixel - if it returns nil or a blank image, no permission
        let testRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        guard let image = CGWindowListCreateImage(
            testRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            return false
        }
        
        // Check if the image has actual content (not just transparent)
        // If no permission, CGWindowListCreateImage returns a valid but empty/background-only image
        return image.width > 0 && image.height > 0
    }
    
    /// Captures a screenshot of the specified display
    /// - Parameter displayIndex: The index of the display to capture (0 = main display)
    /// - Returns: The captured screenshot as NSImage, or nil if capture failed
    func captureDisplay(displayIndex: Int) -> NSImage? {
        let displays = getDisplayList()
        
        guard displayIndex < displays.count else {
            print("Display index \(displayIndex) out of range. Available displays: \(displays.count)")
            return nil
        }
        
        let displayID = displays[displayIndex]
        return captureDisplay(displayID: displayID)
    }
    
    /// Captures a custom area of the screen
    /// - Parameters:
    ///   - rect: The rectangle to capture (in screen coordinates)
    /// - Returns: The captured screenshot as NSImage, or nil if capture failed
    func captureArea(rect: CGRect) -> NSImage? {
        if let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) {
            let size = NSSize(
                width: CGFloat(cgImage.width),
                height: CGFloat(cgImage.height)
            )
            return NSImage(cgImage: cgImage, size: size)
        }
        
        print("CGWindowListCreateImage failed for custom area")
        return nil
    }
    
    /// Captures a screenshot of the specified display by ID
    /// This captures all windows on screen, not just the desktop background
    /// - Parameter displayID: The CGDirectDisplayID of the display to capture
    /// - Returns: The captured screenshot as NSImage, or nil if capture failed
    func captureDisplay(displayID: CGDirectDisplayID) -> NSImage? {
        let displayBounds = CGDisplayBounds(displayID)
        
        // Use CGWindowListCreateImage - this is the standard API
        // It requires Screen Recording permission in System Preferences
        if let cgImage = CGWindowListCreateImage(
            displayBounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) {
            let size = NSSize(
                width: CGFloat(cgImage.width),
                height: CGFloat(cgImage.height)
            )
            return NSImage(cgImage: cgImage, size: size)
        }
        
        print("CGWindowListCreateImage failed")
        print("Please grant Screen Recording permission:")
        print("System Preferences > Privacy & Security > Screen Recording > Enable ScreenMagic")
        
        return nil
    }
    
    /// Returns a list of all available display IDs
    func getDisplayList() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        
        let result = CGGetActiveDisplayList(16, &activeDisplays, &displayCount)
        
        guard result == .success else {
            print("Failed to get display list: \(result)")
            return []
        }
        
        return Array(activeDisplays.prefix(Int(displayCount)))
    }
    
    /// Returns information about all available displays
    func getDisplayInfo() -> [DisplayInfo] {
        let displays = getDisplayList()
        
        return displays.enumerated().map { index, displayID in
            let bounds = CGDisplayBounds(displayID)
            let isMain = CGDisplayIsMain(displayID) != 0
            let name = getDisplayName(displayID: displayID) ?? "Display \(index + 1)"
            
            return DisplayInfo(
                id: displayID,
                index: index,
                name: name,
                bounds: bounds,
                isMain: isMain
            )
        }
    }
    
    /// Gets the name of a display
    private func getDisplayName(displayID: CGDirectDisplayID) -> String? {
        // Try to get display name from IOKit
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IODisplayConnect")
        
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let info = IODisplayCreateInfoDictionary(service, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as? [String: Any],
               let productName = info[kDisplayProductName] as? [String: String],
               let name = productName.values.first {
                IOObjectRelease(service)
                return name
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        
        return nil
    }
}

struct DisplayInfo {
    let id: CGDirectDisplayID
    let index: Int
    let name: String
    let bounds: CGRect
    let isMain: Bool
    
    var description: String {
        let mainIndicator = isMain ? " (Main)" : ""
        return "\(name)\(mainIndicator) - \(Int(bounds.width))x\(Int(bounds.height))"
    }
}
