# Dictly v1.4.1

## Performance Optimization Release

Faster dictate→paste flow with reduced latency and improved VAD reliability.

### Performance Improvements

**Dictate→Paste Speed (~700ms faster)**
- Instant fn key response (removed 10ms dispatch delay)
- Faster Apple SpeechAnalyzer (removed 500ms artificial delay)
- Optimized async pipeline (removed Task spawning overhead)
- Fixed VAD initialization race condition

**Technical Changes**
- Remove DispatchQueue.main.async from keyboard handling
- Convert transcription methods to direct async
- Proper VAD initialization await before startListening
- Version management with single source of truth (Version.swift)

---

# Dictly v1.4.0

## Enhanced On-Device & Streaming Improvements

Optimized transcription modes, native download status, and storage management.

### What's New

**Optimized Transcription Modes**
- **Apple Batch Mode**: Complete text with all refinements for better quality
- **Parakeet Streaming**: Real-time text with VAD for immediate feedback
- **Smart Routing**: Each provider uses its optimal processing mode

**Native Download UI**
- **Menu Bar Status**: See download progress in status bar dropdown
- **Minimalist Design**: Non-intrusive, macOS-native implementation
- **Automatic Hide**: Status appears only during downloads

**Storage Management**
- **Clear Models**: Remove downloaded models from General settings
- **Free Space**: Reclaim ~600MB when needed
- **Auto Re-download**: Models download automatically when next needed

### Transcription Mode Details

| Provider | Mode | During Recording | Quality | Use Case |
|----------|------|------------------|---------|----------|
| Parakeet + VAD | Streaming | Text appears as you speak | Per-chunk | Immediate feedback |
| Parakeet | Batch | Silent | Complete text | Standard use |
| Apple | Batch | Silent | All refinements | Best quality |
| Cloud APIs | Batch | Silent | Complete text | Standard use |

### Quick Actions

**Clear Downloaded Models:**
1. Settings → General → Storage
2. Click "Clear Models..."
3. Confirm deletion
4. Models re-download on next use

**Monitor Downloads:**
1. Click menu bar icon
2. See "Downloading [model name]..." at top
3. Status disappears when complete

### Technical Changes

**Apple SpeechAnalyzer:**
- Changed from streaming to batch mode
- Captures all punctuation refinements
- Better quality from complete context
- Matches Parakeet batch behavior

**Parakeet + VAD:**
- Real-time streaming mode enabled
- Speech chunks transcribed immediately
- Text appears during recording
- ~110x RTF on Apple Silicon

**Download Status:**
- NSMenuItem in menu bar dropdown
- Show/hide on download events
- Non-blocking, native UX
- Background notifications preserved

### Breaking Changes

None - all existing functionality enhanced.

---

**Previous Release:** [v1.3.0 - Parakeet Integration](https://github.com/yourusername/dictly/releases/tag/v1.3.0)

---

# Dictly v1.3.0

## Parakeet CoreML Integration - Multilingual On-Device Transcription

Complete privacy with ANE-accelerated multilingual speech recognition for macOS 14+.

### What's New

**Parakeet (On-Device) Transcription (macOS 14+)**
- **25 European Languages**: Multilingual support without cloud APIs
- **ANE-Accelerated**: ~110x real-time factor on M4 Pro, runs on Apple Neural Engine
- **100% Private**: Audio never leaves your Mac - complete offline transcription
- **No API Key Required**: Zero setup, zero cost, works immediately
- **Automatic Model Download**: Downloads 600MB model on first use
- **Works Offline**: No internet connection required
- **Superior Accuracy**: Average WER 11.97%, English 1.93% (LibriSpeech)

**Provider Comparison**

| Feature | Parakeet (On-Device) | Apple (On-Device) | Cloud APIs |
|---------|---------------------|-------------------|------------|
| Availability | macOS 14+ | macOS 26+ | All macOS |
| Privacy | 100% local | 100% local | Cloud |
| API Key | Not required | Not required | Required |
| Offline | ✅ Yes | ✅ Yes | ❌ No |
| Languages | 25 European | macOS supported | 90+ |
| Acceleration | ANE | ANE | N/A |
| Speed | ~110x RTF | Local processing | Network-dependent |

**Supported Languages (Parakeet):**
English, French, German, Italian, Spanish, Portuguese, Russian, Ukrainian, Polish, Czech, Dutch, Danish, Swedish, Norwegian, Finnish, Romanian, Bulgarian, Croatian, Slovak, Slovenian, Estonian, Latvian, Lithuanian, Greek, Hungarian

### Quick Start with Parakeet

**macOS 14.0+ users:**
1. Settings → Dictation → Service → "Parakeet (On-Device)"
2. First use downloads model automatically (~600MB)
3. Hold fn → speak → transcription appears instantly
4. Works completely offline, no API key needed

### Technical Details

**Parakeet Implementation:**
- FluidAudio Swift framework integration
- FastConformer-TDT architecture (600M parameters)
- ANE-optimized CoreML model
- 16kHz mono Float32 audio input
- Batch transcription with confidence scores
- Automatic model caching and management

### Breaking Changes

None - all existing functionality preserved.

### Known Issues

None reported.

---

**Previous Release:** [v1.2.0 - On-Device & VAD](https://github.com/yourusername/dictly/releases/tag/v1.2.0)

---

# Dictly v1.2.0

## On-Device Transcription & Smart Voice Detection

Complete privacy with 100% on-device speech recognition, plus intelligent voice activity detection for cloud APIs.

### What's New

**Apple (On-Device) Transcription (macOS 26+)**
- **100% Private**: Audio never leaves your Mac - complete offline transcription
- **No API Key Required**: Zero setup, zero cost, works immediately
- **Automatic Language Models**: Downloads speech models on first use
- **Offline Operation**: Works without internet connection
- **Real-Time Results**: Partial transcription as you speak
- **Native Integration**: Leverages Apple's SpeechAnalyzer framework

**Smart Voice Detection (VAD)**
- **Intelligent Recording**: Automatically detects when you're speaking
- **Real-Time Streaming**: Transcription starts during recording, not after
- **Cost Optimization**: Only sends speech to APIs, ignoring silence
- **Configurable Sensitivity**: Adjust detection threshold to your environment
- **Customizable Timing**: Fine-tune speech duration and silence timeout

**User Interface Improvements**
- Right-aligned dropdown controls for visual consistency
- Provider-specific information banners
- Conditional UI based on selected provider
- Streamlined settings organization

### Quick Start with On-Device Transcription

**macOS 26.0+ users:**
1. Settings → Dictation → Service → "Apple (On-Device)"
2. First use downloads language model automatically
3. Hold fn → speak → transcription appears instantly
4. Works completely offline, no API key needed

### Smart Voice Detection Setup

**Cloud API users (Groq/OpenAI):**
1. Settings → Dictation → Enable Smart Recording
2. Adjust sensitivity slider (Low ← → High)
3. Set minimum speech duration (0.1s - 1.0s)
4. Set silence timeout (0.5s - 3.0s)
5. Hold fn once → speak freely → automatic stop on silence

### Provider Comparison

| Feature | Apple (On-Device) | Groq Cloud | OpenAI Cloud |
|---------|-------------------|------------|--------------|
| Privacy | 100% local | Cloud | Cloud |
| API Key | Not required | Required | Required |
| Offline | ✅ Yes | ❌ No | ❌ No |
| Cost | Free | ~$0.01/min | Per token |
| Speed | Local processing | Ultra-fast | Fast |
| Languages | macOS supported | 90+ | 50+ |

### Technical Details

**On-Device Implementation:**
- SpeechAnalyzer with SpeechTranscriber
- `reportingOptions: [.volatileResults]` for real-time results
- `SpeechAnalyzer.bestAvailableAudioFormat()` for optimal performance
- Automatic language model management via AssetInventory
- Concurrent result consumption with async/await

**VAD Implementation:**
- Silero VAD neural network (1.8MB model)
- Core ML acceleration on Apple Silicon
- ~1ms processing per 30ms audio chunk
- 96%+ accuracy in speech detection
- Graceful fallback when FluidAudio unavailable

### Breaking Changes

None - all existing functionality preserved.

### Known Issues

None reported.

---

**Previous Release:** [v1.1.0 - Local AI Model Support](https://github.com/yourusername/dictly/releases/tag/v1.1.0)

---

All existing Groq, OpenAI, and local AI enhancement features work exactly as before.
