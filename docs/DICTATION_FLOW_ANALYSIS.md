# Smart Dictation Flow Analysis

## Current State (2025-10-23)

### Overview
Omri implements smart voice dictation with three processing modes:
1. **On-device batch** (Apple/Parakeet without VAD)
2. **On-device streaming** (Parakeet with VAD)
3. **Cloud streaming** (Groq/OpenAI with VAD)

### Current Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER INITIATES RECORDING                      │
│                     (fn key press OR Dictate button)                 │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     AudioManager.startRecording()                    │
│  • Cache provider settings for audio thread                          │
│  • Initialize on-device managers (Apple/Parakeet) if needed         │
│  • Initialize VAD if enabled (lazy init, async download)            │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                ┌────────────┼────────────┐
                │            │            │
                ▼            ▼            ▼
       ┌────────────┐ ┌──────────┐ ┌─────────────┐
       │   Apple    │ │ Parakeet │ │ Cloud APIs  │
       │  (batch)   │ │ (±VAD)   │ │  (±VAD)     │
       └─────┬──────┘ └─────┬────┘ └──────┬──────┘
             │              │              │
             │              │              │ VAD Mode?
             │              │              ▼
             │              │    ┌──────────────────────┐
             │              │    │   VADManager.init    │
             │              │    │  • Downloads model   │
             │              │    │  • Async task        │
             │              │    │  • May fail silently │
             │              │    └──────────┬───────────┘
             │              │               │
             ▼              ▼               ▼
       ┌──────────────────────────────────────────┐
       │     startAudioEngineAndTap()             │
       │  • Install audio tap on input node       │
       │  • Start AVAudioEngine                   │
       │  • Begin audio buffer capture            │
       └──────────────┬───────────────────────────┘
                      │
                      ▼
       ┌─────────────────────────────────────────────┐
       │     handleAudioBuffer() [AUDIO THREAD]      │
       │  • Convert format (device → 16kHz mono)     │
       │  • Route based on cached flags              │
       └──────────────┬──────────────────────────────┘
                      │
       ┌──────────────┼──────────────┐
       │              │              │
       ▼              ▼              ▼
┌─────────────┐ ┌─────────┐ ┌──────────────┐
│ VAD Route   │ │On-Device│ │Cloud Batch   │
│ (streaming) │ │ Batch   │ │ (no VAD)     │
└──────┬──────┘ └────┬────┘ └──────┬───────┘
       │             │              │
       │             │              │ Buffers in memory
       │             │              │
       ▼             ▼              ▼
┌─────────────────────────────────────────────────┐
│          USER STOPS RECORDING                    │
│        (fn key release OR Stop button)           │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│         AudioManager.stopRecording()             │
└────────────────────┬────────────────────────────┘
                     │
      ┌──────────────┼──────────────┐
      │              │              │
      ▼              ▼              ▼
┌──────────┐  ┌──────────┐  ┌────────────────┐
│  Apple   │  │ Parakeet │  │  Cloud Batch   │
│finishAud │  │stopSess  │  │processBuffers  │
│stopSess  │  │          │  │→ transcribe()  │
└────┬─────┘  └────┬─────┘  └────────┬───────┘
     │             │                  │
     │ Batch only  │ Batch only      │
     │             │                  │
     ▼             ▼                  ▼
┌─────────────────────────────────────────────┐
│    Transcription Result (final text)        │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│     PasteManager.processAndPasteText()      │
│  • Optional AI transformation (fn+shift)    │
│  • Terminal detection and routing           │
│  • Clipboard copy + paste                   │
└─────────────────────────────────────────────┘
```

### VAD Streaming Flow Detail

```
┌─────────────────────────────────────────────────┐
│   VADManager.processAudioBuffer() [Real-time]   │
│  • Extracts Float32 samples from buffer         │
│  • Calls FluidAudio processStreamingChunk()     │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│   FluidAudio Silero VAD Neural Network          │
│  • Threshold: 0.5 (configurable)                │
│  • Min speech: 0.25s                            │
│  • Silence timeout: 1.0s                        │
└────────────────┬────────────────────────────────┘
                 │
         ┌───────┴───────┐
         │               │
         ▼               ▼
┌─────────────┐  ┌──────────────┐
│ speechStart │  │  speechEnd   │
│  event      │  │   event      │
└──────┬──────┘  └──────┬───────┘
       │                │
       │ Set flag       │ Process chunk
       │ Clear buffers  │
       │                │
       ▼                ▼
┌─────────────────────────────────────────────┐
│  Collect audio buffers during speech        │
│  • Append buffers while isSpeechDetected    │
│  • Calculate duration from timestamps       │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│   vadManager(didCompleteAudioChunk)         │
│  • Convert buffers → WAV data (cloud)       │
│  • Extract Float samples (on-device)        │
└────────────────┬────────────────────────────┘
                 │
         ┌───────┴───────┐
         │               │
         ▼               ▼
┌─────────────┐  ┌──────────────┐
│  Cloud API  │  │   Parakeet   │
│ transcribe  │  │transcribeChk │
└──────┬──────┘  └──────┬───────┘
       │                │
       │ Wait for API   │ Immediate
       │                │
       ▼                ▼
┌─────────────────────────────────────────────┐
│  performStreamingTranscription() OR         │
│  performParakeetStreamingTranscription()    │
│  • Skip if already processing (flag)        │
│  • Set isProcessingTranscription = true     │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  PasteManager.appendStreamingText()         │
│  • Optional AI transformation               │
│  • Native insertion at cursor position      │
│  • OR clipboard + Cmd+V fallback            │
└─────────────────────────────────────────────┘
                 │
                 │ Multiple chunks possible
                 │ during single recording
                 ▼
         [CONTINUES UNTIL
          USER STOPS RECORDING]
```

## Identified UX Problems

### 1. **VAD Initialization Race Condition**
**Location**: `AudioManager.continueStartRecording()` lines 299-325, 426-448

**Problem**:
- VAD initialization happens asynchronously AFTER audio engine starts
- User may start speaking before VAD is ready
- First 1-2 seconds of audio might be missed
- No user feedback about VAD readiness state

**Code Evidence**:
```swift
// Cloud API mode - initialize VAD if enabled
if Settings.shared.enableVAD {
    if vadManager == nil {
        Task {
            do {
                try await setupVADManager()  // Async init
                await MainActor.run {
                    self.vadManager?.startListening()
                }
            } catch {
                // Fails silently - continues without VAD
            }
        }
    }
}
// Start audio engine immediately (line 450)
startAudioEngineAndTap()  // Audio starts BEFORE VAD ready
```

**Impact**: **CRITICAL**
- First utterance gets lost
- Unpredictable behavior (sometimes works, sometimes doesn't)
- No user indication of system state

### 2. **Streaming Processing Lock Contention**
**Location**: `AudioManager.performStreamingTranscription()` lines 765-810

**Problem**:
- Single `isProcessingTranscription` flag blocks all chunks
- If API is slow (500ms-1s), subsequent speech chunks are silently dropped
- User speaks multiple sentences but only first one transcribes

**Code Evidence**:
```swift
func performStreamingTranscription(audioData: Data, duration: Double) async {
    if self.isProcessingTranscription {
        Logger.log("Skipping chunk transcription - already processing",
                   context: "VAD", level: .debug)
        return  // ❌ Drops chunk silently
    }
    self.isProcessingTranscription = true
    // ... API call (can take 500ms-2s)
    self.isProcessingTranscription = false
}
```

**Impact**: **HIGH**
- Lost speech segments when talking continuously
- User confusion ("Why didn't it transcribe what I said?")
- Degraded experience with slower APIs (OpenAI vs Groq)

### 3. **Inconsistent AI Processing Behavior**
**Location**: `PasteManager.appendStreamingText()` vs `processAndPasteText()` lines 37-56, 58-73

**Problem**:
- Streaming mode processes AI per chunk (many small requests)
- Batch mode processes AI once (single context)
- Different quality results for same provider settings
- Inefficient: AI model gets fragmented sentences, loses context

**Code Evidence**:
```swift
func appendStreamingText(_ text: String, withAI: Bool = true) async {
    let shouldUseAI = withAI && Settings.shared.enableAIProcessing
    let processedText = await processText(text, withAI: shouldUseAI)
    // ❌ Each chunk gets independent AI processing
    // "Hello" → AI process → paste
    // "how are" → AI process → paste
    // "you today" → AI process → paste
    // Result: Choppy, inconsistent, expensive
}
```

**Impact**: **MEDIUM**
- Higher AI API costs (3 requests vs 1)
- Inconsistent formatting across chunks
- Lost context between sentences
- Confusing for users (text changes style mid-sentence)

### 4. **No User Feedback During Processing**
**Location**: Multiple locations - no status UI implementation

**Problem**:
- No visual indication of VAD state (listening vs processing)
- No feedback when chunk is being transcribed
- No indication when AI processing is happening
- User doesn't know if system is working or frozen

**Missing Implementation**:
- AudioManager delegates signal state changes (didStart, didStop, willStartNetworkProcessing)
- AppDelegate updates status bar icon
- BUT: No intermediate states (transcribing, transforming, pasting)

**Impact**: **MEDIUM-HIGH**
- User uncertainty ("Is it working?")
- Accidental double-taps ("It's not responding, let me try again")
- No clear distinction between recording/processing/inserting states

### 5. **VAD Timing Parameters Not User-Tested**
**Location**: `VADManager.init()` line 88-93

**Problem**:
- Default values seem arbitrary:
  - Sensitivity: 0.5
  - Min speech: 0.25s (250ms)
  - Silence timeout: 1.0s
- No documentation on why these values chosen
- Research shows dictation needs different timing than conversation

**Research Evidence**:
> "People tend to speak faster in conversations compared to dictation, so the optimal silence-based timeout threshold may be higher for dictation compared to conversational scenarios."

**Impact**: **MEDIUM**
- May cut off natural pauses in dictation
- May wait too long after user finishes
- Not optimized for target use case (dictation vs conversation)

### 6. **Terminal Routing Happens Too Late**
**Location**: `PasteManager.processAndPasteText()` line 44-51

**Problem**:
- AI processing happens before terminal check
- Wastes API credits if user is in terminal (doesn't need polish)
- Unnecessary latency for terminal use case

**Code Evidence**:
```swift
let processedText = await processText(text, withAI: shouldUseAI)
// ❌ AI processing done first (500ms-2s)

#if os(macOS)
if TerminalWindowController.shared.isTerminalActive {
    TerminalWindowController.shared.sendText(processedText)
    // ✅ But AI already ran and charged API
}
#endif
```

**Impact**: **LOW-MEDIUM**
- Wasted API costs
- Added latency (500ms-2s) for terminal users
- Not a functional bug, but inefficient

### 7. **Native Insertion vs Paste Fallback Confusion**
**Location**: `PasteManager.appendTextToCurrentPosition()` lines 166-179

**Problem**:
- Two different pasting mechanisms with different UX
- Native insertion: Precise cursor position, preserves clipboard
- Cmd+V fallback: Replaces clipboard, less precise
- No clear user indication of which method will be used
- Accessibility permissions required but not explained upfront

**Impact**: **LOW**
- Inconsistent pasting behavior
- Clipboard pollution (user's copied content gets replaced)
- Confusing permission prompts

## Industry Best Practices (Research Findings 2025)

### 1. Latency Thresholds
**Source**: Multiple UX studies, A/B testing results

- **Users notice delays > 250ms**
- **Ideal latency < 100ms** (excellent UX)
- **250-500ms**: Acceptable but noticeable
- **> 500ms**: Poor UX, users perceive as "slow"

**Implication for Omri**:
- Cloud API transcription typically 500ms-2s
- VAD adds 50-100ms buffering delay
- AI transformation adds 500ms-2s
- **Total latency: 1-4 seconds** ❌ Above acceptable threshold

### 2. VAD Failure Modes
**Research**: WebRTC VAD analysis, Silero VAD benchmarks

**Finding**: VAD should "fail-safe" by indicating speech when in doubt
- Better to have false positive (transcribe background noise) than false negative (miss speech)
- Users can delete accidental transcription, but can't recover lost speech

**Current Omri Behavior**: Neutral (Silero VAD defaults)
- Sensitivity 0.5 is middle-ground
- No fail-safe bias implemented

### 3. Streaming vs Batch Trade-offs
**Source**: Deepgram, AssemblyAI documentation

**Streaming Benefits**:
- Lower perceived latency (incremental results)
- Better for long recordings (minutes)
- Allows real-time corrections

**Batch Benefits**:
- Better accuracy (full context)
- Lower API costs (single request)
- Simpler error handling

**Hybrid Approach** (Recommended):
- Use streaming for real-time feedback
- Use batch for final processing
- Example: Show interim results, but send full audio for final accuracy

**Omri Currently**: Pure streaming (VAD mode) or pure batch (no VAD)
- Missing hybrid approach

### 4. AI Processing Context
**Source**: GPT-4/Claude API documentation, RAG best practices

**Finding**: Context matters for quality
- Processing fragmented sentences reduces quality
- Better to process complete thoughts as single unit
- Streaming AI should only be used for low-latency requirements (chat)

**Current Omri Behavior**: Processes each VAD chunk independently
- Loses context between sentences
- Lower quality than batch mode
- **Recommendation**: Accumulate chunks, process once at end

### 5. User Feedback Patterns
**Source**: Apple Human Interface Guidelines, Material Design

**Key Principles**:
- **Immediate feedback** on action (< 100ms)
- **Progress indication** for operations > 1s
- **Clear state transitions** (recording → processing → done)
- **Error recovery** (clear CTAs when something fails)

**Current Omri**:
- ✅ Status bar icon changes (waveform → mic → hourglass)
- ❌ No intermediate states during streaming
- ❌ No clear error recovery flows
- ❌ No indication of VAD initialization state

### 6. Dictation-Specific Timing
**Source**: Academic research on dictation systems

**Finding**:
- Dictation has longer natural pauses than conversation (thinking time)
- Optimal silence timeout: **1.5-2.5 seconds** (higher than conversation's 0.5-1s)
- Minimum speech duration: **300-500ms** to filter out non-speech sounds

**Current Omri**: 1.0s silence, 0.25s min speech
- Silence timeout may be too aggressive for dictation
- Min speech is probably good

## Recommended Flow Improvements

### Priority 1: Fix VAD Initialization Race (CRITICAL)

**Current Problem**: VAD initializes async while audio starts immediately

**Solution**:
```
startRecording() → Check VAD enabled
                      ↓
                 VAD initialized?
                      ↓
               ┌──────┴──────┐
               │             │
               ▼             ▼
           ✅ Yes         ❌ No
               │             │
               │             ▼
               │      await setupVADManager()
               │             │
               │    ┌────────┘
               │    │ Success?
               │    │
               │    ▼
               └────┴────> startAudioEngineAndTap()
                           (only after VAD ready)
```

**Implementation**:
- Block `startAudioEngineAndTap()` until VAD init completes
- Show status bar indicator during init ("Preparing VAD...")
- Timeout after 5 seconds, fall back to batch mode
- Clear user feedback throughout

### Priority 2: Queue-Based Streaming Processing (HIGH)

**Current Problem**: Single processing flag drops chunks

**Solution**:
```swift
class AudioManager {
    private var transcriptionQueue: [AudioChunk] = []
    private var isProcessingQueue = false

    func vadManager(didCompleteAudioChunk audioData: Data, duration: Double) {
        // Always queue chunk
        transcriptionQueue.append(AudioChunk(data: audioData, duration: duration))

        // Process queue if not already processing
        if !isProcessingQueue {
            Task { await processTranscriptionQueue() }
        }
    }

    private func processTranscriptionQueue() async {
        isProcessingQueue = true

        while let chunk = transcriptionQueue.first {
            transcriptionQueue.removeFirst()

            // Transcribe chunk
            let result = try? await transcriptionService.transcribe(...)

            // Append to accumulated text (not paste yet)
            accumulatedText.append(result.text)
        }

        isProcessingQueue = false
    }
}
```

**Benefits**:
- Never drops speech chunks
- Maintains temporal ordering
- Clear queue status for UI feedback

### Priority 3: Hybrid Streaming + Batch (MEDIUM)

**Current Problem**: Inconsistent AI processing, poor context

**Solution**:
```
VAD detects speech chunks
        ↓
Transcribe each chunk → Accumulate plain text
        ↓                      ↓
Show interim results    [Store in buffer]
        ↓                      ↓
User stops recording
        ↓
Process accumulated text with AI (single request)
        ↓
Replace interim text with final polished version
```

**Benefits**:
- Lower perceived latency (streaming feedback)
- Better quality (AI gets full context)
- Lower costs (single AI request)

### Priority 4: User Feedback Enhancements (MEDIUM)

**Add explicit state machine**:

```
States:
- Idle (no icon OR default mic icon)
- Initializing VAD (loading spinner)
- Ready to Record (mic icon)
- Recording (waveform animation)
- Detecting Speech (waveform + badge)
- Transcribing (upload icon)
- Transforming AI (sparkle icon)
- Inserting Text (checkmark flash)
- Error (warning icon)

Transitions:
- Each state has clear icon + tooltip
- Errors show notification with recovery CTA
- Long operations (>1s) show progress
```

**Implementation**:
- AppDelegate status item updates for each state
- Delegate methods for all state transitions
- Persistent state observable (for external monitoring)

### Priority 5: Tunable VAD Parameters (LOW)

**Current**: Hardcoded values in VADManager init

**Solution**:
- Add "Advanced" section to settings
- Provide presets:
  - "Conversation" (fast, 0.5s silence)
  - "Dictation" (balanced, 1.5s silence) ← DEFAULT
  - "Careful" (slow, 2.5s silence)
- Allow manual tuning for power users
- Document what each parameter does

## Comparison: Current vs Ideal Flow

### Current Flow (VAD Streaming Mode)
```
1. User presses fn key
2. startRecording() → VAD.init() async (may take 500ms)
3. Audio engine starts immediately
4. Audio buffers → lost if VAD not ready
5. VAD eventually starts → detects speech → emits chunk
6. Chunk queued for transcription
7. IF not already processing:
     - Transcribe chunk (500ms-2s)
     - Process with AI if enabled (500ms-2s)
     - Paste immediately
8. ELSE: Drop chunk silently ❌
9. Repeat steps 5-8 for each speech segment
10. User releases fn key → stopRecording()
11. VAD stops listening
```

**Total latency per chunk**: 1-4 seconds
**Chunks dropped**: Often (if speaking continuously)
**AI quality**: Poor (no context)

### Ideal Flow (Hybrid Approach)
```
1. User presses fn key
2. Show "Initializing..." indicator
3. await VAD initialization (guaranteed ready)
4. Show "Ready - Start speaking" indicator
5. Audio engine starts
6. User speaks → VAD detects speech → emits chunk
7. Queue chunk for background transcription
8. Show interim transcription immediately (no AI yet)
9. Continue queuing and showing interim results
10. User releases fn key → stopRecording()
11. Combine all interim transcriptions
12. IF AI enabled: Process complete text once (single request)
13. Replace interim text with final result
14. Paste to target application
```

**Total latency**:
- First interim result: 500ms-1s (streaming benefit)
- Final result: +1-2s for AI (only if enabled)

**Benefits**:
- ✅ No dropped chunks (queue-based)
- ✅ Immediate feedback (streaming display)
- ✅ High quality (batch AI processing)
- ✅ Predictable behavior (guaranteed init)

## Testing Recommendations

### User Testing Scenarios

1. **Continuous Speech**
   - Dictate 3-4 sentences without pausing
   - Expected: All sentences captured
   - Current: Often drops chunks 2-3

2. **Natural Pauses**
   - Dictate with 2-3 second pauses (thinking time)
   - Expected: Preserves all speech, doesn't cut off early
   - Current: May trigger speechEnd too early (1s timeout)

3. **Cold Start**
   - First use after app launch
   - Expected: Clear feedback during VAD download
   - Current: Silent init, possible missing first utterance

4. **Terminal vs App Usage**
   - Switch between terminal and text editor
   - Expected: AI only processes when needed (text editor)
   - Current: Always processes AI regardless of target

5. **Permission States**
   - Test without accessibility permissions
   - Expected: Clear prompt, graceful fallback
   - Current: Works but uses Cmd+V (replaces clipboard)

### Performance Benchmarks

**Metrics to track**:
- Time to first transcription result (target < 1s)
- End-to-end latency (target < 2s without AI, < 4s with AI)
- Chunk drop rate (target 0%)
- API request count per recording (minimize)
- User-perceived responsiveness (qualitative)

**Test across**:
- Different providers (Groq vs OpenAI vs Parakeet)
- Network conditions (fast LTE, slow WiFi, offline)
- Audio environments (quiet room, background noise, music playing)

## Implementation Priority Matrix

| Issue                          | Impact | Effort | Priority |
|-------------------------------|--------|--------|----------|
| VAD initialization race       | HIGH   | LOW    | P0 🔴    |
| Streaming processing lock     | HIGH   | MED    | P1 🟠    |
| User feedback states          | MED    | MED    | P1 🟠    |
| Hybrid streaming+batch        | MED    | HIGH   | P2 🟡    |
| AI processing efficiency      | MED    | LOW    | P2 🟡    |
| Terminal routing optimization | LOW    | LOW    | P3 🟢    |
| VAD parameter tuning          | LOW    | LOW    | P3 🟢    |
| Native insertion behavior     | LOW    | LOW    | P4 ⚪    |

## Next Steps

1. **Review this analysis** with stakeholders
2. **User test current behavior** to validate hypotheses
3. **Prototype P0 fix** (VAD init race condition)
4. **A/B test** queue-based processing vs current
5. **Design UI mockups** for state feedback
6. **Implement hybrid flow** if user testing validates need
7. **Document best practices** for future features

---

**Document Status**: Draft for Review
**Last Updated**: 2025-10-23
**Author**: Analysis based on codebase audit + 2025 research
