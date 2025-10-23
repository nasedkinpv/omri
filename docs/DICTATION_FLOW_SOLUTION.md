# Smart Dictation Flow: The Ultimate Fix

## Deep Thinking Analysis

### The Root Cause: Conflated Boundaries

The fundamental awkwardness stems from mixing two different boundary models:

1. **User-Bounded Sessions**: User explicitly starts (fn key down) and stops (fn key up)
2. **System-Bounded Chunks**: VAD implicitly detects speech start/end within the session

Current architecture treats VAD chunks as independent recording sessions, when they're actually fragments of a single user-controlled session. This is like treating TCP packets as separate HTTP requests - a category error that creates cascading problems.

### Key Insight: VAD's True Purpose

**Wrong Mental Model**: VAD controls when to transcribe
**Correct Mental Model**: VAD provides interim checkpoints for UX feedback

The fn key release is the true processing trigger. VAD should enable "show progress as you speak" not "decide when to process." This single reframing solves most architectural problems.

### The "Awkward" Feeling Decoded

When users say it feels awkward, they mean:
- **Unpredictability**: Sometimes works, sometimes doesn't (race conditions)
- **Black box**: No idea what the system is doing (missing feedback)
- **Lost speech**: Dropped chunks create confusion and frustration
- **Inconsistency**: Results vary based on invisible system state

The fix isn't just technical - it's about making system state **observable and predictable**.

## Proposed Architecture: The Session-Centric Model

### Three Clean Layers

```
┌─────────────────────────────────────────────────────┐
│              1. CAPTURE LAYER                        │
│  Responsibilities:                                   │
│  • Audio buffer collection (AVAudioEngine)          │
│  • Format conversion (device → 16kHz mono)          │
│  • VAD analysis (speech detection)                  │
│  • Waveform visualization data                      │
│                                                      │
│  Key: No business logic, pure data collection       │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              2. SESSION LAYER                        │
│  Responsibilities:                                   │
│  • Session lifecycle management                     │
│  • Audio/text accumulation                          │
│  • Interim result generation                        │
│  • Processing queue management                      │
│  • State machine orchestration                      │
│                                                      │
│  Key: Single source of truth for session state      │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              3. OUTPUT LAYER                         │
│  Responsibilities:                                   │
│  • Target app detection (terminal vs editor)        │
│  • AI processing (if applicable)                    │
│  • Text insertion (native vs fallback)              │
│  • Clipboard management                             │
│                                                      │
│  Key: Context-aware delivery mechanism              │
└─────────────────────────────────────────────────────┘
```

### The SessionManager: Heart of the System

```swift
@MainActor
class DictationSessionManager: ObservableObject {
    // MARK: - Session State

    struct Session {
        let id: UUID
        let startTime: Date
        var audioBuffers: [AVAudioPCMBuffer] = []
        var interimTranscripts: [String] = []
        var vadCheckpoints: [VADCheckpoint] = []
        var state: SessionState
        var targetContext: TargetContext?
    }

    struct VADCheckpoint {
        let timestamp: Double
        let audioRange: Range<Int>  // Buffer indices
        let speechDuration: Double
        var transcriptIndex: Int?   // Reference to interim transcript
    }

    enum SessionState {
        case initializing         // VAD/provider setup
        case ready               // Can start recording
        case recording           // Actively capturing audio
        case detecting(VADState) // VAD detected speech
        case transcribing        // Processing audio → text
        case transforming        // AI processing
        case inserting           // Pasting to target
        case completed           // Done
        case error(Error)        // Failed
    }

    // MARK: - Properties

    private var currentSession: Session?
    private let captureLayer: CaptureLayer
    private let outputLayer: OutputLayer

    @Published var visibleState: SessionState = .ready
    @Published var interimText: String = ""
    @Published var waveformData: [Float] = []

    // MARK: - Public API

    func startSession() async throws {
        let sessionId = UUID()

        // Initialize session
        var session = Session(
            id: sessionId,
            startTime: Date(),
            state: .initializing
        )

        // CRITICAL: Initialize VAD if enabled BEFORE starting audio
        if Settings.shared.enableVAD {
            updateState(.initializing)
            try await captureLayer.ensureVADReady(timeout: 5.0)
        }

        // Detect target app context
        session.targetContext = detectTargetContext()

        // Start audio capture
        session.state = .ready
        currentSession = session
        updateState(.ready)

        try captureLayer.startAudioCapture()
        updateState(.recording)
    }

    func stopSession() async {
        guard var session = currentSession else { return }

        // Stop audio immediately
        captureLayer.stopAudioCapture()

        // Process accumulated data
        await processSession(session)

        currentSession = nil
        updateState(.completed)
    }

    // MARK: - Capture Layer Callbacks

    func captureLayer(_ layer: CaptureLayer, didReceiveAudioBuffer buffer: AVAudioPCMBuffer) {
        guard var session = currentSession else { return }

        // Accumulate all audio (never drop)
        session.audioBuffers.append(buffer)

        // Update waveform visualization
        if let samples = extractWaveformSamples(from: buffer) {
            waveformData = samples
        }
    }

    func captureLayer(_ layer: CaptureLayer, vadDidDetectSpeech checkpoint: VADCheckpoint) {
        guard var session = currentSession else { return }

        // Store checkpoint for later processing
        session.vadCheckpoints.append(checkpoint)
        updateState(.detecting(.speaking))

        // Generate interim transcription (async, non-blocking)
        Task {
            await generateInterimTranscript(for: checkpoint)
        }
    }

    func captureLayer(_ layer: CaptureLayer, vadDidDetectSilence: Void) {
        updateState(.detecting(.silence))
    }

    // MARK: - Session Processing

    private func processSession(_ session: Session) async {
        updateState(.transcribing)

        let provider = Settings.shared.transcriptionProvider

        // Combine all audio into single chunk
        let combinedAudio = combineAudioBuffers(session.audioBuffers)

        // Transcribe based on provider
        let finalTranscript: String
        if provider.isOnDevice {
            // On-device: Use accumulated partials or re-transcribe
            finalTranscript = await transcribeOnDevice(combinedAudio,
                                                       interims: session.interimTranscripts)
        } else {
            // Cloud: Single API call with full audio
            finalTranscript = try await transcribeCloud(combinedAudio)
        }

        // Update UI with full transcript
        interimText = finalTranscript

        // Apply AI processing if enabled AND appropriate for target
        let processedText: String
        if shouldApplyAI(for: session.targetContext) {
            updateState(.transforming)
            processedText = try await outputLayer.transformText(
                finalTranscript,
                context: session.targetContext
            )
        } else {
            processedText = finalTranscript
        }

        // Insert into target application
        updateState(.inserting)
        await outputLayer.insertText(
            processedText,
            into: session.targetContext
        )
    }

    // MARK: - Interim Transcription (UX Only)

    private func generateInterimTranscript(for checkpoint: VADCheckpoint) async {
        guard var session = currentSession else { return }

        // Extract audio for this checkpoint
        let checkpointAudio = extractCheckpointAudio(checkpoint, from: session.audioBuffers)

        // Quick transcription (may be lower quality, that's OK)
        if let transcript = try? await quickTranscribe(checkpointAudio) {
            session.interimTranscripts.append(transcript)

            // Update UI immediately
            interimText = session.interimTranscripts.joined(separator: " ")
        }
    }

    // MARK: - Target Context Detection

    private func detectTargetContext() -> TargetContext {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return .unknown
        }

        let bundleId = frontApp.bundleIdentifier ?? ""

        // Terminal apps: No AI processing, immediate insertion
        if bundleId.contains("terminal") || bundleId.contains("iterm") {
            return .terminal(bundleId: bundleId)
        }

        // Code editors: Preserve exact formatting
        if bundleId.contains("xcode") || bundleId.contains("vscode") {
            return .codeEditor(bundleId: bundleId)
        }

        // Chat apps: Conversational tone
        if bundleId.contains("slack") || bundleId.contains("messages") {
            return .chat(bundleId: bundleId)
        }

        // Text editors: Full AI processing appropriate
        if bundleId.contains("pages") || bundleId.contains("word") {
            return .document(bundleId: bundleId)
        }

        return .generic(bundleId: bundleId)
    }

    private func shouldApplyAI(for context: TargetContext?) -> Bool {
        guard Settings.shared.enableAIProcessing else { return false }

        switch context {
        case .terminal, .codeEditor:
            return false  // Never polish code/terminal
        case .chat:
            return false  // Keep conversational tone
        case .document, .generic, .unknown:
            return true   // Apply polish
        case .none:
            return true
        }
    }
}

enum TargetContext {
    case terminal(bundleId: String)
    case codeEditor(bundleId: String)
    case chat(bundleId: String)
    case document(bundleId: String)
    case generic(bundleId: String)
    case unknown
}
```

### The CaptureLayer: Initialization-First Design

```swift
@MainActor
class CaptureLayer {

    // VAD is always-resident singleton (initialized at app launch)
    private let vadManager: VADManager
    private let audioEngine: AVAudioEngine

    init() {
        self.vadManager = VADManager.shared  // Singleton, pre-initialized
        self.audioEngine = AVAudioEngine()
    }

    // CRITICAL: Ensure VAD is ready before any recording
    func ensureVADReady(timeout: TimeInterval = 5.0) async throws {
        let settings = Settings.shared

        guard settings.enableVAD else { return }

        if !vadManager.isInitialized {
            // First-time initialization with timeout
            try await withTimeout(timeout) {
                try await vadManager.initialize()
            }
        }

        // VAD is guaranteed ready or throws
    }

    func startAudioCapture() throws {
        // Audio engine setup (existing code)
        // Install tap, start engine
        // NO LONGER STARTS BEFORE VAD READY
    }
}

// VAD Manager as Singleton
@MainActor
class VADManager {
    static let shared = VADManager()

    private(set) var isInitialized = false

    // Initialize at app launch (called from AppDelegate)
    func initializeAtLaunch() async {
        guard Settings.shared.enableVAD else { return }

        do {
            try await initialize()
            Logger.log("VAD initialized at app launch", context: "VAD", level: .info)
        } catch {
            Logger.log("VAD initialization failed: \(error)", context: "VAD", level: .warning)
            // App continues without VAD
        }
    }

    // Called during recording if VAD enabled mid-session
    func initialize() async throws {
        guard !isInitialized else { return }

        // FluidAudio initialization (existing code)
        // ...

        isInitialized = true
    }
}
```

### The OutputLayer: Context-Aware Delivery

```swift
@MainActor
class OutputLayer {

    private let transformationService: TransformationService?

    func transformText(_ text: String, context: TargetContext?) async throws -> String {
        guard let service = transformationService else { return text }

        // Choose prompt based on target context
        let prompt = promptForContext(context)

        return try await service.transform(
            text: text,
            prompt: prompt,
            model: Settings.shared.transformationModel,
            temperature: 0.7
        )
    }

    func insertText(_ text: String, into context: TargetContext?) async {
        // Check if terminal (route directly)
        if case .terminal = context {
            TerminalWindowController.shared.sendText(text)
            return
        }

        // Use existing PasteManager logic
        // Native insertion → Cmd+V fallback
        if hasAccessibilityPermissions() {
            tryNativeInsertion(text)
        } else {
            copyAndPaste(text)
        }
    }

    private func promptForContext(_ context: TargetContext?) -> String {
        switch context {
        case .document:
            return Settings.shared.transformationPrompt  // Full polish
        case .generic:
            return """
            Clean up this transcribed speech:
            • Remove filler words (um, uh, like)
            • Fix obvious transcription errors
            • Keep the tone natural

            Transcribed content: {transcribed_text}
            """
        default:
            return ""  // Shouldn't reach here
        }
    }
}
```

## The Complete Flow (Visual)

### Happy Path: User Records, System Responds

```
┌─────────────────────────────────────────────────────────────┐
│ USER: Press fn key                                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ SessionManager.startSession()                                │
│  ├─ State: .initializing                                    │
│  ├─ UI: Show "Preparing..." (if VAD not ready)             │
│  ├─ await CaptureLayer.ensureVADReady(timeout: 5s)         │
│  │   └─ VADManager.shared.initialize() [BLOCKS]            │
│  ├─ detectTargetContext() → TargetContext                  │
│  ├─ State: .ready                                           │
│  └─ CaptureLayer.startAudioCapture()                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ State: .recording                                            │
│ UI: Show HUD with waveform + "Listening..."                 │
└────────────────────┬────────────────────────────────────────┘
                     │
      ┌──────────────┼──────────────┐
      │ [Audio Thread]              │ [Main Thread]
      │                              │
      ▼                              ▼
┌──────────────┐              ┌────────────────┐
│ Audio Buffer │              │ Waveform       │
│ → Accumulate │              │ Visualization  │
│              │              │ Updates        │
│ [NEVER DROP] │              └────────────────┘
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│ VADManager.processBuffer()                   │
│  ├─ Detect speech start                      │
│  │   └─ State: .detecting(.speaking)        │
│  │   └─ UI: Waveform pulses + "Speaking..." │
│  │                                            │
│  └─ Detect speech end (checkpoint)           │
│      └─ Generate interim transcript          │
│          └─ UI: Show text below waveform     │
└──────────────┬───────────────────────────────┘
               │
               │ [Multiple checkpoints possible]
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│ USER: Release fn key                                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ SessionManager.stopSession()                                 │
│  ├─ CaptureLayer.stopAudioCapture() [IMMEDIATE]            │
│  └─ processSession()                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Session Processing (Async, User sees progress)              │
│                                                              │
│ State: .transcribing                                        │
│ UI: "Transcribing..."                                       │
│  ├─ Combine all audio buffers → single chunk               │
│  ├─ Provider-specific transcription                         │
│  │   ├─ On-device: Use accumulated partials + refinement  │
│  │   └─ Cloud: Single API call (no dropped chunks)        │
│  └─ Update interim text display                            │
│                                                              │
│ Decision: Apply AI?                                         │
│  ├─ Check targetContext (terminal? code editor?)           │
│  └─ Check Settings.shared.enableAIProcessing               │
│                                                              │
│ IF AI appropriate:                                          │
│   State: .transforming                                      │
│   UI: "Polishing with AI..."                               │
│   ├─ Context-aware prompt selection                        │
│   └─ Single AI request (full context)                      │
│                                                              │
│ State: .inserting                                           │
│ UI: "Inserting text..."                                     │
│  ├─ Detect target app                                       │
│  ├─ Terminal? → Direct send                                │
│  └─ Other? → Native insertion or Cmd+V                     │
│                                                              │
│ State: .completed                                           │
│ UI: Flash checkmark, fade HUD                              │
└─────────────────────────────────────────────────────────────┘
```

### Error Paths: Explicit Handling

```
┌─────────────────────────────────────────────────────────────┐
│ Error: VAD Initialization Timeout (5s)                      │
│  ├─ State: .error(.vadTimeout)                             │
│  ├─ UI: Show alert "VAD unavailable, continuing in batch   │
│  │       mode"                                              │
│  ├─ Disable VAD for this session                           │
│  └─ Continue with batch recording                          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Error: Transcription API Failure                            │
│  ├─ State: .error(.transcriptionFailed(reason))            │
│  ├─ UI: Show notification "Transcription failed: [reason]  │
│  │       Audio saved to [path]"                            │
│  ├─ Save audio to ~/Desktop/omri_recovery_[timestamp].wav │
│  └─ User can retry via context menu                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Error: User Speaks During Initialization                    │
│  ├─ This CAN'T HAPPEN anymore (init blocks start)          │
│  └─ Architecture prevents race condition entirely          │
└─────────────────────────────────────────────────────────────┘
```

## Key Architectural Decisions

### 1. VAD Lifecycle: Always-Resident Singleton

**Decision**: Initialize VAD at app launch, keep in memory
**Rationale**:
- 2MB model is trivial memory cost
- Eliminates initialization race condition
- Predictable behavior (ready or not ready, never "maybe ready")
- Settings change can trigger re-init in background

**Alternative Rejected**: Lazy initialization
- Creates race conditions
- Unpredictable user experience
- Complex error handling

### 2. Session Boundary: User-Controlled, Not VAD-Controlled

**Decision**: fn key release triggers processing, VAD provides interim feedback only
**Rationale**:
- User expects fn key to control behavior (mental model)
- Dictation has explicit boundaries (unlike conversation)
- VAD timing is inherently heuristic, user timing is explicit
- Allows immediate processing when user is done

**Alternative Rejected**: VAD controls end-of-session
- Unpredictable timing (user released key, why wait?)
- Conflicts with user's mental model
- Adds unnecessary latency

### 3. Transcription Strategy: Accumulate + Process Once

**Decision**: Store all audio, generate interims for UX, process fully at end
**Rationale**:
- Never drops chunks (all audio preserved)
- Interim results give feedback without blocking
- Final processing has full context (better quality)
- Single API request (lower cost)

**Alternative Rejected**: Process each VAD chunk independently
- Drops chunks under load
- Loses context
- Higher API costs
- Inconsistent results

### 4. AI Processing: Context-Aware, Not Blanket

**Decision**: Detect target app, apply AI only where appropriate
**Rationale**:
- Terminal/code editor shouldn't be polished
- Saves API credits
- Reduces latency for non-AI targets
- Better UX (preserves intent in technical contexts)

**Alternative Rejected**: Always apply AI if enabled
- Wastes API costs
- Slower for all use cases
- Inappropriate for technical contexts

### 5. UI Feedback: State Machine with Observable Transitions

**Decision**: Explicit state enum, every state change triggers UI update
**Rationale**:
- User always knows system state
- No black box behavior
- Easy to add new states (e.g., "downloading model")
- Testable (state machine is deterministic)

**Alternative Rejected**: Implicit state via boolean flags
- Combinatorial explosion
- Unclear states
- Hard to test

## Implementation Roadmap

### Phase 1: Core Architecture (1-2 weeks)

**Goal**: New architecture without breaking existing functionality

1. Create `DictationSessionManager` class
   - Session struct
   - State machine
   - Public API (start/stop session)

2. Create `CaptureLayer` class
   - Extract audio capture code from AudioManager
   - Keep VADManager integration

3. Create `OutputLayer` class
   - Extract PasteManager logic
   - Add target context detection

4. Wire up layers
   - SessionManager coordinates CaptureLayer + OutputLayer
   - Delegate callbacks flow through SessionManager

5. Update AudioManager to use SessionManager
   - Thin wrapper for backward compatibility
   - Existing code continues to work

**Deliverable**: New architecture working alongside old code

### Phase 2: VAD Singleton (1 week)

**Goal**: Eliminate initialization race condition

1. Convert VADManager to singleton
   - `VADManager.shared`
   - Initialization at app launch

2. Add initialization tracking
   - `isInitialized` flag
   - `initializeAtLaunch()` method

3. Update SessionManager to block on VAD ready
   - `ensureVADReady(timeout: 5s)`
   - UI feedback during init

4. Update settings UI
   - Show VAD initialization status
   - "Downloading VAD model..." indicator

**Deliverable**: VAD always ready before recording starts

### Phase 3: Session Processing (1-2 weeks)

**Goal**: Accumulate-then-process flow, no dropped chunks

1. Implement session audio accumulation
   - Store all buffers in session
   - Never drop chunks

2. Implement interim transcription
   - Background processing
   - UI-only (doesn't block)

3. Implement final processing
   - Combine all audio
   - Single transcription call
   - Single AI call (if enabled)

4. Remove old per-chunk processing
   - Clean up isProcessingTranscription flag
   - Remove streaming AI logic

**Deliverable**: Reliable transcription, no missing speech

### Phase 4: UI Feedback (1 week)

**Goal**: Observable system state

1. Create state machine UI
   - Status bar icon per state
   - Tooltips with current state

2. Create recording HUD (optional but recommended)
   - Floating window during recording
   - Waveform visualization
   - Interim transcript display
   - Processing state indicator

3. Add notifications for long operations
   - Model downloads
   - Processing delays

**Deliverable**: User always knows system state

### Phase 5: Context-Aware Processing (1 week)

**Goal**: Smart AI application based on target

1. Implement target context detection
   - Bundle ID analysis
   - Context enum

2. Update AI processing logic
   - Check target before processing
   - Skip AI for terminal/code editor

3. Add context-specific prompts
   - Document polish (full)
   - Generic cleanup (light)

**Deliverable**: Efficient, appropriate AI usage

### Phase 6: Testing & Refinement (1-2 weeks)

**Goal**: Validate UX improvements

1. User testing scenarios
   - Continuous speech
   - Natural pauses
   - Cold start
   - Target switching

2. Performance benchmarking
   - Latency measurements
   - API cost tracking
   - Memory usage

3. Edge case handling
   - Network failures
   - Permission issues
   - Long recordings

**Deliverable**: Production-ready implementation

## Success Metrics

### Quantitative

- **Initialization time**: < 500ms for VAD ready (target: ~200ms after app launch)
- **Time to first result**: < 1s for interim transcript
- **End-to-end latency**: < 2s without AI, < 4s with AI
- **Chunk drop rate**: 0% (never drop speech)
- **API requests per session**: 1 transcription + 0-1 transformation (down from N chunks)

### Qualitative

- **Predictability**: System behavior is consistent and understandable
- **Observability**: User always knows what's happening
- **Reliability**: Speech is never lost or dropped
- **Appropriateness**: AI only used where it makes sense
- **Responsiveness**: Immediate feedback at every step

### User Testing Questions

1. "Did you feel confident the system was working?" (target: 90%+ yes)
2. "Did you notice any speech being missed?" (target: 0% yes)
3. "Was it clear what the system was doing at each step?" (target: 80%+ yes)
4. "Did the results meet your expectations?" (target: 90%+ yes)
5. "Would you use this regularly?" (target: 85%+ yes)

## Migration Strategy

### Backward Compatibility

- Keep existing AudioManager API
- SessionManager used internally
- Gradual migration of code

### Feature Flag

```swift
// Settings.swift
@UserDefault("useNewDictationFlow", defaultValue: false)
var useNewDictationFlow: Bool

// AudioManager.swift
func startRecording() {
    if Settings.shared.useNewDictationFlow {
        // New SessionManager path
        sessionManager.startSession()
    } else {
        // Legacy path
        continueStartRecording()
    }
}
```

### Rollout Plan

1. **Week 1-3**: Implement behind feature flag (disabled by default)
2. **Week 4**: Internal testing with flag enabled
3. **Week 5**: Beta testing with select users
4. **Week 6**: Enable for 10% of users (gradual rollout)
5. **Week 7**: Enable for 50% of users (monitor metrics)
6. **Week 8**: Enable for 100% of users
7. **Week 9**: Remove feature flag and legacy code

## Conclusion: From Awkward to Elegant

The current flow is awkward because it violates user mental models and mixes abstraction levels. The solution isn't incremental fixes - it's a fundamental re-architecture around these principles:

1. **User control is primary** (fn key, not VAD, controls session)
2. **System state is observable** (always show what's happening)
3. **Processing is accumulative** (never drop data)
4. **Feedback is immediate** (show progress, process at end)
5. **Intelligence is contextual** (AI only where appropriate)

This architecture transforms dictation from an unpredictable black box into a reliable, understandable tool. Users will know exactly what's happening at every moment, and the system will consistently deliver high-quality results.

The implementation is substantial but methodical. Each phase delivers value independently, allowing for testing and refinement along the way. The end result: dictation that feels natural, reliable, and professional.

---

**Document Status**: Proposed Solution (Ready for Review)
**Last Updated**: 2025-10-23
**Next Step**: Review with team, prioritize phases, begin Phase 1
