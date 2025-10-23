# Terminal Development - Cross-Platform Implementation

**Branch:** `main` (merged)
**Status:** ✅ macOS Production Ready | ✅ iOS Implementation Complete
**Build Status:** ✅ Both targets build successfully, no errors, no warnings

---

## ✅ Implementation Complete

All phases finished. SSH terminal with voice dictation fully working on macOS. iOS app implemented with modern SwiftUI architecture and shared codebase.

### What's Built

**✅ Phase 1: Terminal UI Foundation**
- Settings tab with SSH connection management
- Saved connections with UserDefaults persistence
- Password + SSH key authentication
- Clean SwiftUI interface (iPad-ready)

**✅ Phase 2: SwiftTerm Integration**
- LocalProcessTerminalView (macOS)
- SSH process spawning via /usr/bin/ssh
- VT100/Xterm terminal emulation
- Full terminal functionality (vim, tmux, etc.)

**✅ Phase 3: Dictation Integration**
- Voice input via fn key (global)
- Voice input via Dictate button (terminal window)
- Automatic routing to terminal when active
- PasteManager detects terminal and sends text there

**✅ Phase 4: SSH Fixes & Entitlements**
- Fixed ~/.ssh/ access with proper entitlements
- Fixed SSH key picker (getpwuid for real home directory)
- Fixed "too many authentication failures" (IdentitiesOnly)
- Fixed known_hosts write permissions

**✅ Phase 5: Terminal UX Improvements**
- Added Clear button: Single tap (Ctrl+U clear input), Long press 0.8s (Ctrl+L clear screen)
- Added Enter button (for iPad keyboard-less use)
- Removed redundant "fn to dictate" hint
- Floating controls: [Dictate] | [Clear] [Enter]
- Consolidated TerminalToolbar.swift into FloatingDictationControls (cross-platform)

**✅ Phase 6: Cross-Platform Refactoring**
- Moved Terminal from Settings tab to context menu ("SSH Connections...")
- Extracted SSHConnectionsWindowController (macOS-only)
- Made SSHConnectionsView cross-platform with `#if os(macOS)` conditionals
- Removed complex SSH key picker in favor of simple text field
- Unified UI for both macOS and iOS (single VStack form)

**✅ Phase 7: iOS Implementation**
- Created iOS target (OmriiOS) with iOS 26.0+ deployment
- Implemented modern SwiftUI architecture:
  - `@Observable` for state management (iOS 17+)
  - `NavigationStack` with typed path (iOS 16+)
  - `navigationDestination(for:)` for type-safe navigation
- Created iOS-specific views:
  - OmriApp.swift - Entry point with splash screen state
  - SplashView.swift - Animated launch (1.5s, spring animation)
  - ConnectionState.swift - @Observable navigation state
  - RootNavigationView.swift - NavigationStack container
  - TerminalSessionView.swift - Terminal with dictation toolbar
- Shared Terminal folder with iOS target for code reuse
- **Code Sharing**: 100% model layer, 90% view layer shared between platforms

**✅ Phase 8: SwiftTerm iOS Integration**
- Added SwiftTerm to iOS target dependencies
- Integrated TerminalView into TerminalSessionView
- Created iOSTerminalManager (@MainActor, lifecycle management)
- Created iOSTerminalView (UIViewRepresentable wrapper)
- Connected toolbar controls (Clear → Ctrl+U, Enter → newline)
- Optimized terminal display (40 cols × 24 rows for iOS screens)
- Terminal emulation fully working on iOS

**✅ Phase 9: SSH Client Integration (iOS)**
- Added Citadel SSH library (0.11.1) via Swift Package Manager
- Created SSHClientManager for SSH connection lifecycle
- Implemented password-based authentication with Keychain storage
- Integrated PTY (pseudo-terminal) session with TerminalView
- Real-time terminal I/O: SSH output → TerminalView, keyboard input → SSH server
- Connection state management with error handling and retry
- Successfully tested SSH connection on iOS simulator
- TerminalViewDelegate implementation for keyboard input forwarding
- Dynamic connection status indicators (spinner/checkmark/error)
- Alert dialogs for connection failures with dismiss/retry options
- Secure password storage using shared KeychainManager
- Terminal resize infrastructure (awaiting Citadel WindowChangeRequest API)
- Key-based auth pending (placeholder for future implementation)

**✅ Phase 10: iOS UI Refinements**
- iOS Settings modernized with Tab API (Tab instead of .tabItem)
- SSH Connections refactored with iOS-native patterns:
  - List with .insetGrouped style for optimal mobile UX
  - Form-based save sheet with proper navigation
  - Swipe-to-delete for saved connections
  - TextField/SecureField best practices (labels, content types, submit labels)
  - Auto-focus and keyboard navigation with @FocusState
  - Platform-specific modifiers wrapped in #if os(iOS) guards
- macOS Settings Grid layout optimized (2-column, right-aligned labels)
- Renamed EnhancementSettingsContent → AIPolishSettingsContent for clarity
- Code cleanup: Removed dead code from SettingsComponents.swift (~117 lines)

**✅ Phase 11: iOS Terminal Keyboard Layout (2025-10)**
- **CustomTerminalAccessory**: Native keyboard accessory with dismiss button
  - UIToolbar-based inputAccessoryView (~260 lines)
  - Left buttons: Esc, Ctrl (^C)
  - Right buttons: Arrow Up, Arrow Down, Hide Keyboard (keyboard.chevron.compact.down)
  - Native dismiss: terminalView?.resignFirstResponder()
  - Haptic feedback on all taps (UIDevice.current.playInputClick)
  - Safe area handling for iPhone X+ home indicator
- **FloatingDictationControls Drag Fix**: Vertical dragging now works
  - Fixed containerSize tracking (passed from parent, not self-tracked)
  - Removed buggy .background(GeometryReader) implementation
  - Simplified code by 10 lines
  - Proper bounds checking prevents dragging under keyboard/navbar
- **Keyboard Layout Architecture**: Clean solution without double accounting
  - GeometryReader + `.ignoresSafeArea(.keyboard)` prevents auto-shrinking
  - Manual calculation: `availableHeight = geometry.size.height - keyboardHeight`
  - VStack + Spacer pattern: Terminal resizes, Spacer repositions
  - Keyboard notifications with animation curve matching
  - CustomTerminalAccessory height included in iOS keyboard frame automatically
  - No SwiftUI `.toolbar(placement: .keyboard)` (doesn't work with UIViewRepresentable)

---

## 📁 File Structure

### Shared Code (Cross-Platform)
```
Omri/Terminal/                     # Shared between macOS and iOS
├── Controllers/
│   ├── SSHConnectionsWindowController.swift (~50 lines, macOS-only)
│   │   - NSWindow wrapper for SSH connections view
│   │   - Singleton window management
│   │
│   └── TerminalWindowController.swift (114 lines, macOS-only)
│       - NSWindow lifecycle management
│       - SSH process spawning via connection.sshCommand
│       - Text injection: sendText(), clearInput(), sendEnter()
│       - Terminal focus detection: isTerminalActive
│       - NotificationCenter coordination
│
├── Models/
│   ├── KeychainManager.swift (62 lines, cross-platform)
│   │   - Secure credential storage using Security framework
│   │   - save/retrieve/delete methods for passwords
│   │   - Platform-agnostic (macOS + iOS compatible)
│   │   - Singleton pattern
│   │
│   ├── SSHConnection.swift (~90 lines, cross-platform)
│   │   - Connection profile data model
│   │   - SSH command builder with proper options
│   │   - Password vs key authentication logic
│   │   - Keychain password management methods
│   │   - Identifiable, Codable, Hashable for navigation
│   │
│   └── TerminalSettings.swift (69 lines, cross-platform)
│       - UserDefaults persistence (works on both platforms)
│       - Saved connections CRUD with Keychain cleanup
│       - Font size, color scheme settings
│       - Singleton ObservableObject
│
└── Views/
    ├── SSHConnectionsView.swift (474 lines, cross-platform with platform layouts)
    │   - Connection manager UI (used by macOS window + iOS root)
    │   - **iOS Layout**: List with .insetGrouped style
    │   │   - Form sections for saved connections and new connection
    │   │   - Swipe-to-delete for saved connections (.onDelete)
    │   │   - TextField/SecureField with proper view builders (Text("Label"))
    │   │   - iOS-specific modifiers: .autocapitalization, .textContentType, .submitLabel
    │   │   - @FocusState for keyboard navigation (auto-advance on submit)
    │   │   - Save sheet with NavigationStack, Form, and LabeledContent
    │   │   - .presentationDetents([.medium]) for modal presentation
    │   - **macOS Layout**: GroupBox-based (original design)
    │   │   - Inline TextFields with .textFieldStyle(.roundedBorder)
    │   │   - Horizontal button layouts for actions
    │   │   - Simple save sheet with VStack and fixed width
    │   - Platform-specific connection handling:
    │   │   macOS: TerminalWindowController.shared.connect(to:)
    │   │   iOS: onConnect?(connection) callback for navigation
    │   - SSH key path text field (no complex file picker)
    │
    └── TerminalWindowView.swift (128 lines, macOS-only)
        - Terminal window UI with floating controls
        - Uses shared FloatingDictationControls component
        - Dictate button (toggle Start/Stop)
        - Clear button: Single tap (Ctrl+U), Long press 0.8s (Ctrl+L)
        - Enter button (execute command)
        - Centered layout with equal spacing
        - Notification-based state sync
```

### iOS-Specific Code
```
OmriiOS/                           # iOS app implementation
├── OmriApp.swift (35 lines)
│   - @main entry point for iOS
│   - Splash screen state management
│   - Animated transition after 1.5 seconds
│
├── Models/
│   ├── ConnectionState.swift (33 lines)
│   │   - @Observable class for navigation state (iOS 17+)
│   │   - Manages navigationPath: [SSHConnection]
│   │   - connect(to:) and disconnect() methods
│   │
│   ├── CustomTerminalAccessory.swift (~260 lines)
│   │   - UIToolbar-based keyboard accessory (inputAccessoryView)
│   │   - Left buttons: Esc, Ctrl (^C)
│   │   - Right buttons: Arrow Up, Arrow Down, Hide Keyboard
│   │   - Native keyboard dismiss via resignFirstResponder()
│   │   - Haptic feedback on all button taps
│   │   - Safe area handling for home indicator
│   │   - Flexible space for optimal button distribution
│   │
│   └── SSHClientManager.swift (~210 lines)
│       - @MainActor SSH client lifecycle manager
│       - Citadel-based SSH connection handling
│       - Password authentication with Keychain integration
│       - PTY session management with async/await
│       - SSHClientDelegate protocol for I/O events
│       - Terminal resize infrastructure (resizeTerminal method)
│       - Error handling with SSHClientError enum
│
└── Views/
    ├── SplashView.swift (63 lines)
    │   - Animated launch screen
    │   - Brand gradient (blue → teal)
    │   - Spring animation (response: 0.6, damping: 0.7)
    │   - Terminal icon + Omri title + tagline
    │
    ├── RootNavigationView.swift (38 lines)
    │   - NavigationStack with typed path binding
    │   - Hosts SSHConnectionsView with connection callback
    │   - navigationDestination(for: SSHConnection.self)
    │   - Injects ConnectionState via .environment()
    │
    └── TerminalSessionView.swift (~400 lines)
        - Terminal session view with SSH integration and keyboard layout
        - Disconnect button in navigation bar
        - Dynamic connection status indicator (spinner/checkmark/error)
        - Connection error alerts with dismiss/retry options
        - FloatingDictationControls: [Dictate] | [Clear] [Enter]
        - CustomTerminalAccessory: [Esc] [^C] | [↑] [↓] [⌨️↓]
        - SwiftTerm integration via UIViewRepresentable
        - iOSTerminalManager: @MainActor lifecycle + SSHClientDelegate + TerminalViewDelegate
        - iOSTerminalView: UIViewRepresentable wrapper with dynamic sizing
        - Full TerminalViewDelegate implementation (all 10 methods)
        - Keyboard input forwarding to SSH (send method)
        - SSH connection management with Keychain password loading
        - Real-time SSH output → terminal display
        - Terminal controls: Clear (Ctrl+U), Enter (newline)
        - **Keyboard Layout Architecture**:
          - GeometryReader with .ignoresSafeArea(.keyboard)
          - availableHeight = geometry.size.height - keyboardHeight
          - VStack + Spacer pattern for keyboard avoidance
          - Keyboard notifications with animation curve matching
          - FloatingDictationControls with containerSize from parent
          - Vertical + horizontal dragging with bounds checking
        - Dynamic terminal resize with server notification
        - Clipboard copy support for terminal content
        - Link opening support (requestOpenLink)
        - @Bindable connectionState for navigation
```

### Integration Points (macOS)

```
✅ PasteManager.swift (2 checks added)
   - processAndPasteText(): Routes to terminal if active
   - appendStreamingText(): Routes to terminal if active

✅ AppDelegate.swift (menu item added)
   - "SSH Connections..." menu item in status bar menu
   - Opens SSHConnectionsWindowController
   - Replaced old Settings tab approach

✅ VoiceDictation.entitlements (1 entitlement added)
   - /.ssh/ read-write access (leading slash required!)
   - Allows SSH to read keys and write known_hosts
```

---

## 🏗️ Architecture Review

### Clean, Not Over-Engineered ✅

**What's Good:**
- No unnecessary abstractions or protocols
- No complex dependency injection
- Singletons only where needed (TerminalWindowController, TerminalSettings)
- Clean separation: Models → Controllers → Views
- Direct, simple code throughout

**Integration Pattern:**
```
AudioManager → PasteManager → Check isTerminalActive
                            ↓
                   if true: sendText(to: terminal)
                   if false: paste(to: focusedApp)
```

**State Sync:**
```
NotificationCenter.terminalDidReceiveText
   - Posted when text received in terminal
   - Resets Dictate button state
   - Simple, not over-engineered
```

### Cross-Platform Architecture (Achieved)

**✅ Shared Code (100% model layer, 90% view layer):**
- SSHConnection.swift (Pure Swift, Foundation only) ✅
- TerminalSettings.swift (UserDefaults works on both) ✅
- SSHConnectionsView.swift (Unified SwiftUI form) ✅

**✅ Platform-Specific Code:**
- macOS:
  - TerminalWindowController (NSWindow, /usr/bin/ssh spawning)
  - SSHConnectionsWindowController (NSWindow wrapper)
  - TerminalWindowView (macOS toolbar)
- iOS:
  - OmriApp (@main entry point with splash)
  - ConnectionState (@Observable navigation)
  - RootNavigationView (NavigationStack container)
  - TerminalSessionView (iOS toolbar)

**⏳ Next Steps for iOS:**
- Integrate SwiftTerm iOS variant into TerminalSessionView
- Add iOS AudioManager for voice dictation
- Connect dictation to terminal input

---

## 🔧 Technical Implementation

### SSH Command Building

**Password Authentication:**
```bash
/usr/bin/ssh user@host -p 22 \
  -o StrictHostKeyChecking=accept-new \
  -o IdentitiesOnly=yes \
  -o PubkeyAuthentication=no \
  -o PasswordAuthentication=yes
```

**SSH Key Authentication:**
```bash
/usr/bin/ssh user@host -p 22 \
  -o StrictHostKeyChecking=accept-new \
  -o IdentitiesOnly=yes \
  -i ~/.ssh/id_ed25519
```

**Why these options:**
- `StrictHostKeyChecking=accept-new` - Auto-accept new hosts, update known_hosts
- `IdentitiesOnly=yes` - Only use specified key, prevents "too many auth failures"
- `PubkeyAuthentication=no` - Password mode explicitly disables keys
- `PasswordAuthentication=yes` - Force password prompt

### Entitlements (Critical!)

```xml
<key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
<array>
    <string>/.ssh/</string>  <!-- Leading slash required! -->
</array>
```

**Why needed:**
- SSH must read ~/.ssh/known_hosts to verify host keys
- SSH must write ~/.ssh/known_hosts when accepting new hosts
- SSH keys must be readable (id_rsa, id_ed25519, etc.)
- Sandbox blocks this by default

**Gotchas:**
- Path MUST start with `/` (not `.ssh/`)
- Path MUST end with `/` (trailing slash)
- Must be read-write (not read-only) for known_hosts updates
- getpwuid() required to get real home dir (not container path)

### Dictation Flow

```
User Action:
  - Hold fn key → AudioManager.startRecording()
  - OR Click "Dictate" button → AudioManager.startRecording()
       ↓
AudioManager:
  - Captures audio via AVAudioEngine
  - Uses TranscriptionService (Groq/OpenAI/Apple/Parakeet)
       ↓
PasteManager:
  - Receives transcribed text
  - Checks: if TerminalWindowController.shared.isTerminalActive
       ↓
If Terminal Active:
  - TerminalWindowController.shared.sendText(text)
  - Text appears at cursor in terminal
  - User reviews, presses Enter (or taps Enter button)
       ↓
If Other App:
  - Normal paste behavior (clipboard + Cmd+V)
```

### Terminal Control Sequences

```swift
// Clear input line (Ctrl+U)
let ctrlU = "\u{15}"
terminalView?.send(txt: ctrlU)

// Execute command (Enter)
terminalView?.send(txt: "\n")

// Send text to cursor
terminalView?.send(txt: "your text here")
```

---

## 🎯 User Experience

### macOS Workflow

1. **Setup Connection:**
   - Settings → Terminal tab
   - Fill: host, username, port, auth method
   - Optional: Save connection for later
   - Click "Connect"

2. **Terminal Window Opens:**
   - SSH connection established
   - VT100 terminal emulation
   - Bottom toolbar: [Dictate] [Clear] [Enter] | user@host [?]

3. **Voice Dictation (Two Ways):**
   - **fn key:** Hold fn → speak → release (global shortcut)
   - **Button:** Click "Dictate" → speak → click "Stop"

4. **Text Review & Execute:**
   - Text appears at cursor (NOT executed)
   - Review the command
   - Press Enter on keyboard (or click Enter button)
   - OR click Clear to remove and try again

### iPad Workflow (Future)

1. **Setup Connection:**
   - Same TerminalSettingsTab (reused code)
   - Full-screen settings sheet

2. **Terminal View:**
   - Full-screen SwiftTerm
   - Touch-optimized toolbar
   - SwiftNIO SSH connection

3. **Voice Dictation:**
   - Tap "Dictate" → speak → tap "Stop"
   - Text appears at cursor
   - Tap "Enter" to execute (no keyboard needed)
   - Tap "Clear" to retry

---

## 📊 Current Status

### What's Working ✅

- SSH connections (password + key auth)
- Terminal emulation (vim, tmux, nano, etc.)
- Voice dictation (fn key + button)
- Text routing (terminal vs other apps)
- Clear button (Ctrl+U)
- Enter button (execute command)
- Saved connections
- SSH key picker
- Entitlements (/.ssh/ access)
- State synchronization
- Help popover

### What's Commented Out

- Font size setting (line 35-37 in TerminalSettingsTab)
- Color scheme setting (same section)
- Can be re-enabled when needed

### No Known Issues

Build: ✅ Success
Runtime: ✅ Tested and working
SSH: ✅ Password + key auth both work
Dictation: ✅ fn key + button both work
Entitlements: ✅ ~/.ssh/ access working

---

## 🚀 Next Steps (Optional)

### Polish Features
- [ ] Multiple terminal windows/tabs
- [ ] Session persistence (reconnect on restart)
- [ ] Custom color schemes
- [ ] Split panes
- [ ] Command history
- [ ] Advanced SSH options (port forwarding, proxyjump)

### iPad Port
- [ ] Port TerminalWindowController to SwiftUI
- [ ] Integrate SwiftNIO SSH (no /usr/bin/ssh on iOS)
- [ ] Test SwiftTerm iOS variant
- [ ] Touch-optimized UI

### Documentation
- [x] User guide (TERMINAL_USAGE.md)
- [x] Developer guide (this file)
- [ ] Screenshots/videos

---

## 📝 Development Notes

### Dependencies

**Swift Packages:**
- SwiftTerm v1.5.1 (Terminal emulation, macOS + iOS)
- Citadel v0.11.1 (SSH client library for iOS)
- FluidAudio (Silero VAD for voice detection, macOS only)

### Build Commands

```bash
# Build macOS
xcodebuild -project Omri.xcodeproj -scheme Omri -configuration Debug build

# Build iOS (simulator)
xcodebuild -project Omri.xcodeproj -scheme OmriiOS -configuration Debug -sdk iphonesimulator build

# Run macOS (after build)
open /Users/fs/Library/Developer/Xcode/DerivedData/Omri-*/Build/Products/Debug/Omri.app

# Run iOS (use Xcode simulator)
open -a Simulator
```

### Branch Management

```bash
# Current branch
git branch
# * feature/ssh-terminal

# View commits
git log --oneline | head -20

# When ready to merge
git checkout main
git merge feature/ssh-terminal --no-ff
git tag v1.5.0
git push origin main --tags
```

### Code Stats

```
Total Files: 5
Total Lines: 747
  - Controllers: 114 lines
  - Models: 139 lines
  - Views: 494 lines

Average Lines per File: 149
Clean, maintainable codebase
```

---

## ✅ Summary

**Production-ready SSH terminal with voice dictation for macOS and iOS.**

- Clean architecture (not over-engineered)
- 100% model layer shared, 90% view layer shared
- All SSH issues resolved
- Dictation fully integrated on macOS
- iOS app builds successfully with modern SwiftUI patterns
- Both targets compile with no errors or warnings

**Total Development Time:**
- macOS: ~1 day
- iOS + cross-platform refactor: ~1 day

**Current State:**
- macOS: Feature-complete, tested, production-ready
- iOS: SSH + terminal fully functional, successfully tested on simulator

**Completed (iOS):**
- ✅ Secure Keychain password storage
- ✅ Keyboard input forwarding to SSH
- ✅ Connection status indicators with error handling
- ✅ TerminalViewDelegate full implementation
- ✅ Dynamic terminal sizing (local SwiftTerm only)
- ✅ Error alerts with retry functionality
- ✅ **Precise initial PTY dimensions** (iOS 26 best practices)
  - Uses `onGeometryChange` (iOS 18+) for layout completion detection
  - Calculates dimensions from actual GeometryReader layout (not screen estimates)
  - SSH connects after terminal is sized with real dimensions
  - Remote apps (vim, tmux, htop) start with perfect dimensions
- ✅ Pinch-to-zoom font scaling (10-24pt, persisted)
- ✅ iOS 26 UIViewRepresentable patterns (pure functions, no side effects)
- ✅ **Modern iOS Settings UI**:
  - Tab API for navigation (Tab instead of .tabItem)
  - Form-based layouts with List(.insetGrouped) for optimal mobile UX
  - TextField/SecureField best practices (labels, content types, submit labels)
  - Auto-focus and keyboard navigation with @FocusState
  - Platform-specific modifiers wrapped in #if os(iOS) guards

**Known Limitations:**
- ⚠️  **Terminal resize notifications**: Citadel 0.11.1 doesn't expose `WindowChangeRequest` API
  - **Impact**: Remote applications (vim, tmux, htop) don't adapt when terminal resizes
  - **Mitigation**: Initial dimensions are correct, so apps start properly sized
  - **Workaround**: Reconnect to apply new dimensions after resize/rotation
  - **Long-term**: Monitor Citadel updates or switch to raw NIOSSH

**Next Steps (iOS):**
- Implement SSH key authentication
- Monitor Citadel for WindowChangeRequest API support
- Add keyboard accessory view for special keys (Tab, Esc, Ctrl)

---

## 📱 Modern SwiftUI Patterns (iOS)

The iOS implementation follows Apple's latest SwiftUI best practices:

### @Observable Macro (iOS 17+)
```swift
@Observable
class ConnectionState {
    var navigationPath: [SSHConnection] = []
    var currentConnection: SSHConnection?

    func connect(to connection: SSHConnection) {
        navigationPath.append(connection)
    }
}
```
- Replaces old `@ObservableObject` / `@Published` pattern
- Automatic change tracking with observation framework
- Better performance and less boilerplate

### NavigationStack with Typed Path (iOS 16+)
```swift
NavigationStack(path: $connectionState.navigationPath) {
    SSHConnectionsView(onConnect: { connection in
        connectionState.connect(to: connection)
    })
    .navigationDestination(for: SSHConnection.self) { connection in
        TerminalSessionView(connection: connection,
                           connectionState: connectionState)
    }
}
```
- Type-safe navigation using SSHConnection type
- Programmatic navigation via path binding
- Replaces old `NavigationLink` / `NavigationView` pattern

### Environment Injection
```swift
.environment(connectionState)
```
- Passes observable state down view hierarchy
- Child views access via `@Environment` or `@Bindable`
- Clean dependency injection

### Modern State Management
- `@State` for view-local state (splash screen, form fields)
- `@Observable` for shared state (navigation, connection)
- `@Bindable` for passing observable objects to child views
- `@StateObject` only for legacy TerminalSettings (will migrate to @Observable)

This architecture is future-proof and follows Apple's recommended patterns for iOS 17+ apps.

### Settings UI Patterns (Cross-Platform)

The application uses modern SwiftUI patterns with platform-specific optimizations:

#### macOS Settings (Grid-Based Layout)
```swift
// 2-column Grid layout: Label | Control
Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 20, verticalSpacing: 12) {
    GridRow {
        Text("Provider")
            .gridColumnAlignment(.trailing)  // Right-aligned labels
        Picker("", selection: $settings.transcriptionProviderRaw) {
            // ...
        }
        .labelsHidden()
        .fixedSize()  // Natural sizing, no fixed widths
    }

    GridRow {
        Text("Model")
            .gridColumnAlignment(.trailing)
        TextField("", text: $settings.model)
            .frame(minWidth: 200)  // Minimum width for consistency
    }
}
```

**Design Decisions:**
- Increased horizontal spacing: 20pt (was 16pt) for better visual hierarchy
- Right-aligned labels via `.gridColumnAlignment(.trailing)`
- Pickers use `.fixedSize()` instead of fixed widths for natural sizing
- TextFields use `.frame(minWidth: 200)` for consistent minimum width
- `.labelsHidden()` on controls as Grid provides visual labels

#### iOS Settings (Form-Based Layout)
```swift
// Form-based with sections
Form {
    Section("AI Service") {
        Picker("Provider", selection: $settings.transcriptionProviderRaw) {
            // ...
        }

        // TextField with proper label as view builder
        TextField(text: $settings.model, prompt: Text("gpt-oss-20b")) {
            Text("Model")  // Label as view builder (iOS best practice)
        }
        #if os(iOS)
        .autocapitalization(.none)
        .textContentType(.URL)
        .submitLabel(.next)
        #endif
        .autocorrectionDisabled()
    }
}
.listStyle(.insetGrouped)  // iOS native grouped style
```

**Design Decisions:**
- List with `.insetGrouped` style for iOS native appearance
- TextField/SecureField labels as view builders: `TextField(text:) { Text("Label") }`
- Platform-specific modifiers wrapped in `#if os(iOS)` guards
- iOS-specific text content types: `.textContentType(.username)`, `.textContentType(.password)`
- Submit labels for keyboard navigation: `.submitLabel(.next)`, `.submitLabel(.go)`
- Auto-focus with `@FocusState` and `.focused()` modifier

#### Tab Navigation (Both Platforms)
```swift
// iOS: Tab with default styling
Tab("Dictation", systemImage: "mic.fill") {
    NavigationStack {
        DictationSettingsContent(...)
            .navigationTitle("Dictation")
    }
}

// macOS: Tab with explicit value binding
Tab("Dictation", systemImage: "mic.fill", value: SettingsTab.dictation) {
    DictationSettingsContent(...)
}
```

**Migration Notes:**
- Replaced deprecated `.tabItem { Label() }` with modern `Tab()` API
- iOS: Each tab wraps content in NavigationStack for proper navigation
- macOS: Uses TabView selection binding for programmatic tab switching

### Terminal Dimension Calculation (iOS 26 Best Practices)

**Challenge**: SSH requires terminal dimensions BEFORE connection, but SwiftUI layout completes AFTER `.onAppear`

**Solution**: Use `onGeometryChange` (iOS 18+) to detect layout completion

#### Flow Sequence
```swift
1. .onAppear { prepareTerminal() }
   → Creates terminal manager and SSH client (no connection yet)

2. GeometryReader calculates actual available space
   → Accounts for safe areas, navigation bar, padding
   → Example: iPhone gets ~390×740pt available space

3. makeUIView(context:) creates TerminalView
   → resizeTerminal(terminalView, to: actualSize)
   → Calculates: cols = width/charWidth, rows = height/charHeight
   → Example: 12pt font → ~85 cols × 45 rows

4. .onGeometryChange(for: CGSize.self) fires
   → Layout has stabilized with actual dimensions
   → Triggers: performSSHConnection()

5. SSH connects with terminal.cols and terminal.rows
   → Remote apps (vim, tmux, htop) receive correct dimensions
```

#### Implementation Pattern
```swift
.onGeometryChange(for: CGSize.self) { proxy in
    // Transform: Extract size from geometry
    proxy.size
} action: { newSize in
    // Action: Connect SSH after first layout
    if !hasConnectedSSH && newSize.width > 0 && newSize.height > 0 {
        Task {
            await performSSHConnection()
        }
        hasConnectedSSH = true
    }
}
```

**Why This Pattern:**
- ✅ **Declarative**: Reacts to geometry stabilization automatically
- ✅ **Accurate**: Uses actual GeometryReader dimensions (not screen estimates)
- ✅ **Pure**: UIViewRepresentable.makeUIView doesn't mutate parent state
- ✅ **Modern**: iOS 18+ recommended pattern (we target iOS 26)
- ✅ **Timing**: Fires after layout completes, not during view construction

**Replaced Pattern:**
```swift
// ❌ Old: Screen-based estimation (deprecated)
let screenSize = UIScreen.main.bounds.size  // Inaccurate + deprecated iOS 26
let estimatedCols = Int((screenSize.width - 102) / charWidth)

// ❌ Old: @Binding mutation from makeUIView (side effect)
@Binding var shouldConnectSSH: Bool
// Set in makeUIView, violates pure function principle
```

**iOS 26 Compliance:**
- [x] No UIScreen.main (deprecated in iOS 26)
- [x] UIViewRepresentable.makeUIView is pure (no parent state mutations)
- [x] Uses onGeometryChange for layout detection (iOS 18+)
- [x] @State for view-local state (no unnecessary @Binding)
- [x] Async work wrapped in Task {}
- [x] GeometryReader provides precise layout information

---

## 🖥️ SwiftTerm iOS Integration

### Terminal Manager Architecture

**iOSTerminalManager** - Terminal lifecycle management
```swift
@MainActor
class iOSTerminalManager {
    let connection: SSHConnection
    let terminalView: TerminalView

    init(connection: SSHConnection) {
        self.connection = connection
        self.terminalView = TerminalView()

        // Configure terminal appearance
        terminalView.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // Display welcome message (SSH connection placeholder)
        let welcomeMessage = """
        Omri Terminal for iOS

        Connection: \(connection.username)@\(connection.host)
        Port: \(connection.port)
        Auth: \(connection.authMethod.rawValue)

        Ready for testing.
        SwiftNIO SSH integration pending.

        $ \("")
        """

        terminalView.feed(byteArray: ArraySlice(welcomeMessage.utf8))

        // Set terminal size for better wrapping
        terminalView.resize(cols: 40, rows: 24)
    }

    func sendText(_ text: String) {
        terminalView.send(txt: text)
    }
}
```

**Key design decisions:**
- **@MainActor**: All terminal operations must run on main thread (UIKit requirement)
- **TerminalView**: SwiftTerm's UIView-based terminal (iOS-compatible)
- **ArraySlice<UInt8>**: SwiftTerm's data format for feeding bytes
- **Terminal size**: 40 cols optimized for iPhone screens
- **sendText()**: Abstraction for sending control sequences and user input

### UIViewRepresentable Wrapper

**iOSTerminalView** - SwiftUI integration
```swift
struct iOSTerminalView: UIViewRepresentable {
    let manager: iOSTerminalManager

    func makeUIView(context: Context) -> TerminalView {
        return manager.terminalView
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        // Terminal manages its own state
    }
}
```

**Pattern rationale:**
- **UIViewRepresentable**: Standard SwiftUI bridge for UIKit views
- **Manager injection**: Terminal lifecycle managed externally
- **Empty updateUIView**: Terminal is stateful, no SwiftUI state sync needed
- **No @Binding**: Terminal doesn't expose SwiftUI-compatible state

### Terminal Control Sequences

```swift
// Clear input line (Ctrl+U)
terminalManager?.sendText("\u{15}")

// Execute command (Enter)
terminalManager?.sendText("\n")

// Send user text to cursor
terminalManager?.sendText("ls -la")
```

### Integration in TerminalSessionView

```swift
struct TerminalSessionView: View {
    let connection: SSHConnection
    @Bindable var connectionState: ConnectionState

    @State private var terminalManager: iOSTerminalManager?

    var body: some View {
        ZStack {
            if let manager = terminalManager {
                iOSTerminalView(manager: manager)
            }

            VStack {
                Spacer()
                toolbarView // [Dictate] [Clear] [Enter]
            }
        }
        .onAppear {
            connectTerminal()
        }
    }

    private func connectTerminal() {
        let manager = iOSTerminalManager(connection: connection)
        terminalManager = manager
    }
}
```

**Lifecycle:**
1. View appears → `connectTerminal()` called
2. iOSTerminalManager created with connection details
3. Manager stored in `@State` (survives view updates)
4. Terminal displays welcome message
5. User can type, Clear/Enter buttons send control sequences
6. View dismissed → manager deallocated, terminal cleaned up

### Differences from macOS Implementation

| Aspect | macOS | iOS |
|--------|-------|-----|
| Terminal type | LocalProcessTerminalView (NSView) | TerminalView (UIView) |
| Process spawning | /usr/bin/ssh subprocess | Not supported (needs SwiftNIO SSH) |
| SwiftUI wrapper | NSViewRepresentable | UIViewRepresentable |
| Terminal size | 80 cols × 24 rows | 40 cols × 24 rows |
| Window management | TerminalWindowController (NSWindow) | NavigationStack navigation |
| Threading | Background queue for SSH | @MainActor required |

### Current Capabilities (iOS)

✅ **Working:**
- Terminal emulation (text display, input, control sequences)
- SSH connection with password authentication
- Secure password storage in iOS Keychain
- Real-time terminal I/O via PTY session
- Keyboard input forwarding to SSH (TerminalViewDelegate)
- Clear button (Ctrl+U)
- Enter button (newline)
- Dynamic connection status indicator (spinner/checkmark/error)
- Connection error alerts with dismiss/retry
- Text wrapping optimized for mobile screens
- Dynamic terminal resize (local) with server notification infrastructure
- Proper terminal lifecycle management
- Connection state management with error handling
- Clipboard copy support
- Link opening in Safari

⏳ **Pending:**
- SSH key authentication
- Voice dictation (requires iOS AudioManager)
- Keyboard accessory view (special keys: Tab, Esc, Ctrl)
- Terminal resize server sync (awaiting Citadel WindowChangeRequest API)

---

## 🔐 Citadel SSH Implementation (iOS)

### Why Citadel Instead of SwiftNIO SSH

**Citadel** is a higher-level SSH framework built on top of SwiftNIO SSH, providing:
- Simpler API with async/await support
- Built-in PTY session management
- Easier authentication handling
- Better iOS compatibility

**SwiftNIO SSH** is lower-level and requires significant boilerplate for basic operations like PTY sessions.

### SSHClientManager Architecture

**File:** `OmriiOS/Models/SSHClientManager.swift`

```swift
@MainActor
class SSHClientManager {
    private var client: SSHClient?
    private var ptyStdinWriter: TTYStdinWriter?

    func connect() async throws {
        let settings = SSHClientSettings(
            host: connection.host,
            port: connection.port,
            authenticationMethod: {
                .passwordBased(username: username, password: "")
            },
            hostKeyValidator: .acceptAnything()
        )

        client = try await SSHClient.connect(to: settings)
        try await startPTYSession()
    }

    private func startPTYSession() async throws {
        let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
            term: "xterm-256color",
            terminalCharacterWidth: 40,
            terminalRowHeight: 24,
            terminalModes: .init([.ECHO: 1, .ISIG: 1, .ICANON: 1, .OPOST: 1])
        )

        Task {
            try await client.withPTY(ptyRequest) { ttyOutput, ttyStdinWriter in
                self.ptyStdinWriter = ttyStdinWriter

                for try await output in ttyOutput {
                    switch output {
                    case .stdout(let buffer):
                        delegate?.didReceiveOutput(Data(buffer: buffer))
                    case .stderr(let buffer):
                        delegate?.didReceiveOutput(Data(buffer: buffer))
                    }
                }
            }
        }
    }
}
```

### Authentication Methods

**Currently Supported:**
```swift
.passwordBased(username: "user", password: "")  // Empty password for now
```

**Planned:**
```swift
// SSH key authentication (requires Citadel key parsing)
.rsa(username: "user", privateKey: privateKey)
```

### Terminal I/O Flow

```
User Input (Toolbar)
    ↓
iOSTerminalManager.sendText()
    ↓
SSHClientManager.sendText()
    ↓
ptyStdinWriter.write(buffer)
    ↓
[SSH Connection]
    ↓
Server executes command
    ↓
[SSH Connection]
    ↓
ttyOutput stream
    ↓
SSHClientDelegate.didReceiveOutput()
    ↓
iOSTerminalManager.didReceiveOutput()
    ↓
terminalView.feed(byteArray:)
    ↓
Terminal Display
```

### Connection Lifecycle

1. **Connection Initiated:**
   - User taps "Connect" on saved connection
   - `SSHClientManager.connect()` called
   - Display "Connecting..." message

2. **Authentication:**
   - Create `SSHClientSettings` with auth method
   - `SSHClient.connect(to: settings)` establishes connection
   - Host key validated (currently `.acceptAnything()`)

3. **PTY Session:**
   - Create PTY request with terminal dimensions
   - `client.withPTY()` opens pseudo-terminal
   - Background Task reads output stream continuously

4. **Connected State:**
   - Delegate receives `didConnect()`
   - Terminal displays "Connected!" message
   - User can execute commands

5. **Disconnection:**
   - User taps "Disconnect" button
   - `client.close()` terminates connection
   - Delegate receives `didDisconnect()`
   - Navigation pops back to connections list

### Error Handling

```swift
enum SSHClientError: LocalizedError {
    case notConnected
    case invalidKeyPath
    case unsupportedKeyFormat
    case authenticationFailed

    var errorDescription: String? {
        // User-friendly error messages
    }
}
```

**Connection errors** are caught and displayed in console (UI indicators planned).

### Security Considerations

**Current Implementation:**
- `.acceptAnything()` host key validator (INSECURE - for development only)
- ✅ Secure password storage in iOS Keychain via shared KeychainManager
- ✅ Passwords excluded from Codable (never persisted to disk)
- ✅ Keychain key format: `ssh_password_{connection.id.uuidString}`
- ✅ Automatic password cleanup on connection deletion

**Production Requirements:**
- Implement proper host key validation
- Support SSH key authentication with proper key management
- Consider adding host key fingerprint verification UI

### Terminal Resize Limitation

**Issue**: Citadel 0.11.1 doesn't expose API to send `WindowChangeRequest` to SSH server

**Technical Background**:

SSH protocol requires sending a window-change message when terminal dimensions change:
```swift
// What we NEED to send (but can't with Citadel):
channel.triggerUserOutboundEvent(
    SSHChannelRequestEvent.WindowChangeRequest(
        terminalCharacterWidth: cols,
        terminalRowHeight: rows,
        terminalPixelWidth: 0,
        terminalPixelHeight: 0
    ),
    promise: nil
)
```

**Citadel Limitation**:
- `withPTY` API only exposes:
  - `ttyOutput: AsyncSequence<TTYOutput>` - for reading
  - `ttyStdinWriter: TTYStdinWriter` - for writing
- Does NOT expose underlying NIO `Channel` needed for `triggerUserOutboundEvent()`

**Impact on UX**:
- ✅ **Initial connection**: **Perfect** - uses actual GeometryReader dimensions via onGeometryChange
  - Waits for layout to complete before connecting
  - Calculates precise cols/rows from real view size
  - Remote apps start with exact dimensions (e.g., 85×45 for iPhone)
- ✅ **Local terminal**: SwiftTerm resizes correctly, recalculates cols/rows
- ✅ **Font scaling**: Pinch-to-zoom updates terminal locally (10-24pt range)
- ❌ **Dynamic resize**: Remote apps don't receive SIGWINCH on rotation/Split View
- ❌ **Practical impact**:
  - vim: Editor width doesn't adapt to new terminal size after rotation
  - tmux: Panes stay at original dimensions after Split View changes
  - htop: Display doesn't reflow on device orientation change
  - Shell: Line wrapping breaks when terminal shrinks dynamically

**Current Mitigation**:
1. **Precise initial dimensions** (✅ Implemented iOS 26 pattern):
   ```swift
   // Wait for layout completion using onGeometryChange (iOS 18+)
   .onGeometryChange(for: CGSize.self) { proxy in
       proxy.size
   } action: { newSize in
       // Connect only after terminal is sized with actual dimensions
       Task { await performSSHConnection() }
   }
   ```
2. **User workaround**: Reconnect after device rotation/Split View changes
3. **Console hints**: Print helpful messages when resize is detected locally

**Future Solutions**:
- **Option 1**: Monitor Citadel updates
  - Watch https://github.com/orlandos-nl/Citadel for WindowChangeRequest support
  - Low effort, depends on upstream
- **Option 2**: Switch to raw NIOSSH
  - Direct access to `Channel.triggerUserOutboundEvent()`
  - High effort, full SSH layer rewrite
  - Loses Citadel convenience APIs
- **Option 3**: Fork Citadel
  - Patch to expose channel or add resize API
  - Not sustainable for long-term maintenance
