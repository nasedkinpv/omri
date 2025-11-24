# Model Download System - Complete Logic Flow Analysis

## Overview
The model download system allows users to pre-download on-device transcription models (currently Parakeet) from the Settings → General → Storage section.

---

## Component Architecture

### Core Components
1. **ModelDownloadManager** (`Shared/Models/ModelDownloadManager.swift`)
   - `@Observable @MainActor` singleton
   - Manages download state for all models
   - Coordinates between UI and model implementations

2. **DownloadableModel Protocol**
   - Abstract interface for any downloadable model
   - Methods: `isDownloaded()`, `download()`

3. **ParakeetModel** (implements DownloadableModel)
   - Concrete implementation for Parakeet TDT v3
   - Delegates to ParakeetTranscriptionManager

4. **UI** (`GeneralSettingsContent.swift`)
   - Shows model list with status and download buttons
   - Reactive to state changes via @Observable

---

## State Machine

```
┌─────────────────┐
│ .notDownloaded  │──────────────────────────────┐
└────────┬────────┘                              │
         │ User clicks "Download"                │
         ↓                                       │
┌─────────────────┐                              │
│  .downloading   │                              │
└────────┬────────┘                              │
         │                                       │
         ├──→ Success ──→ ┌──────────────┐      │
         │                │ .downloaded  │      │
         │                └──────────────┘      │
         │                                       │
         └──→ Failure ──→ ┌──────────────┐      │
                          │   .error     │──────┘
                          └──────────────┘
                          User clicks "Clear & Retry"
```

### State Transitions
- `.notDownloaded` → `.downloading` (user clicks Download)
- `.downloading` → `.downloaded` (download succeeds)
- `.downloading` → `.error(String)` (download fails)
- `.error` → `.notDownloaded` (user clicks Clear & Retry, clears files)
- `.downloaded` → `.notDownloaded` (user clears all models)

---

## Complete Flow Diagrams

### 1. App Launch Flow
```
App Launch
    ↓
ModelDownloadManager.shared created
    ↓
init() called
    ↓
registerModels() - adds ParakeetModel to availableModels
    ↓
NO automatic status check (prevents auto-download)
    ↓
modelStates = [:] (empty)
modelProgress = [:] (empty)
```

**Key Point**: NO automatic work happens on app launch ✓

---

### 2. User Opens General Tab Flow
```
User opens Settings → General
    ↓
GeneralSettingsContent renders
    ↓
onDeviceModelsSection VStack shown
    ↓
.onAppear { Task { await manager.checkAllModelsStatus() } }
    ↓
For each model in availableModels:
    ├─→ Check model.isAvailable (platform check)
    │   └─→ If false: modelStates[id] = .error("Not available")
    │
    └─→ If modelStates[id] == nil or .notDownloaded:
        └─→ await model.isDownloaded()
            ├─→ FileManager checks: config.json exists?
            │   ├─→ YES: modelStates[id] = .downloaded
            │   └─→ NO:  modelStates[id] = .notDownloaded
            └─→ @Observable triggers UI update
```

**Key Point**: Only checks file existence, NO download triggered ✓

**ParakeetModel.isDownloaded() Implementation**:
```swift
// Checks file system WITHOUT triggering download
let configPath = "/Library/Application Support/FluidAudio/Models/
                  parakeet-tdt-0.6b-v3-coreml/config.json"
return fileManager.fileExists(atPath: configPath)
```

---

### 3. User Clicks Download Flow
```
User clicks "Download" button
    ↓
Task { await manager.downloadModel(model.id) }
    ↓
downloadModel(modelId):
    ├─→ Guard: model exists? (✓)
    ├─→ Guard: already .downloading? → return (prevents concurrent) ✓
    ├─→ Guard: already .downloaded? → return (prevents re-download) ✓
    ↓
    modelStates[id] = .downloading
    modelProgress[id] = 0.0
    @Observable → UI updates (shows progress bar + "Downloading...")
    ↓
    await model.download()  // ParakeetModel.download()
        ↓
        let manager = ParakeetTranscriptionManager()
        try await manager.initializeModels()
            ↓
            FluidAudio: AsrModels.downloadAndLoad()
                ├─→ Downloads Decoder.mlmodelc (22.5 MB)
                ├─→ Downloads Encoder.mlmodelc (424.6 MB)
                ├─→ Downloads JointDecision.mlmodelc (12.1 MB)
                ├─→ Downloads Preprocessor.mlmodelc (480 KB)
                └─→ Downloads config files
            ↓
            ├─→ SUCCESS:
            │   modelProgress[id] = 1.0
            │   modelStates[id] = .downloaded
            │   @Observable → UI updates (shows "Ready")
            │
            └─→ FAILURE (catch error):
                let message = parseDownloadError(error)
                modelStates[id] = .error(message)
                @Observable → UI updates (shows error + "Clear & Retry")
```

**Download Guards**:
1. ✓ Model exists in availableModels
2. ✓ Not already downloading (prevents concurrent downloads)
3. ✓ Not already downloaded (prevents re-download)

---

### 4. Download Error Flow
```
Download fails (network, disk space, file corruption)
    ↓
parseDownloadError(error) analyzes error string:
    ├─→ "couldn't be moved" → "Download incomplete. Try clearing models and retry."
    ├─→ "couldn't be opened" → "Download incomplete. Try clearing models and retry."
    ├─→ "no such file" → "Download failed. Clear models and retry."
    ├─→ "network/internet" → "Network error. Check connection and retry."
    ├─→ "space/disk" → "Not enough disk space (~600MB needed)"
    └─→ default → "Download failed. Clear models and retry."
    ↓
modelStates[id] = .error(message)
    ↓
UI shows:
    - Red error icon
    - Error message
    - "Clear & Retry" button (borderedProminent)
```

---

### 5. Clear & Retry Flow
```
User clicks "Clear & Retry" (from error state)
    ↓
Task {
    manager.clearModel(model.id)
        ↓
        Remove directory: FluidAudio/Models/parakeet-tdt-0.6b-v3-coreml/
        (Best effort - ignores errors)
        ↓
        resetModel(id)
            modelStates[id] = .notDownloaded
            modelProgress[id] = 0.0
    ↓
    await manager.downloadModel(model.id)
    (Downloads fresh copy - see Download Flow above)
}
```

---

### 6. Clear All Models Flow
```
User clicks "Clear All Models..." button
    ↓
Alert: "Clear Downloaded Models?" shown
    ↓
User confirms
    ↓
clearDownloadedModels()
    ↓
    Remove entire directory: FluidAudio/Models/
    ↓
    Task { await manager.checkAllModelsStatus() }
        ↓
        For each model:
            await model.isDownloaded()
            (config.json no longer exists)
            modelStates[id] = .notDownloaded
        ↓
        @Observable → UI updates (shows "Download" button)
```

**Button Visibility Logic**:
```swift
// Button only shown if at least one model is .downloaded
if manager.availableModels.contains(where: {
    manager.state(for: $0.id) == .downloaded
}) {
    // Show "Clear All Models..." button
}
```

With current single-model setup:
- `.notDownloaded` → Button hidden ✓
- `.downloading` → Button hidden ✓ (can't clear mid-download)
- `.downloaded` → Button shown ✓
- `.error` → Button hidden (use "Clear & Retry" instead)

---

## UI Reactivity Analysis

### How @Observable Updates Work

1. **State Change**:
```swift
// In ModelDownloadManager
modelStates[modelId] = .downloading  // Mutation tracked by @Observable
```

2. **View Access**:
```swift
// In GeneralSettingsContent
let state = manager.state(for: model.id)
    ↓
// Internally calls:
return modelStates[modelId] ?? .notDownloaded
```

3. **SwiftUI Observation**:
- @Observable macro tracks property access
- When `modelStates` dictionary is accessed via `state(for:)`
- SwiftUI registers dependency on that property
- When `modelStates` is mutated, SwiftUI invalidates view
- View body re-executes, recomputing `state`

### Critical Question: Does this work with dictionaries?

**Answer**: YES ✓

The @Observable macro tracks access to the `modelStates` property itself. Any mutation to the dictionary (even changing a value at a key) triggers property observers. SwiftUI will re-render views that accessed this property.

**However**, there's a subtle issue in our current implementation...

### 🚨 ISSUE FOUND: UI Reactivity Problem

Current code:
```swift
ForEach(manager.availableModels, id: \.id) { model in
    let state = manager.state(for: model.id)
    // ... use state in UI
}
```

**Problem**: `let state` is computed once per render and becomes a local constant. While @Observable should trigger re-renders when modelStates changes, we're relying on implicit observation.

**Better Pattern**:
```swift
ForEach(manager.availableModels, id: \.id) { model in
    // Access manager.state(for:) directly in child views
    // This makes observation more explicit
    modelRow(for: model, state: manager.state(for: model.id))
}
```

Or even better - use a computed property:
```swift
// In ModelDownloadManager
func stateBinding(for modelId: String) -> Binding<ModelDownloadState> {
    Binding(
        get: { self.modelStates[modelId] ?? .notDownloaded },
        set: { self.modelStates[modelId] = $0 }
    )
}
```

**Actually**, re-reading the @Observable documentation, the current implementation should work because:
1. View body executes
2. Accesses `manager.state(for:)` which reads `modelStates`
3. @Observable tracks this access
4. When `modelStates` changes, view is invalidated
5. View body re-executes, `let state` is recomputed with new value

The local `let` is fine because it's recomputed on each render.

---

## Edge Cases Analysis

### Edge Case 1: App Quit During Download
**Scenario**: User starts download, quits app mid-download

**What Happens**:
- Partial model files exist in FluidAudio/Models/
- On next launch: `isDownloaded()` checks for config.json
- If config.json wasn't downloaded yet → returns false → state = .notDownloaded
- User clicks Download → FluidAudio may fail due to partial files
- User gets error → clicks "Clear & Retry" → files removed → fresh download

**Status**: ✓ Handled via "Clear & Retry"

---

### Edge Case 2: Network Interruption
**Scenario**: Download fails mid-way due to network issue

**What Happens**:
- FluidAudio throws error
- `catch` block: `parseDownloadError()` checks for "network"
- Returns: "Network error. Check connection and retry."
- State = `.error("Network error...")`
- UI shows error + "Clear & Retry" button

**Status**: ✓ Handled with user-friendly message

---

### Edge Case 3: Concurrent Download Attempts
**Scenario**: User rapidly clicks Download button multiple times

**What Happens**:
```swift
// First click:
if modelStates[modelId] == .downloading { return }  // false, continues
modelStates[modelId] = .downloading

// Second click (before first completes):
if modelStates[modelId] == .downloading { return }  // TRUE, returns early ✓
```

**Status**: ✓ Prevented by guard clause

---

### Edge Case 4: Download Already Completed
**Scenario**: User clicks Download when model already downloaded

**What Happens**:
```swift
if modelStates[modelId] == .downloaded { return }  // TRUE, returns early ✓
```

**Status**: ✓ Prevented by guard clause

---

### Edge Case 5: Clear While Downloading (Future Multi-Model)
**Scenario**: With multiple models, one is downloading, user clears all

**Current Behavior** (single model):
- Button only shows if state == .downloaded
- If state == .downloading, button is hidden ✓

**Future Behavior** (multiple models):
- If Model A is .downloaded and Model B is .downloading
- Button will be shown (because A is downloaded)
- User clicks clear → removes A's files
- B's download continues but may fail when trying to write to cleared directory

**Status**: ⚠️ Not an issue now (single model), but needs fixing for multi-model

**Fix Needed**:
```swift
// Disable button if ANY model is downloading
.disabled(manager.availableModels.contains(where: {
    manager.state(for: $0.id) == .downloading
}))
```

---

## Threading & Concurrency Analysis

### @MainActor Isolation
- **ModelDownloadManager**: @MainActor ✓
- **DownloadableModel protocol**: @MainActor ✓
- **ParakeetModel**: struct (no isolation needed) ✓
- **ParakeetTranscriptionManager**: @MainActor ✓

**All UI updates happen on MainActor** ✓

### Async Operations
1. `checkAllModelsStatus()` - File I/O (async, non-blocking)
2. `downloadModel()` - Network download (async via FluidAudio)
3. `isDownloaded()` - File existence check (fast, MainActor OK)

**No blocking operations on MainActor** ✓

---

## File System Operations

### Model Storage Location
```
~/Library/Containers/com.beneric.Omri/Data/
  └── Library/Application Support/
      └── FluidAudio/
          └── Models/
              └── parakeet-tdt-0.6b-v3-coreml/
                  ├── Decoder.mlmodelc/
                  ├── Encoder.mlmodelc/
                  ├── JointDecision.mlmodelc/
                  ├── Preprocessor.mlmodelc/
                  ├── config.json ← Checked by isDownloaded()
                  ├── parakeet_v3_vocab.json
                  └── parakeet_vocab.json
```

### 🚨 ISSUE FOUND: Hardcoded Model Directory

In `clearModel()`:
```swift
.appendingPathComponent("parakeet-tdt-0.6b-v3-coreml") // HARDCODED ❌
```

**Problem**: If FluidAudio updates the model directory name, this breaks.

**Fix**: Make it dynamic based on model ID or query FluidAudio for the path.

---

## Issues Summary

### Critical Issues
None ✓

### Minor Issues
1. ✅ **FIXED: Hardcoded model directory name** in `clearModel()`
   - Added `storagePath` property to `DownloadableModel` protocol
   - Each model provides its own storage path dynamically
   - Future models automatically supported

2. ✅ **FIXED: Progress indication** (was stuck at 0%)
   - Changed from determinate (0% → 100%) to indeterminate spinner
   - Shows "Downloading model files (~600 MB)..." message
   - Limitation: FluidAudio doesn't provide progress callbacks
   - Better UX: Users see animated spinner instead of frozen 0%

3. **No download cancellation**
   - Impact: Low (downloads are relatively fast, user can quit app)
   - Fix: Add cancel button that sets state to .error

4. ✅ **FIXED: Future multi-model edge case** (clear while downloading)
   - Added `.disabled()` modifier to "Clear All Models" button
   - Button disabled when ANY model is downloading
   - Prevents corrupting partial downloads

---

## Best Practices Verification

### ✓ Lazy Initialization
- No work done on app launch
- Status check only when UI appears

### ✓ Explicit User Intent
- Downloads only when user clicks "Download"
- No automatic downloads

### ✓ UI-Driven State Management
- State checked when UI appears (.onAppear)
- State updated via @Observable (reactive)

### ✓ Idempotent Operations
- Safe to call download() multiple times (guards prevent issues)
- Safe to call checkAllModelsStatus() multiple times

### ✓ Concurrent Safety
- Prevents multiple simultaneous downloads of same model
- @MainActor ensures thread safety

### ✓ Error Handling
- User-friendly error messages
- Clear recovery path ("Clear & Retry")

### ✓ File System Safety
- Best-effort cleanup (ignores errors)
- Checks file existence before operations

---

## Recommendations

### ✅ Completed Fixes
1. ✅ **Fixed hardcoded model directory** in `clearModel()`
2. ✅ **Added multi-model clear protection**
3. ✅ **Fixed UI reactivity** - removed local `let state` variable
4. ✅ **Improved progress indication** - indeterminate spinner with message

### Future Enhancements
1. Progress percentage (if FluidAudio adds support)
2. Download cancellation button
3. Background download continuation
4. Download queue (for multiple concurrent models)

---

## Conclusion

**Overall Status**: ✅ Production Ready with Minor Improvements Needed

The implementation follows best practices:
- ✓ No automatic downloads
- ✓ Proper state management
- ✓ Thread safety
- ✓ Error handling
- ✓ User-friendly UX

Minor issues identified:
- ⚠️ Hardcoded model directory path
- ⚠️ Future multi-model edge case

Both are low-priority and don't affect current single-model functionality.
