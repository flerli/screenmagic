import Foundation
import Carbon.HIToolbox
import AppKit

/// Configuration for the ScreenMagic app
struct AppConfig: Codable {
    /// Index of the display to capture screenshots from (0 = main display)
    var sourceDisplayIndex: Int = 0
    
    /// Whether to use custom capture area instead of full display
    var useCustomCaptureArea: Bool = false
    
    /// Custom capture area coordinates
    var captureX: Int = 0
    var captureY: Int = 0
    var captureWidth: Int = 1920
    var captureHeight: Int = 1080
    
    /// Index of the display where the drawing window should appear
    var targetDisplayIndex: Int = 0
    
    /// Whether to center the window on the target display
    var centerWindow: Bool = true
    
    /// Position where the drawing window should appear (if not centered)
    var windowPosition: CGPoint = CGPoint(x: 100, y: 100)
    
    /// Size of the drawing window
    var windowSize: CGSize = CGSize(width: 800, height: 600)
    
    /// Key code for taking screenshots (default: F13 = 105)
    var screenshotKeyCode: UInt16 = 105
    
    /// Modifier flags for screenshot key (shift, control, option, command)
    var screenshotModifiers: UInt32 = 0
    
    /// Key code for copying to clipboard (default: F14 = 107)
    var copyKeyCode: UInt16 = 107
    
    /// Modifier flags for copy key
    var copyModifiers: UInt32 = 0
    
    /// Border size in pixels to add around screenshot (for annotations)
    var borderSize: CGFloat = 50
    
    /// Default brush size
    var defaultBrushSize: CGFloat = 3.0
    
    /// Default drawing color (stored as hex)
    var defaultColorHex: String = "#FF0000"
    
    // Custom decoder to handle missing keys with defaults
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceDisplayIndex = try container.decodeIfPresent(Int.self, forKey: .sourceDisplayIndex) ?? 0
        useCustomCaptureArea = try container.decodeIfPresent(Bool.self, forKey: .useCustomCaptureArea) ?? false
        captureX = try container.decodeIfPresent(Int.self, forKey: .captureX) ?? 0
        captureY = try container.decodeIfPresent(Int.self, forKey: .captureY) ?? 0
        captureWidth = try container.decodeIfPresent(Int.self, forKey: .captureWidth) ?? 1920
        captureHeight = try container.decodeIfPresent(Int.self, forKey: .captureHeight) ?? 1080
        targetDisplayIndex = try container.decodeIfPresent(Int.self, forKey: .targetDisplayIndex) ?? 0
        centerWindow = try container.decodeIfPresent(Bool.self, forKey: .centerWindow) ?? true
        windowPosition = try container.decodeIfPresent(CGPoint.self, forKey: .windowPosition) ?? CGPoint(x: 100, y: 100)
        windowSize = try container.decodeIfPresent(CGSize.self, forKey: .windowSize) ?? CGSize(width: 800, height: 600)
        screenshotKeyCode = try container.decodeIfPresent(UInt16.self, forKey: .screenshotKeyCode) ?? 105
        screenshotModifiers = try container.decodeIfPresent(UInt32.self, forKey: .screenshotModifiers) ?? 0
        copyKeyCode = try container.decodeIfPresent(UInt16.self, forKey: .copyKeyCode) ?? 107
        copyModifiers = try container.decodeIfPresent(UInt32.self, forKey: .copyModifiers) ?? 0
        borderSize = try container.decodeIfPresent(CGFloat.self, forKey: .borderSize) ?? 50
        defaultBrushSize = try container.decodeIfPresent(CGFloat.self, forKey: .defaultBrushSize) ?? 3.0
        defaultColorHex = try container.decodeIfPresent(String.self, forKey: .defaultColorHex) ?? "#FF0000"
    }
}

/// Manages loading and saving configuration
class ConfigManager {
    static let shared = ConfigManager()
    
    private let configFileName = "config.json"
    private var _config: AppConfig
    
    var config: AppConfig {
        get { _config }
        set {
            _config = newValue
            saveConfig()
        }
    }
    
    private init() {
        _config = ConfigManager.loadConfig() ?? AppConfig()
    }
    
    private static var configFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("ScreenMagic")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        return appFolder.appendingPathComponent("config.json")
    }
    
    private static func loadConfig() -> AppConfig? {
        let url = configFileURL
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            print("Failed to load config: \(error)")
            return nil
        }
    }
    
    private func saveConfig() {
        let url = ConfigManager.configFileURL
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(_config)
            try data.write(to: url)
            print("Config saved to \(url.path)")
        } catch {
            print("Failed to save config: \(error)")
        }
    }
    
    /// Updates a single config value
    func update(_ block: (inout AppConfig) -> Void) {
        block(&_config)
        saveConfig()
    }
}

// MARK: - Key Code Helpers

struct KeyCodeHelper {
    static let keyCodeNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
        50: "`", 51: "Delete", 53: "Escape",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 103: "F11", 105: "F13", 107: "F14",
        109: "F10", 111: "F12", 113: "F15", 118: "F4",
        120: "F2", 122: "F1",
        123: "Left Arrow", 124: "Right Arrow",
        125: "Down Arrow", 126: "Up Arrow"
    ]
    
    static func name(for keyCode: UInt16) -> String {
        return keyCodeNames[keyCode] ?? "Key \(keyCode)"
    }
    
    /// Returns full shortcut name including modifiers
    static func shortcutName(keyCode: UInt16, modifiers: UInt32) -> String {
        var parts: [String] = []
        
        // Carbon modifier flags
        if modifiers & UInt32(Carbon.controlKey) != 0 {
            parts.append("⌃")
        }
        if modifiers & UInt32(Carbon.optionKey) != 0 {
            parts.append("⌥")
        }
        if modifiers & UInt32(Carbon.shiftKey) != 0 {
            parts.append("⇧")
        }
        if modifiers & UInt32(Carbon.cmdKey) != 0 {
            parts.append("⌘")
        }
        
        parts.append(name(for: keyCode))
        return parts.joined()
    }
    
    /// Converts NSEvent modifier flags to Carbon modifier flags
    static func carbonModifiers(from nsModifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonMods: UInt32 = 0
        
        if nsModifiers.contains(.command) {
            carbonMods |= UInt32(Carbon.cmdKey)
        }
        if nsModifiers.contains(.shift) {
            carbonMods |= UInt32(Carbon.shiftKey)
        }
        if nsModifiers.contains(.option) {
            carbonMods |= UInt32(Carbon.optionKey)
        }
        if nsModifiers.contains(.control) {
            carbonMods |= UInt32(Carbon.controlKey)
        }
        
        return carbonMods
    }
}
