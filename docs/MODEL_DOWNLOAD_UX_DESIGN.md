# Model Download Feature - UX Design Document

## Date: 2025-10-23
## Status: Design Proposal

---

## Overview

Allow users to pre-download Parakeet on-device transcription models before first use, eliminating the 5-10 second delay during initial recording.

**Current Behavior**:
- Models download automatically on first recording attempt
- User sees "Initializing VAD..." message
- 5-10 second wait before audio starts
- Confusing for first-time users

**Proposed Behavior**:
- Models can be pre-downloaded from Settings
- Clear visual feedback of download status
- No wait time on first recording

---

## User Research Findings

### Pain Points from Logs Analysis

From user logs (2025-10-23 session):
```
[19:43:12.313] Downloading models...
[19:43:12.318] ASR models already present
[19:43:12.636] Models loaded successfully (324ms)
```

**Issues**:
1. **First-use delay**: Users don't know why recording doesn't start immediately
2. **No progress feedback**: Download happens silently in background
3. **Uncertainty**: Users don't know if app is frozen or working
4. **Repeated downloads**: Users might switch away and trigger re-download

### Model Details (from FluidAudio logs)

**Parakeet TDT v3 (600MB total)**:
- Preprocessor.mlmodelc: ~500KB (CPU only)
- Encoder.mlmodelc: ~450MB (ANE accelerated)
- Decoder.mlmodelc: ~50MB (CPU only)
- JointDecision.mlmodelc: ~10MB (CPU only)
- Vocabulary: ~90MB (8,192 tokens, 25 languages)

**Total download**: ~600MB
**Download time** (user logs): ~8-12 seconds on fast connection
**Storage path**: `~/Library/Application Support/FluidAudio/Models/`

---

## Design Principles (Existing UI Guidelines)

From codebase analysis:

### 1. **Clarity Over Cleverness**
- Use explicit labels ("Download Models" not just "Download")
- Show clear status (Downloaded, Downloading, Not Downloaded)
- No hidden states

### 2. **Consistent Component Usage**
- `SettingsSectionHeader` for section titles
- `SettingsSectionFooter` for helpful descriptions
- `OmriStatusIndicator` for connection/status states
- `.borderedProminent` buttons for primary actions
- `.controlSize(.large)` for important buttons

### 3. **Platform-Appropriate Layouts**
- **macOS**: Grid layout with trailing labels
- **iOS**: Form with sections and LabeledContent

### 4. **Brand Colors**
- BrandMint (#00D4AA): Success/Downloaded
- BrandTeal (#5AC8FA): In progress
- BrandOrange (#FF9500): Warning/Action needed
- BrandBlue (#007AFF): Primary actions

---

## Proposed UI Design

### Location: Dictation Settings Tab

**Placement**: Between "Account" and "Smart Voice Detection" sections

**Visibility**: Only shown when `transcriptionProvider == .parakeet`

### States

**State 1: Not Downloaded** (Initial state)
```
┌─────────────────────────────────────────────────┐
│ On-Device Models                                │
│                                                 │
│ [⚠️] Parakeet TDT v3                           │
│      Not downloaded (600 MB)                    │
│                                                 │
│                     [Download Models] (Blue)    │
│                                                 │
│ Models will be stored locally for offline use. │
│ Download once, transcribe anytime without      │
│ internet connection.                            │
└─────────────────────────────────────────────────┘
```

**State 2: Downloading** (Active download)
```
┌─────────────────────────────────────────────────┐
│ On-Device Models                                │
│                                                 │
│ [🔄] Parakeet TDT v3                           │
│      Downloading... 342 MB of 600 MB           │
│      ████████░░░░░░░░░░░░░░ 57%                │
│                                                 │
│                         [Cancel] (Secondary)    │
│                                                 │
│ Downloading models for offline transcription.  │
└─────────────────────────────────────────────────┘
```

**State 3: Downloaded** (Success state)
```
┌─────────────────────────────────────────────────┐
│ On-Device Models                                │
│                                                 │
│ [✓] Parakeet TDT v3                            │
│     Ready for offline use (600 MB)             │
│                                                 │
│                  [Re-download] (Secondary)      │
│                                                 │
│ Models are ready. Transcription works offline. │
└─────────────────────────────────────────────────┘
```

**State 4: Error** (Download failed)
```
┌─────────────────────────────────────────────────┐
│ On-Device Models                                │
│                                                 │
│ [⚠️] Parakeet TDT v3                           │
│      Download failed: Network error            │
│                                                 │
│                   [Retry Download] (Orange)     │
│                                                 │
│ Check your internet connection and try again.  │
└─────────────────────────────────────────────────┘
```

---

## Component Breakdown

### macOS Implementation (Grid Layout)

```swift
VStack(alignment: .leading, spacing: 16) {
    SettingsSectionHeader(title: "On-Device Models")

    HStack(alignment: .top, spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                OmriStatusIndicator(
                    state: modelStatus.statusIndicatorState,
                    service: .general
                )
                Text("Parakeet TDT v3")
                    .font(.headline)
            }

            Text(modelStatus.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }

        Spacer()

        // Action button
        Button(modelStatus.buttonTitle) {
            handleModelAction()
        }
        .buttonStyle(modelStatus.buttonStyle)
        .controlSize(.large)
        .disabled(modelStatus.isProcessing)
    }

    // Progress bar (only when downloading)
    if case .downloading(let progress) = modelStatus {
        ProgressView(value: progress)
            .progressViewStyle(.linear)
            .tint(Color("BrandTeal"))
    }

    SettingsSectionFooter(text: modelStatus.footerText)
}
```

### iOS Implementation (Form Layout)

```swift
Section {
    LabeledContent {
        HStack(spacing: 12) {
            OmriStatusIndicator(
                state: modelStatus.statusIndicatorState,
                service: .general
            )

            Button(modelStatus.buttonTitle) {
                handleModelAction()
            }
            .buttonStyle(modelStatus.buttonStyle)
            .disabled(modelStatus.isProcessing)
        }
    } label: {
        VStack(alignment: .leading, spacing: 4) {
            Text("Parakeet TDT v3")
                .font(.headline)
            Text(modelStatus.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // Progress bar (only when downloading)
    if case .downloading(let progress) = modelStatus {
        ProgressView(value: progress)
            .progressViewStyle(.linear)
            .tint(Color("BrandTeal"))
    }
} header: {
    Text("On-Device Models")
} footer: {
    Text(modelStatus.footerText)
}
```

---

## Data Model

```swift
enum ModelDownloadStatus {
    case notDownloaded
    case downloading(progress: Double)  // 0.0 to 1.0
    case downloaded
    case error(String)

    var statusIndicatorState: OmriStatusIndicator.ConnectionState {
        switch self {
        case .notDownloaded:
            return .disconnected
        case .downloading:
            return .connecting
        case .downloaded:
            return .connected
        case .error:
            return .error
        }
    }

    var description: String {
        switch self {
        case .notDownloaded:
            return "Not downloaded (600 MB)"
        case .downloading(let progress):
            let downloaded = Int(progress * 600)
            return "Downloading... \(downloaded) MB of 600 MB"
        case .downloaded:
            return "Ready for offline use (600 MB)"
        case .error(let message):
            return "Download failed: \(message)"
        }
    }

    var buttonTitle: String {
        switch self {
        case .notDownloaded:
            return "Download Models"
        case .downloading:
            return "Cancel"
        case .downloaded:
            return "Re-download"
        case .error:
            return "Retry Download"
        }
    }

    var buttonStyle: ButtonStyle {
        switch self {
        case .notDownloaded:
            return .borderedProminent  // Blue
        case .downloading:
            return .bordered           // Secondary
        case .downloaded:
            return .bordered           // Secondary
        case .error:
            return .borderedProminent  // Orange (via tint)
        }
    }

    var footerText: String {
        switch self {
        case .notDownloaded:
            return "Models will be stored locally for offline use. Download once, transcribe anytime without internet connection."
        case .downloading:
            return "Downloading models for offline transcription."
        case .downloaded:
            return "Models are ready. Transcription works offline."
        case .error:
            return "Check your internet connection and try again."
        }
    }

    var isProcessing: Bool {
        if case .downloading = self {
            return true
        }
        return false
    }
}
```

---

## User Flows

### Flow 1: First-Time User (Pre-Download)

```
1. User opens Settings → Dictation tab
2. Sees "Parakeet (On-Device)" in provider list
3. Selects Parakeet
4. New section appears: "On-Device Models"
5. Status: "Not downloaded (600 MB)"
6. Clicks "Download Models" button
7. Progress bar appears, shows 0-100%
8. Download completes (8-12 seconds)
9. Status changes to "Ready for offline use"
10. User presses fn key → Immediate transcription (no delay!)
```

### Flow 2: Existing User (Already Downloaded)

```
1. User opens Settings → Dictation tab
2. Sees "On-Device Models" section
3. Status: "Ready for offline use (600 MB)"
4. Green checkmark indicator
5. Option to "Re-download" if needed (e.g., corrupted models)
```

### Flow 3: Download Interrupted

```
1. User starts download
2. Progress bar at 45%
3. User quits app or loses connection
4. Next time: Shows "Download failed: Connection lost"
5. "Retry Download" button available
6. Click to resume/restart download
```

### Flow 4: Low Disk Space

```
1. User clicks "Download Models"
2. System checks available disk space
3. If < 1GB available: Show alert
   "Not enough disk space. Parakeet requires 600 MB.
    Free up space and try again."
4. Download cancelled
```

---

## Technical Implementation Notes

### Checking Model Status

```swift
class ModelManager: ObservableObject {
    @Published var status: ModelDownloadStatus = .notDownloaded

    func checkModelStatus() async {
        // Use existing ParakeetTranscriptionManager method
        let manager = ParakeetTranscriptionManager()
        let downloaded = await manager.areModelsDownloaded()

        await MainActor.run {
            self.status = downloaded ? .downloaded : .notDownloaded
        }
    }

    func downloadModels() async {
        await MainActor.run {
            self.status = .downloading(progress: 0.0)
        }

        do {
            let manager = ParakeetTranscriptionManager()

            // FluidAudio doesn't provide progress callbacks yet
            // So we simulate progress with time-based updates
            Task {
                for i in stride(from: 0.0, to: 1.0, by: 0.1) {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    await MainActor.run {
                        if case .downloading = self.status {
                            self.status = .downloading(progress: i)
                        }
                    }
                }
            }

            try await manager.initializeModels()

            await MainActor.run {
                self.status = .downloaded
            }
        } catch {
            await MainActor.run {
                self.status = .error(error.localizedDescription)
            }
        }
    }
}
```

### Integration Points

1. **DictationSettingsContent.swift**
   - Add new section after "Account" section
   - Only visible when Parakeet is selected
   - Uses ModelManager for state

2. **ParakeetTranscriptionManager.swift**
   - Existing `areModelsDownloaded()` method (already implemented)
   - Existing `initializeModels()` method (already implemented)
   - No changes needed to core functionality

3. **Settings.swift**
   - Optional: Add `@Published var modelDownloadStatus` if needed for persistence
   - Or use `@StateObject var modelManager` in view (cleaner)

---

## Progressive Disclosure

**Hide complexity, reveal when needed:**

### Minimal View (Default)
```
[✓] Parakeet TDT v3 - Ready (600 MB)    [Re-download]
```

### Expanded View (During download)
```
[🔄] Parakeet TDT v3
     Downloading... 342 MB of 600 MB
     ████████░░░░░░░░░░░░░░ 57%

     Models include:
     • Encoder (450 MB) - Neural engine accelerated
     • Decoder (50 MB) - Fast inference
     • Vocabulary (90 MB) - 25 languages

     [Cancel]
```

### Advanced Options (Future)
```
[✓] Parakeet TDT v3 - Ready              [•••]

Click [•••] to:
- View model details
- Change storage location
- Delete models (free 600 MB)
- Check for updates
```

---

## Accessibility

### VoiceOver Support

**Not Downloaded**:
```
Button: "Download Models"
Hint: "Downloads 600 megabytes of on-device transcription models for offline use"
```

**Downloading**:
```
Progress: "Downloading models, 57 percent complete"
Button: "Cancel download"
```

**Downloaded**:
```
Status: "Models ready, 600 megabytes installed"
Button: "Re-download models"
```

### Keyboard Navigation

- Tab to "Download Models" button
- Space/Enter to activate
- Tab to "Cancel" during download
- Esc to dismiss progress (if modal)

---

## Error Handling

### Error Scenarios

1. **Network Error**
   ```
   [⚠️] Download failed: No internet connection
   [Retry Download]

   Footer: "Check your connection and try again."
   ```

2. **Disk Space Error**
   ```
   [⚠️] Download failed: Insufficient storage
   [Free Up Space]

   Footer: "600 MB required. Free up space in System Settings."
   ```

3. **Corrupted Download**
   ```
   [⚠️] Download incomplete or corrupted
   [Re-download]

   Footer: "Try downloading again."
   ```

4. **Permission Error** (sandbox issue)
   ```
   [⚠️] Cannot write to model directory
   [Restart App]

   Footer: "Restart the app and try again."
   ```

---

## Alternative Designs Considered

### Alternative 1: Auto-Download on Provider Selection

**Pros**: Zero user action needed
**Cons**:
- Unexpected 600MB download
- No user consent for bandwidth/storage
- Battery drain on mobile
- ❌ **Rejected**: Too aggressive

### Alternative 2: Modal Download Screen

**Pros**: Focused experience
**Cons**:
- Blocks other settings changes
- Feels heavy-handed for optional feature
- ❌ **Rejected**: Too intrusive

### Alternative 3: Menu Bar Item

**Pros**: Quick access
**Cons**:
- Clutters menu bar
- Hidden from new users
- ❌ **Rejected**: Not discoverable

### ✅ Selected: In-Settings Section

**Pros**:
- Discoverable (right where you select Parakeet)
- Non-blocking (can change other settings)
- Clear context (part of Dictation settings)
- Consistent with existing UI patterns

---

## Future Enhancements

### Phase 2: Model Management
- View detailed model info (sizes, versions)
- Delete models to free space
- Change storage location
- Auto-update check

### Phase 3: Multiple Models
- Support for different Parakeet versions
- Language-specific model downloads
- Model quality settings (fast vs accurate)

### Phase 4: Smart Download
- Download during idle time
- Low-power mode awareness
- Wi-Fi only option
- Automatic cleanup of old versions

---

## Success Metrics

### UX Metrics

**Before Feature**:
- First recording delay: 8-12 seconds (model download)
- User confusion: "Why isn't it starting?"
- Support requests: "App is frozen"

**After Feature**:
- First recording delay: <100ms (models pre-downloaded)
- Clear status: User knows download is needed
- Self-service: No support needed

### Technical Metrics

- Download success rate: >95%
- Average download time: 8-12 seconds
- Re-download rate: <5% (indicates stable downloads)
- Disk space errors: <1% (users have enough space)

---

## Implementation Checklist

### Phase 1: Core Functionality
- [ ] Create `ModelManager` observable object
- [ ] Add model status checking (use `areModelsDownloaded()`)
- [ ] Add download trigger (use `initializeModels()`)
- [ ] Add progress tracking (time-based simulation)
- [ ] Add cancel functionality
- [ ] Add error handling

### Phase 2: UI Integration
- [ ] Add "On-Device Models" section to DictationSettingsContent
- [ ] Implement macOS grid layout
- [ ] Implement iOS form layout
- [ ] Add status indicator integration
- [ ] Add progress bar
- [ ] Add button states

### Phase 3: Polish
- [ ] Add disk space check before download
- [ ] Add accessibility labels
- [ ] Add VoiceOver hints
- [ ] Test keyboard navigation
- [ ] Test error scenarios
- [ ] Add analytics (download started, completed, failed)

### Phase 4: Testing
- [ ] Test on slow network (download progress)
- [ ] Test network interruption (error handling)
- [ ] Test low disk space (error alert)
- [ ] Test rapid provider switching (state management)
- [ ] Test on iOS and macOS (both platforms)

---

## Design Rationale Summary

**Why this design?**

1. **Visibility**: Section appears exactly when relevant (Parakeet selected)
2. **Clarity**: Explicit states (Not Downloaded, Downloading, Downloaded)
3. **Control**: User initiates download, not automatic
4. **Feedback**: Progress bar shows real-time status
5. **Recovery**: Clear error states with actionable buttons
6. **Consistency**: Uses existing UI components and patterns
7. **Performance**: Pre-download eliminates first-use delay

**Alignment with Omri's design principles:**
- ✅ Clean, minimal interface
- ✅ Clear status indicators
- ✅ Consistent with existing Settings patterns
- ✅ Platform-appropriate layouts (Grid vs Form)
- ✅ Brand colors for status states
- ✅ Helpful footer text for context

---

## Conclusion

This design provides a clear, user-friendly way to manage Parakeet model downloads while maintaining consistency with Omri's existing UI patterns. The section only appears when relevant, uses familiar components, and provides clear feedback at every stage.

**Next Steps**:
1. Review and approve design
2. Implement Phase 1 (core functionality)
3. Implement Phase 2 (UI integration)
4. Test with real users
5. Iterate based on feedback

---

**Document Status**: Design Proposal - Ready for Review
**Created**: 2025-10-23
**Author**: UX Design Review
