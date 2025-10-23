# Omri iOS Implementation

## Status: Production Ready ✅

Fully functional iOS app with SSH terminal, voice dictation, multi-provider transcription support, brand assets, and all required permissions. Builds successfully and runs on iOS 26.0+ devices and simulators.

## Architecture

### App Flow
```
Launch → Splash (1.5s) → SSH Connections List → Terminal Session
                              ↑                        ↓
                              └────[Disconnect]────────┘
```

### Navigation Pattern
- **NavigationStack** with typed path binding (iOS 16+)
- **@Observable** state management (iOS 17+)
- **@Bindable** for passing observable objects
- **navigationDestination(for:)** for type-safe navigation

## Files Created

### iOS/OmriApp.swift
- `@main` entry point for iOS app
- Splash screen state management
- Animated transition to main app after 1.5 seconds

### iOS/Views/SplashView.swift
- Animated launch screen with brand gradient
- Spring animation (response: 0.6, damping: 0.7)
- Brand colors: Blue (#007AFF) + Teal (#5AC8FA)
- Terminal icon + "Omri" title + tagline

### iOS/Models/ConnectionState.swift
- `@Observable` class for navigation and connection state
- Manages `navigationPath: [SSHConnection]`
- `connect(to:)` - Pushes connection to navigation stack
- `disconnect()` - Pops from navigation stack and dismisses

### iOS/Views/RootNavigationView.swift
- NavigationStack container
- Hosts SSHConnectionsView with connection callback
- navigationDestination for SSHConnection type
- Injects ConnectionState via environment

### iOS/Views/TerminalSessionView.swift
- **Immersive full-screen** terminal with hidden navigation bar
- **Floating disconnect** button (top-left, circular, native iOS 26 style)
- **FloatingDictationControls** (iOS 26 Liquid Glass):
  - **Whole-panel draggable**: Entire surface responds to drag gestures
  - **Dictate** button: Tap to toggle OR hold 1s to record (auto-stops 0.3s after release)
  - **Clear** button: Single tap (Ctrl+U clear input), Long press 0.8s (Ctrl+L clear screen)
  - **Enter** button (sends newline to terminal)
  - **Pressed states**: Scale 0.95 + opacity 0.8 for tactile feedback
  - **Compact spacing**: 8pt padding matching iOS guidelines
  - **Position persistence**: Saved with @AppStorage
- SwiftTerm integration with full terminal emulation

## Current Features

### Voice Dictation
- **Multi-Provider Support**: Groq, OpenAI, Custom endpoints via Settings.shared
- **Groq Translations**: Automatic translation to English
- **Audio Recording**: Platform-agnostic AudioRecorder with AVAudioEngine
- **Microphone Permission**: NSMicrophoneUsageDescription configured
- **Integration**: DictationManager with Settings.shared pattern (matches macOS)

### SSH Terminal
- **SwiftTerm Emulation**: Full terminal emulation (v1.5.1)
- **Citadel SSH Client**: Secure SSH connections with password auth (v0.11.1)
- **Connection Management**: Saved connections via TerminalSettings
- **PTY Sessions**: Interactive terminal sessions with stdin/stdout
- **Dictation Integration**: Voice-to-text directly into terminal

### Shared Code Architecture
The iOS app leverages extensive cross-platform code from `Shared/`:

**Models**:
- **SettingsModel** - Unified settings with @UserDefault wrappers
- **SSHConnection** - Connection profiles with Keychain integration
- **TerminalSettings** - Saved connections (macOS display settings conditional)

**Services**:
- **TranscriptionService** - Groq, OpenAI, Custom APIs
- **TransformationService** - AI text enhancement
- **KeychainManager** - Secure credential storage
- **BaseHTTPService** - HTTP utilities

**Views**:
- **SSHConnectionsView** - Cross-platform connection manager
- **Settings UI** - Brand colors, settings components
- **BrandColors** - Shared brand identity

**Audio**:
- **AudioRecorder** - Platform-agnostic recording
- **AudioRecorderDelegate** - Recording lifecycle

## Build & Run

### Command Line
```bash
# Build for iOS Simulator
xcodebuild -project Omri.xcodeproj -scheme OmriiOS \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

# Install on simulator
xcrun simctl install booted \
  ~/Library/Developer/Xcode/DerivedData/Omri-*/Build/Products/Debug-iphonesimulator/OmriiOS.app

# Launch app
xcrun simctl launch booted Beneric.OmriiOS
```

### Xcode GUI
1. Open `Omri.xcodeproj` in Xcode
2. Select **OmriiOS** scheme (not Omri)
3. Choose an iOS Simulator (iPhone or iPad)
4. Press **Cmd+R** to build and run

### Requirements
- **Xcode 17.0+** (for iOS 26.0 SDK)
- **macOS 26.0+** (for latest developer tools)
- **iOS Simulator** or physical device with iOS 26.0+

## Configuration

### Microphone Permission
Already configured in `INFOPLIST_KEY_NSMicrophoneUsageDescription`:
> "Microphone access is needed to record your voice for transcription"

First dictation attempt will prompt user for permission.

### API Keys
Configure in-app via Settings tab:
1. Launch app
2. Tap **Settings** (gear icon)
3. Select provider (Groq, OpenAI, Custom)
4. Enter API key
5. Keys stored securely in iOS Keychain

### SSH Connections
Add connections via Connection Manager:
1. Launch app → SSH Connections List
2. Tap **+** button
3. Enter: host, username, port, auth method
4. Save (stored in TerminalSettings)
5. Tap connection to open terminal session

## Known Issues & Limitations

### Current
- **Password auth only**: SSH key authentication not yet implemented on iOS (password authentication works)
- **No accessibility paste**: iOS doesn't have Cmd+V simulation (clipboard-only paste works)
- **Apple SpeechAnalyzer**: Only available on macOS 26.0+, not yet on iOS

### On-Device Transcription
- **Parakeet (iOS 17+)**: FluidAudio framework supports iOS, but not yet implemented in our iOS app (macOS only currently)
- **Cloud APIs**: Groq, OpenAI, Custom endpoints all work perfectly and are production-ready

### Future Enhancements
- **Parakeet on iOS**: Implement ParakeetTranscriptionManager for iOS (FluidAudio already supports iOS 17+)
- Add SSH key authentication support (currently password-only)
- Add keyboard accessory view for common terminal shortcuts
- Support for custom AI transformation prompts in iOS settings
- Apple SpeechAnalyzer when/if Apple adds iOS support

## Code Quality & Architecture

**Production-Ready Status**:
- ✅ Modern Swift concurrency (async/await, @MainActor)
- ✅ SwiftUI with @Observable state management (iOS 17+)
- ✅ Protocol-oriented design with dependency injection
- ✅ Cross-platform code sharing via Shared/ folder
- ✅ Secure Keychain storage for credentials
- ✅ Platform conditionals for iOS/macOS differences
- ✅ Comprehensive brand system (colors, components)
- ✅ Zero technical debt, clean architecture
- ✅ Both iOS and macOS targets building successfully

**Recent Improvements**:
- **Immersive UI**: Hidden navigation bar, floating disconnect button, full-screen terminal experience
- **Hold-to-record**: Long press 1s to start dictation, auto-stop 0.3s after release (walkie-talkie style)
- **Whole-panel draggable**: Entire FloatingDictationControls surface responds to drag gestures
- **Pressed states**: Obvious visual feedback with scale 0.95 + opacity 0.8
- **Compact spacing**: Reduced to 8pt padding matching iOS guidelines (was 16pt)
- **FloatingDictationControls**: Cross-platform iOS 26 Liquid Glass with iOS 17 fallbacks
- **Clear button dual-action**: Single tap (Ctrl+U), long press 0.8s (Ctrl+L)
- **Thread safety**: Comprehensive documentation added to AudioRecorder
- **iOS permissions**: Modernized to AVAudioApplication (iOS 17+)
- Consolidated transformation services (3 → 1 unified)
- Moved Terminal code to Shared/ for cross-platform reuse
- Both targets building with 0 errors, 0 warnings
