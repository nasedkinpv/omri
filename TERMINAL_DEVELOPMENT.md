# Terminal Development Progress

## ✅ Phase 1 Complete: Terminal UI Foundation

**Branch:** `feature/ssh-terminal`
**Commit:** `f5b91ca - feat: terminal settings tab with ssh connection ui`
**Build Status:** ✅ Compiles successfully

### What's Been Built

#### 1. Terminal Tab in Settings Window
- Added new "Terminal" tab between "AI Polish" and "General"
- Icon: `terminal.fill`
- Description: "SSH connections and remote terminal access"
- **This exact UI will become the iPad interface**

#### 2. SSH Connection Management
**Files:**
- `Dictly/Terminal/Models/SSHConnection.swift` - Connection profile data model
- `Dictly/Terminal/Models/TerminalSettings.swift` - Settings storage with UserDefaults
- `Dictly/Terminal/Views/TerminalSettingsTab.swift` - Complete SwiftUI form

**Features:**
- Saved connections list (stored in UserDefaults)
- New connection form:
  - Host, username, port fields
  - Authentication method picker (password/SSH key)
  - SSH key file picker (reads from `~/.ssh/`)
  - Save connection button
  - Quick connect button
- Terminal settings:
  - Font size slider (10-20pt)
  - Color scheme picker

#### 3. Terminal Window Controller
**Files:**
- `Dictly/Terminal/Controllers/TerminalWindowController.swift`
- `Dictly/Terminal/Views/TerminalWindowView.swift`

**Status:** Placeholder implementation with:
- NSWindow management (900x600, resizable)
- Connection info display
- Dictation button UI
- Commented-out SwiftTerm integration code (ready to uncomment)

### Architecture Preview

```
Settings Window → Terminal Tab → [Connect] Button
                                       ↓
                              Opens Terminal Window
                              (Separate NSWindow)
                                       ↓
                              LocalProcessTerminalView
                              (SwiftTerm - pending)
                                       ↓
                              Spawns: ssh user@host
```

---

## 🔄 Phase 2: SwiftTerm Integration (Next)

### Prerequisites

**1. Add SwiftTerm Dependency**

In Xcode:
1. Open `Dictly.xcodeproj`
2. Select project in sidebar
3. Go to "Package Dependencies" tab
4. Click "+" button
5. Enter: `https://github.com/migueldeicaza/SwiftTerm`
6. Version: Up to Next Major - `1.0.0`
7. Click "Add Package"
8. Add to target "Dictly"

**2. Remove Sandbox Entitlement**

`LocalProcessTerminalView` requires ability to spawn processes.

Edit `Dictly.entitlements`:
```xml
<!-- REMOVE THIS LINE: -->
<key>com.apple.security.app-sandbox</key>
<true/>

<!-- App will still be secure with hardened runtime -->
```

### Implementation Steps

#### Step 1: Uncomment SwiftTerm Code

**In `TerminalWindowController.swift`:**
```swift
// Uncomment line 6:
import SwiftTerm

// Uncomment lines 33-54 (the LocalProcessTerminalView implementation)
```

**In `TerminalWindowView.swift`:**
```swift
// Uncomment line 6:
import SwiftTerm

// Uncomment lines 51-59 (TerminalViewRepresentable)

// Replace placeholder Color.black view with:
TerminalViewRepresentable(terminalView: terminalView)
```

#### Step 2: Test SSH Connection

```swift
// In TerminalWindowController.connect(to:)
let terminalView = LocalProcessTerminalView(frame: .zero)
let (executable, args) = connection.sshCommand
terminalView.startProcess(
    executable: executable,
    args: args
)
// Terminal will spawn ssh process and connect!
```

#### Step 3: Verify Functionality

1. Build and run app
2. Open Settings → Terminal tab
3. Add connection:
   - Host: `example.com`
   - User: `your-username`
   - Port: `22`
4. Click "Connect"
5. Terminal window should open with live SSH session

---

## 🎤 Phase 3: Dictation Integration (After Phase 2)

### Detection Strategy

**Modify `AudioManager.swift`:**
```swift
// After transcription completes
if TerminalWindowController.shared.isTerminalActive {
    // Send to terminal
    TerminalWindowController.shared.sendText(transcribedText)
} else {
    // Existing behavior: paste to frontmost app
    pasteManager.processAndPasteText(transcribedText)
}
```

### Terminal Text Injection

**In `TerminalWindowController.swift`:**
```swift
func sendText(_ text: String) {
    terminalView?.send(txt: text)
    // Text appears at cursor in terminal
}
```

### User Experience

1. User opens terminal, connects to SSH
2. User presses `fn` key to dictate
3. Speech recognized and sent directly to terminal
4. Text appears as if typed

---

## 📱 iPad Migration Path (Future)

### What's Already Cross-Platform (70%)

✅ **Works on iOS as-is:**
- `TerminalSettingsTab.swift` - Pure SwiftUI
- `SSHConnection.swift` - Foundation only
- `TerminalSettings.swift` - UserDefaults
- All dictation code (AudioManager, VAD, Services)

### What Needs iOS Adaptation (30%)

**Replace:**
- `LocalProcessTerminalView` (macOS) → `TerminalView` (iOS)
- System `ssh` command → SwiftNIO SSH library
- `NSWindowController` → SwiftUI NavigationStack

**iPad UI Flow:**
```
Settings Sheet (TerminalSettingsTab - reused)
        ↓
    [Connect]
        ↓
Full-Screen Terminal View (SwiftTerm iOS)
        ↓
SwiftNIO SSH Connection
        ↓
Dictation Button → AudioManager (reused)
```

---

## 🚀 Development Workflow

### Running the App

```bash
# Build
xcodebuild -project Dictly.xcodeproj -scheme Dictly -configuration Debug build

# Or in Xcode
⌘R
```

### Testing Terminal Tab

1. Open app (menu bar icon)
2. Click Settings
3. Navigate to "Terminal" tab (3rd tab)
4. See complete SSH connection UI
5. Try saving a connection

### Branch Management

```bash
# Currently on:
git branch
# * feature/ssh-terminal

# Continue development:
git add .
git commit -m "feat: integrate swiftterm"

# When ready to merge:
git checkout main
git merge feature/ssh-terminal
```

---

## 📊 Progress Tracking

- [x] Phase 1: Terminal UI Foundation (✅ Complete - 726 lines)
- [ ] Phase 2: SwiftTerm Integration (Next - ~2-3 days)
  - [ ] Add SwiftTerm dependency
  - [ ] Remove sandbox entitlement
  - [ ] Uncomment integration code
  - [ ] Test SSH connections
- [ ] Phase 3: Dictation Integration (~1-2 days)
  - [ ] Detect terminal window focus
  - [ ] Route transcribed text to terminal
  - [ ] Add visual feedback
- [ ] Phase 4: Polish (~1-2 days)
  - [ ] Multiple terminal windows/tabs
  - [ ] Session persistence
  - [ ] Theme support
  - [ ] Keyboard shortcuts

**Estimated Total:** 2-3 weeks to production-ready SSH terminal with dictation

---

## 🎯 Next Immediate Action

**To continue development:**

1. **In Xcode:** Add SwiftTerm package dependency
2. **Edit `Dictly.entitlements`:** Remove sandbox (required for Process spawning)
3. **Uncomment code** in TerminalWindowController.swift and TerminalWindowView.swift
4. **Build and test** SSH connection

The foundation is solid. Terminal UI is complete and ready for SwiftTerm integration!
