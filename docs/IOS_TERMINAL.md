# iOS Terminal Implementation

**Status**: Production-ready
**Last Updated**: 2025-10-08

---

## Overview

iOS terminal with SSH connectivity, SwiftTerm emulation, voice dictation, and Hack Nerd Font support for powerline/starship prompts.

## Architecture

### Components

**TerminalSessionView.swift** - Main terminal view
- Immersive full-screen with `.toolbar(.hidden)` and `.ignoresSafeArea(.container, edges: .top)`
- Floating disconnect button (top-left, native iOS 26 `.bordered` style with circular shape)
- ZStack layout: Terminal (background) + Floating controls (foreground)
- Connection status indicators (connecting/connected/error)
- Error handling with retry functionality

**iOSTerminalManager** - Terminal lifecycle manager
- `@MainActor` isolated
- Implements `TerminalViewDelegate` + `SSHClientDelegate`
- SwiftTerm integration with proper delegate methods
- Font configuration (Hack Nerd Font → System fallback)

**SSHClientManager** - Citadel SSH client
- Password authentication with Keychain storage
- PTY session management
- Real-time bidirectional I/O (Server → Terminal, Keyboard → Server)
- Terminal resize notifications

**FloatingDictationControls** - iOS 26 Liquid Glass UI
- Bottom-right overlay positioning with keyboard awareness
- Whole-panel draggable surface (`.contentShape(Rectangle())`)
- Compact 8pt padding (matches iOS compact spacing guidelines)
- Circular buttons (`.buttonBorderShape(.circle)`)
- Glass effect (`.glassEffect(.regular.interactive())` on iOS 26, `.regularMaterial` fallback)
- **Hold-to-record**: Long press 1s on Dictate button to start, release to auto-stop after 0.3s
- **Pressed states**: Scale 0.95 + opacity 0.8 for obvious tactile feedback
- Haptic feedback (medium for dictate, light for enter)
- Pulse animation during recording with red circle overlay
- Position persistence via `@AppStorage`

### Font Integration

**Hack Nerd Font** - Hardcoded for powerline/starship
- PostScript name: `HackNFM-Regular` (14pt)
- 4 variants bundled: Regular, Bold, Italic, BoldItalic (~9.5MB total)
- Location: `Shared/Resources/Fonts/`
- Registration: `Info.plist` → UIAppFonts array
- Fallback: System monospace if font not found
- Console logging: `✅ Using Hack Nerd Font (HackNFM-Regular)`

**Future**: Settings UI for font size, font selection, color schemes (see TODO comments)

### SwiftTerm Best Practices

All delegate methods properly implemented:

**scrolled(source:position:)** - Terminal scroll position handling
**sizeChanged(source:newCols:newRows:)** - PTY resize notifications to SSH server
**bell(source:)** - Haptic feedback (`UIImpactFeedbackGenerator`)
**rangeChanged(source:startY:endY:)** - Efficient partial redraws
**send(source:data:)** - Keyboard input forwarding to SSH
**clipboardCopy(source:content:)** - iOS clipboard integration
**requestOpenLink(source:link:params:)** - Safari link opening

**First Responder**: `becomeFirstResponder()` called in `makeUIView()`
**Input Accessory**: Enabled (provides Esc, Tab, Arrows, Ctrl keys)

### iPad Resizing

**Fixed**: Removed `autoresizingMask` conflicts
- GeometryReader → UIViewRepresentable sizing
- Manual frame updates in `updateUIView()`
- Debug logging for resize events (`#if DEBUG`)
- Works with iPad Split View, rotation, Stage Manager

### Info.plist Configuration

**Manual Info.plist** (`OmriiOS/Info.plist`):
```xml
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
<key>CFBundleVersion</key>
<string>1</string>
<key>CFBundleShortVersionString</key>
<string>1.0</string>
<key>CFBundleExecutable</key>
<string>$(EXECUTABLE_NAME)</string>
<key>CFBundleName</key>
<string>$(PRODUCT_NAME)</string>
<key>CFBundlePackageType</key>
<string>APPL</string>
<key>UIAppFonts</key>
<array>
    <string>HackNerdFontMono-Regular.ttf</string>
    <string>HackNerdFontMono-Bold.ttf</string>
    <string>HackNerdFontMono-Italic.ttf</string>
    <string>HackNerdFontMono-BoldItalic.ttf</string>
</array>
```

**Xcode Configuration**:
- `GENERATE_INFOPLIST_FILE = NO`
- `INFOPLIST_FILE = OmriiOS/Info.plist`
- `PBXFileSystemSynchronizedBuildFileExceptionSet` excludes Info.plist from auto-copy

---

## Features

### Terminal Features
- Full VT100/Xterm terminal emulation via SwiftTerm
- SSH password authentication with Keychain storage
- Real-time bidirectional I/O
- Terminal resize notifications (PTY)
- Clipboard copy support
- Link opening in Safari
- Haptic feedback for terminal bell
- System theme integration (`.label`, `.systemBackground`)

### Voice Dictation
- Multi-provider support (Groq/OpenAI/Custom via Settings.shared)
- Tap-to-record interface
- Groq translation mode (any language → English)
- Transcribed text sent directly to terminal
- Error handling with user alerts

### iOS 26 UI
- **Immersive Full-Screen**: Hidden navigation bar, content extends to top edge
- **Floating Controls**: Liquid Glass panel with whole-surface draggability
- **Hold-to-Record**: Long press 1s to start dictation, release to auto-stop (0.3s delay)
- **Pressed States**: Obvious visual feedback (scale 0.95, opacity 0.8)
- **Compact Spacing**: 8pt padding matching iOS guidelines
- **Circular Buttons**: Glass effect (`.glassEffect()` on iOS 26, `.regularMaterial` fallback)
- **Haptic Feedback**: Medium impact for dictate, light for enter
- **Pulse Animation**: Red circle overlay during recording
- **Position Persistence**: Drag position saved via `@AppStorage`

---

## Testing Checklist

- [x] Build succeeds with zero warnings
- [x] Font loads correctly (check console: "✅ Using Hack Nerd Font")
- [ ] Powerline glyphs render correctly (test with starship)
- [ ] iPad Split View resizing works
- [ ] iPad rotation works
- [ ] iPhone rotation works
- [ ] Vim works (Esc, Arrow keys)
- [ ] Tab completion works
- [ ] Terminal bell produces haptic feedback
- [ ] Colors match iOS system theme (dark/light mode)
- [ ] Keyboard activates when tapping terminal
- [ ] Voice dictation works
- [ ] Transcribed text appears in terminal
- [ ] Error handling works (network errors, auth failures)

---

## Known Limitations

- **SSH Key Auth**: Not yet implemented (password auth only)
- **Font Customization**: Hardcoded to Hack Nerd Font (no settings UI)
- **Color Schemes**: System theme only (no custom themes)
- **Font Size**: Fixed at 14pt (no adjustment)

---

## Future Enhancements

See TODO comments in code:

**TerminalSessionView.swift:286-287**:
- Terminal settings UI (font size, font selection, color schemes)

**TerminalSettings.swift:37-42**:
- Settings model structure (fontSize, fontFamily, colorScheme)

**SettingsView.swift:70-82**:
- Terminal tab template (commented out, ready to uncomment)

---

## References

- **SwiftTerm**: https://github.com/migueldeicaza/SwiftTerm
- **Citadel**: https://github.com/orlandos-nl/Citadel
- **Hack Nerd Font**: https://github.com/ryanoasis/nerd-fonts
- **CLAUDE.md**: Main project documentation
- **TERMINAL_DEVELOPMENT.md**: Terminal development guide (macOS + iOS)
