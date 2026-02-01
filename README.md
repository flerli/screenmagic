# ScreenMagic

A macOS screenshot tool designed for use with Wacom Intuos tablets. Take screenshots of a specific display, draw annotations on top, and copy to clipboard - all triggered by tablet buttons.

## Features

- **Menu Bar App**: Runs quietly in the background with a small icon in the macOS menu bar
- **Multi-Display Support**: Configure which display to capture screenshots from
- **Wacom Tablet Integration**: Trigger screenshots and copy actions via configurable tablet buttons
- **Drawing Tools**: 
  - Multiple colors (Red, Blue, Green, Yellow, Black, White)
  - Adjustable brush size
  - Pressure sensitivity support for Wacom tablets
  - Undo support
  - Clear all drawings
- **Configurable Window Position**: Place the drawing window exactly where your Wacom tablet is projected
- **Clipboard Export**: Copy the screenshot with annotations to clipboard with a single button press
- **Save to File**: Export as PNG

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (for building)
- Screen Recording permission (requested on first run)
- Accessibility permission (for global hotkeys)

## Installation

### Build from Source

```bash
cd ScreenMagic
chmod +x build.sh
./build.sh
```

### Install

```bash
cp -r build/ScreenMagic.app /Applications/
```

### Run

```bash
open /Applications/ScreenMagic.app
```

Or double-click the app in Finder.

## Configuration

Click the camera icon in the menu bar and select "Configuration..." to open the settings window.

### Display Settings
- **Display**: Select which monitor to capture screenshots from

### Window Position
- **X, Y**: Set the pixel position where the drawing window appears
- **Width, Height**: Set the size of the drawing window

### Keyboard Shortcuts
- **Screenshot Key**: Default is F5 - press to capture a screenshot
- **Copy Key**: Default is F6 - press to copy screenshot with drawings to clipboard

### Wacom Tablet Buttons
Configure your Wacom tablet buttons in the Wacom preferences to send the keyboard shortcuts above. Alternatively, use the raw tablet button numbers (0-7).

## Usage

1. **Take Screenshot**: Press the configured key (default: F5) or tablet button
2. **Draw**: Use mouse or tablet pen to draw on the screenshot
3. **Change Color**: Click a color button in the toolbar
4. **Adjust Brush Size**: Use the slider in the toolbar
5. **Undo**: Press Cmd+Z or click the Undo button
6. **Clear**: Click the Clear button to remove all drawings
7. **Copy to Clipboard**: Press the configured key (default: F6), tablet button, or Cmd+C
8. **Save**: Press Cmd+S or click the Save button

## Wacom Setup Tips

1. Open **Wacom Tablet Preferences**
2. Select your Intuos tablet
3. Go to the **ExpressKeys** or **Pen Buttons** section
4. Assign a button to **Keystroke**
5. Set the keystroke to F5 (for screenshot) or F6 (for copy)

## Permissions

On first launch, macOS will ask for:

1. **Screen Recording**: Required to capture screenshots
   - Go to System Preferences → Privacy & Security → Screen Recording
   - Enable ScreenMagic

2. **Accessibility**: Required for global hotkey support
   - Go to System Preferences → Privacy & Security → Accessibility
   - Enable ScreenMagic

## Project Structure

```
ScreenMagic/
├── Package.swift           # Swift Package Manager config
├── build.sh               # Build script
├── Sources/
│   ├── main.swift         # App entry point
│   ├── AppDelegate.swift  # Menu bar app & event handling
│   ├── ScreenshotManager.swift    # Screenshot capture
│   ├── DrawingWindowController.swift  # Drawing window
│   ├── DrawingView.swift  # Canvas with drawing support
│   ├── ConfigManager.swift    # Settings persistence
│   └── ConfigWindowController.swift  # Settings UI
└── Resources/
    ├── Info.plist         # App metadata
    └── ScreenMagic.entitlements  # App permissions
```

## License

MIT License
