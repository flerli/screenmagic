# ScreenMagic

A macOS screenshot annotation tool designed for quick visual communication. Capture screenshots with global hotkeys, annotate them with pen/tablet support, and copy directly to clipboard.

![ScreenMagic](https://img.shields.io/badge/macOS-12.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

![ScreenMagic Screenshot](ScreenMagic/media/ScreenMagic.jpg)

## Features

### Screenshot Capture
- **Global hotkey** (default: F13) to capture screenshots instantly
- **Multi-display support** - choose which display to capture
- **Custom capture area** - define specific regions relative to the selected display
- **Configurable border** - add padding around screenshots for annotation space

### Drawing & Annotation
- **Pressure-sensitive drawing** with Wacom tablet support
- **Multiple colors** - Red, Blue, Green, Yellow, Black, White
- **Adjustable stroke size** with real-time circle cursor preview
- **Pressure flow control** - configure how much pen pressure affects stroke thickness
- **Consistent stroke behavior**:
  - While drawing: stroke thickness stays constant on screen
  - After drawing: strokes become part of the image and scale with zoom
- **Undo support** (Cmd+Z)
- **Clear all drawings**

### Zoom & Pan
- **Mouse/tablet wheel zoom** centered on cursor position
- **Fit button** to reset view to image-fit
- **Option+drag** to pan the image
- **Shift+scroll** for manual panning
- Zoom out stops at perfect image-fit (no empty gray space)

### Export
- **Copy to clipboard** (Cmd+C) - copies visible/cropped area
- **Save to file** (Cmd+S) - save as PNG
- When zoomed in, exports only the visible cropped portion

## Installation

### Build from Source

```bash
cd ScreenMagic
./build.sh
```

The built app will be at `build/ScreenMagic.app`

### Install to Applications

```bash
cp -r build/ScreenMagic.app /Applications/
```

### Run

```bash
open /Applications/ScreenMagic.app
```

## Usage

1. **Launch ScreenMagic** - appears in menu bar
2. **Press F13** (or configured hotkey) to capture a screenshot
3. **Draw annotations** using mouse or Wacom tablet
4. **Press F14** (or Cmd+C) to copy to clipboard
5. **Paste** into any app (Slack, VS Code, email, etc.)

### Menu Bar Options
- **Take Screenshot** - manual trigger
- **Configuration** - open settings window
- **Quit** - exit application

## Configuration

Access via menu bar → Configuration:

### Capture Settings
| Setting | Description |
|---------|-------------|
| Source Display | Which monitor to capture |
| Use Custom Capture Area | Enable to capture specific region |
| X, Y, Width, Height | Capture region (relative to selected display) |

### Window Settings  
| Setting | Description |
|---------|-------------|
| Target Display | Where the drawing window appears |
| Center Window | Auto-center or use custom position |
| Window Size | Default drawing window dimensions |

### Drawing Settings
| Setting | Description |
|---------|-------------|
| Border (px) | Padding added around screenshot |
| Stroke Size | Default brush size in pixels |
| Pressure Flow | 0% = constant thickness, 100% = full pressure sensitivity |

### Keyboard Shortcuts
| Setting | Description |
|---------|-------------|
| Screenshot Key | Trigger capture (default: F13) |
| Copy Key | Copy and close window (default: F14) |

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Take Screenshot | F13 (configurable) |
| Copy to Clipboard | Cmd+C or F14 |
| Save to File | Cmd+S |
| Undo | Cmd+Z |
| Pan | Option+Drag |
| Pan (alternate) | Shift+Scroll |
| Zoom | Scroll wheel |
| Reset Zoom | Click "Fit" button |

## Requirements

- macOS 12.0 (Monterey) or later
- Screen Recording permission (required for screenshots)
- Accessibility permission (for global hotkeys)

## Permissions

On first launch, macOS will prompt for:

1. **Screen Recording** - required to capture screenshots
2. **Accessibility** - required for global hotkey registration

Grant these in **System Preferences → Privacy & Security**.

## Wacom Tablet Tips

- Map tablet buttons to F13 (screenshot) and F14 (copy)
- The rotation wheel triggers zoom by default
- Pressure sensitivity works automatically with supported tablets
- Adjust "Pressure Flow" in settings to control thickness variation

## Technical Details

- Built with Swift and AppKit
- Uses Carbon API for global hotkey registration
- CGWindowListCreateImage for screen capture
- Pressure sensitivity via NSEvent tablet events
- No external dependencies

## Project Structure

```
ScreenMagic/
├── Sources/
│   ├── main.swift              # App entry point
│   ├── AppDelegate.swift       # Menu bar, hotkeys, app lifecycle
│   ├── ScreenshotManager.swift # Screen capture logic
│   ├── DrawingWindowController.swift # Drawing window & toolbar
│   ├── DrawingView.swift       # Canvas with zoom/pan/drawing
│   ├── ConfigManager.swift     # Settings persistence
│   └── ConfigWindowController.swift # Configuration UI
├── Resources/
│   └── Info.plist
├── Package.swift
└── build.sh
```

## License

MIT License

Copyright © 2026 [swaibian.com](https://swaibian.com)

## Contributing

Pull requests welcome! Please ensure code builds without warnings.
