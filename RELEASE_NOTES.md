# Omri v1.7.0

## Nemotron On-Device Transcription

Parakeet has been replaced by Nemotron 3.5 ASR for private on-device dictation.

### What's New

**Nemotron 3.5 ASR**

- On-device streaming transcription on macOS and iOS
- About 40 languages
- No API key needed after model download
- Works offline once cached

**Simpler Recording Pipeline**

- One shared audio recorder path on iOS
- External VAD removed
- Cloud transcription now uses one complete recording per request

**Dependency Pinning**

- FluidAudio pinned to 0.15.4
- Swift packages resolved intentionally

Existing settings keep working. The old stored “Parakeet” provider now shows Nemotron.

---

# Omri v1.6.0

## iOS Parakeet & Model Management

On-device transcription comes to iOS with real-time streaming and model download UI.

### What's New

**iOS Parakeet On-Device (iOS 17+)**

- Real-time streaming transcription on iPhone/iPad
- Volatile text preview shows words as you speak
- No API key needed, works offline
- 25 European languages supported

**Model Download UI**

- Download/clear models from Settings → Dictation
- Progress indicator during download
- Retry button on failure
- Shows "Ready" when model is available

**Volatile Text Preview**

- See in-progress transcription while speaking
- Pulsing indicator shows active recognition
- Smooth transitions between volatile and confirmed text

### Technical

- StreamingAsrManager handles iOS microphone capture
- DictationManager extended with streaming callbacks
- ModelDownloadManager integrated in settings UI
- 11k lines of outdated docs removed

---

# Omri v1.4.1

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

# Omri v1.4.0

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
