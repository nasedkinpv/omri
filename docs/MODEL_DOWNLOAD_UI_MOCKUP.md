# Model Download Feature - UI Mockups

## macOS Interface (Grid Layout)

### State 1: Not Downloaded (Initial)

```
┌────────────────────────────────────────────────────────────────────────────┐
│ Settings                                                          ⚙️ Omri   │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│ ┌──────────────┬───────────────────────────────────────────────────────┐  │
│ │ Dictation    │  Speech Recognition                                   │  │
│ │ AI Polish    │                                                        │  │
│ │ General      │  Service:     [Parakeet (On-Device)        ▼]        │  │
│ │ About        │  Model:       [parakeet-tdt-v3             ▼]        │  │
│ │              │  Language:    [Auto-detect                 ▼]        │  │
│ │              │                                                        │  │
│ │              │  Use Parakeet for 100% private on-device transcription│  │
│ │              │                                                        │  │
│ │              │  ──────────────────────────────────────────────────   │  │
│ │              │                                                        │  │
│ │              │  On-Device Models                                     │  │
│ │              │                                                        │  │
│ │              │  ⚠️  Parakeet TDT v3                                  │  │
│ │              │      Not downloaded (600 MB)                          │  │
│ │              │                                                        │  │
│ │              │                       [Download Models] ◄──── Blue    │  │
│ │              │                                                        │  │
│ │              │  Models will be stored locally for offline use.       │  │
│ │              │  Download once, transcribe anytime without internet.  │  │
│ │              │                                                        │  │
│ │              │  ──────────────────────────────────────────────────   │  │
│ │              │                                                        │  │
│ │              │  Smart Voice Detection                                │  │
│ │              │                                                        │  │
│ │              │  ☑️ Enable Smart Recording                            │  │
│ │              │                                                        │  │
│ └──────────────┴───────────────────────────────────────────────────────┘  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### State 2: Downloading (Active)

```
┌────────────────────────────────────────────────────────────────────────────┐
│ Settings                                                          ⚙️ Omri   │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│ ┌──────────────┬───────────────────────────────────────────────────────┐  │
│ │ Dictation    │  On-Device Models                                     │  │
│ │ AI Polish    │                                                        │  │
│ │ General      │  🔄  Parakeet TDT v3                                  │  │
│ │ About        │      Downloading... 342 MB of 600 MB                  │  │
│ │              │                                                        │  │
│ │              │  ████████████░░░░░░░░░░░░░  57%                      │  │
│ │              │                                                        │  │
│ │              │                                        [Cancel]        │  │
│ │              │                                                        │  │
│ │              │  Downloading models for offline transcription.        │  │
│ │              │  Estimated time remaining: 4 seconds                  │  │
│ │              │                                                        │  │
│ └──────────────┴───────────────────────────────────────────────────────┘  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### State 3: Downloaded (Success)

```
┌────────────────────────────────────────────────────────────────────────────┐
│ Settings                                                          ⚙️ Omri   │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│ ┌──────────────┬───────────────────────────────────────────────────────┐  │
│ │ Dictation    │  On-Device Models                                     │  │
│ │ AI Polish    │                                                        │  │
│ │ General      │  ✅  Parakeet TDT v3                                  │  │
│ │ About        │      Ready for offline use (600 MB)                   │  │
│ │              │                                                        │  │
│ │              │                                   [Re-download]        │  │
│ │              │                                                        │  │
│ │              │  Models are ready. Transcription works offline.       │  │
│ │              │                                                        │  │
│ └──────────────┴───────────────────────────────────────────────────────┘  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## iOS Interface (Form Layout)

### State 1: Not Downloaded (Initial)

```
┌────────────────────────────────────────┐
│  <  Settings                           │
├────────────────────────────────────────┤
│                                        │
│  Dictation   AI Polish   General   ℹ️  │ ← Tabs
│  ━━━━━━━━                              │
│                                        │
│  Speech Recognition                    │
│                                        │
│  Service         Parakeet (On-Device) >│
│  Model           parakeet-tdt-v3      >│
│  Language        Auto-detect          >│
│                                        │
│  Use Parakeet for 100% private        │
│  on-device transcription               │
│                                        │
│  ──────────────────────────────────    │
│                                        │
│  On-Device Models                      │
│                                        │
│  Parakeet TDT v3              ⚠️  📥  │
│  Not downloaded (600 MB)               │
│                                        │
│       [Download Models]                │ ← Blue button
│                                        │
│  Models will be stored locally for    │
│  offline use. Download once,          │
│  transcribe anytime without internet. │
│                                        │
│  ──────────────────────────────────    │
│                                        │
│  Smart Voice Detection                 │
│                                        │
│  Enable Smart Recording           ☑️   │
│                                        │
└────────────────────────────────────────┘
```

### State 2: Downloading (Active)

```
┌────────────────────────────────────────┐
│  <  Settings                           │
├────────────────────────────────────────┤
│                                        │
│  Dictation   AI Polish   General   ℹ️  │
│  ━━━━━━━━                              │
│                                        │
│  On-Device Models                      │
│                                        │
│  Parakeet TDT v3              🔄      │
│  Downloading... 342 MB of 600 MB       │
│                                        │
│  ████████████░░░░░░░░░░  57%          │
│                                        │
│            [Cancel]                    │
│                                        │
│  Downloading models for offline        │
│  transcription.                        │
│                                        │
└────────────────────────────────────────┘
```

### State 3: Downloaded (Success)

```
┌────────────────────────────────────────┐
│  <  Settings                           │
├────────────────────────────────────────┤
│                                        │
│  Dictation   AI Polish   General   ℹ️  │
│  ━━━━━━━━                              │
│                                        │
│  On-Device Models                      │
│                                        │
│  Parakeet TDT v3              ✅      │
│  Ready for offline use (600 MB)        │
│                                        │
│          [Re-download]                 │
│                                        │
│  Models are ready. Transcription      │
│  works offline.                        │
│                                        │
└────────────────────────────────────────┘
```

---

## Detailed Component Breakdown

### Status Indicator Colors (OmriStatusIndicator)

```
⚠️  Not Downloaded    → BrandOrange (#FF9500)  - Action needed
🔄  Downloading       → BrandTeal   (#5AC8FA)  - In progress (animated)
✅  Downloaded        → BrandMint   (#00D4AA)  - Success
❌  Error             → BrandOrange (#FF9500)  - Retry needed
```

### Button Styles

```
[Download Models]     → .borderedProminent + BrandBlue
                       Large, prominent, primary action

[Cancel]              → .bordered (secondary)
                       Medium, less prominent

[Re-download]         → .bordered (secondary)
                       Medium, optional action

[Retry Download]      → .borderedProminent + BrandOrange
                       Large, urgent action
```

### Progress Bar

```
████████████░░░░░░░░░░░░░  57%

Filled:   BrandTeal (#5AC8FA)
Unfilled: Gray 300 (system)
Height:   6pt (standard)
Corners:  Rounded
```

---

## User Journey Visualization

### Journey 1: First-Time User

```
Step 1: Open Settings
┌────────────────────┐
│ [Dictation] tab    │  ← User clicks
└────────────────────┘

Step 2: Select Parakeet
┌────────────────────┐
│ Service: [Parakeet▼]│  ← User selects
└────────────────────┘

Step 3: See Download Section
┌────────────────────┐
│ ⚠️ Not downloaded  │  ← Section appears
│ [Download Models]  │
└────────────────────┘

Step 4: Click Download
┌────────────────────┐
│ 🔄 Downloading...  │  ← Progress shown
│ ████░░░░░░  45%    │
└────────────────────┘

Step 5: Download Complete
┌────────────────────┐
│ ✅ Ready for use   │  ← Success!
│ [Re-download]      │
└────────────────────┘

Step 6: Use Immediately
┌────────────────────┐
│ Press fn           │  → Instant transcription
│ [No delay!]        │     (no 8s wait)
└────────────────────┘
```

### Journey 2: Network Error Recovery

```
Step 1: Download Interrupted
┌────────────────────┐
│ 🔄 Downloading...  │
│ ████░░░░░░  45%    │  ← Network drops
└────────────────────┘

Step 2: Error State
┌────────────────────┐
│ ❌ Download failed │  ← Clear error
│ Network error      │
│ [Retry Download]   │
└────────────────────┘

Step 3: User Retries
┌────────────────────┐
│ 🔄 Downloading...  │  ← Starts from 0%
│ ██░░░░░░░░  10%    │
└────────────────────┘

Step 4: Success
┌────────────────────┐
│ ✅ Ready for use   │
└────────────────────┘
```

---

## Responsive Behavior

### macOS: Grid Layout Scaling

**Standard (1440px width)**:
```
Label                  Control              Button
[On-Device Models]     Status + Text        [Download]
←─────────────────────────────────────────────────────→
        20%                   60%              20%
```

**Narrow (1024px width)**:
```
Label + Status         Button
[Models] Ready         [Re-download]
←─────────────────────────────────→
        70%               30%
```

### iOS: Form Layout Stacking

**iPhone (Portrait)**:
```
┌────────────────────┐
│ Parakeet TDT v3    │  ← Title
│ Status text        │  ← Description
│ ⚠️ Download button │  ← Action
└────────────────────┘
```

**iPad (Regular width)**:
```
┌────────────────────────────────┐
│ Parakeet TDT v3        ⚠️ 📥  │  ← Inline
│ Status                         │
│         [Download Models]      │  ← Centered
└────────────────────────────────┘
```

---

## Animation & Interaction

### Download Button States

**Idle → Hover (macOS)**:
```
[Download Models]
      ↓ (hover)
[Download Models]  ← Slight scale (1.02x)
```

**Press → Loading**:
```
[Download Models]
      ↓ (tap/click)
[  Preparing...  ]  ← Brief (0.5s)
      ↓
🔄 Downloading... 0%
```

### Progress Bar Animation

```
Frame 1: ░░░░░░░░░░░░░░░░  0%
Frame 2: █░░░░░░░░░░░░░░░  5%
Frame 3: ██░░░░░░░░░░░░░░  10%
         ...
Frame N: ████████████████  100% → ✅
```

**Duration**: 8-12 seconds (actual download time)
**Easing**: Linear (matches real progress)
**Update frequency**: Every 500ms

### Status Indicator Pulse (Downloading)

```
🔄  ← Rotate 360° over 2s
    Opacity: 1.0 → 0.6 → 1.0 (repeating)
```

---

## Edge Cases

### Case 1: Switching Providers During Download

```
User: Parakeet → Groq (while downloading)

Action:
1. Cancel ongoing download
2. Hide "On-Device Models" section
3. Show "Account" section (for Groq API key)

No orphaned downloads
```

### Case 2: Multiple Rapid Clicks

```
User: Clicks [Download] 3 times rapidly

Action:
1. First click: Start download
2. Second click: Ignored (already downloading)
3. Third click: Ignored (button disabled)

Button state: .disabled during download
```

### Case 3: App Quit During Download

```
User: Downloads 50% → Quits app

Next launch:
1. Check model status: Incomplete
2. Show: "❌ Download incomplete"
3. Action: [Retry Download]

Clean up partial files
```

### Case 4: Already Downloaded Models

```
User: Downloads models → Switches to Groq → Back to Parakeet

Action:
1. Check model status: Already downloaded
2. Show: "✅ Ready for use"
3. No re-download needed

Fast provider switching
```

---

## Accessibility Details

### VoiceOver (iOS/macOS)

**Not Downloaded**:
```
Element: Button
Label: "Download Models"
Hint: "Downloads 600 megabytes of on-device transcription models.
       This allows offline transcription without internet."
Traits: Button
```

**Downloading**:
```
Element: Progress
Label: "Downloading models"
Value: "57 percent complete, 342 megabytes of 600 downloaded"
Traits: Updates Frequently

Element: Button
Label: "Cancel download"
Hint: "Stops the model download"
Traits: Button
```

**Downloaded**:
```
Element: Status
Label: "Models ready for offline use"
Value: "600 megabytes installed"
Traits: Static Text

Element: Button
Label: "Re-download models"
Hint: "Downloads the models again if needed"
Traits: Button
```

### Keyboard Navigation (macOS)

```
Tab Order:
1. Service picker        (Tab to focus)
2. Model picker          (Tab to focus)
3. Language picker       (Tab to focus)
4. Download button       (Tab to focus, Space to activate)
5. Enable VAD toggle     (Tab to focus, Space to toggle)

During download:
4. Cancel button         (Tab to focus, Space to activate)
```

### Reduced Motion

**Standard**:
```
🔄 (rotating icon, pulsing opacity)
████████░░░░░░  (animated fill)
```

**Reduced Motion**:
```
🔄 (static icon, solid color)
████████░░░░░░  (instant updates, no animation)
```

---

## Dark Mode Support

### Light Mode
```
Background:     White / System Background
Text:           Black / Primary
Footer:         Gray 600 / Secondary
Progress Fill:  BrandTeal (#5AC8FA)
Progress Empty: Gray 300
```

### Dark Mode
```
Background:     Gray 900 / System Background
Text:           White / Primary
Footer:         Gray 400 / Secondary
Progress Fill:  BrandTeal (#5AC8FA)  ← Same
Progress Empty: Gray 700
```

### Status Colors (Same in Both Modes)
```
Success:  BrandMint   (#00D4AA)  ← Sufficient contrast
Warning:  BrandOrange (#FF9500)  ← Sufficient contrast
Action:   BrandTeal   (#5AC8FA)  ← Sufficient contrast
```

---

## Implementation Priority

### P0: Core Functionality (MVP)
```
✓ Show download status (Not Downloaded / Downloaded)
✓ Download button
✓ Success/error states
✓ Basic progress indication
```

### P1: Polish
```
✓ Accurate progress bar (if FluidAudio supports)
✓ Time remaining estimate
✓ Error recovery (retry)
✓ Cancel download
```

### P2: Nice-to-Have
```
○ Model details (size breakdown)
○ Storage location info
○ Model version display
○ Auto-update check
```

### P3: Future
```
○ Multiple model versions
○ Language-specific models
○ Quality settings (fast vs accurate)
○ Background download
```

---

## Summary

This UI design provides:

✅ **Clear visibility** - Status always visible when Parakeet selected
✅ **User control** - Explicit download action, not automatic
✅ **Progress feedback** - Real-time progress bar
✅ **Error recovery** - Clear retry mechanisms
✅ **Consistency** - Matches existing Omri UI patterns
✅ **Accessibility** - Full VoiceOver and keyboard support
✅ **Platform-appropriate** - Grid (macOS) vs Form (iOS)

The design eliminates first-use friction while maintaining user trust and control.

---

**Document Status**: UI Mockup - Ready for Implementation
**Created**: 2025-10-23
**Author**: UX Design Team
