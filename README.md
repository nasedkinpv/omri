<div align="center">
  <img src="brand-icon.png" alt="Omri Logo" width="120" height="120">

  # Omri

  **עמרי | om-REE** — harvesting voice into text
</div>

A native macOS and iOS app for voice transcription. Choose from 100% private on-device transcription (macOS 14+ with Parakeet, macOS 26+ with Apple), your own Groq/OpenAI API keys, or local AI models. Includes SSH terminal with voice dictation on both platforms.

## Architecture

### High-Level System Architecture

```mermaid
flowchart TB
    subgraph Input["Voice Input"]
        FN["fn key (macOS)"]
        TAP["Tap Button (iOS)"]
    end

    subgraph Audio["Audio Layer"]
        AM["AudioManager (macOS)"]
        AR["AudioRecorder (Shared)"]
        VAD["VADManager\n(Silero VAD)"]
    end

    subgraph Transcription["Transcription Providers"]
        direction LR
        PARAKEET["Parakeet CoreML\n(On-Device)"]
        APPLE["Apple SpeechAnalyzer\n(On-Device)"]
        GROQ["Groq API"]
        OPENAI["OpenAI API"]
        CUSTOM["Custom API"]
    end

    subgraph Transform["AI Enhancement"]
        TS["TransformationService"]
    end

    subgraph Output["Text Delivery"]
        PM["PasteManager"]
        TERM["Terminal"]
        CLIP["Clipboard"]
    end

    FN --> AM
    TAP --> AR
    AM --> VAD
    AM --> PARAKEET
    AM --> APPLE
    AM --> GROQ
    AM --> OPENAI
    AR --> PARAKEET
    AR --> GROQ
    AR --> OPENAI
    AR --> CUSTOM

    PARAKEET --> PM
    APPLE --> PM
    GROQ --> PM
    OPENAI --> PM
    CUSTOM --> PM

    PM --> TS
    TS --> PM
    PM --> TERM
    PM --> CLIP
```

### Cross-Platform Code Sharing

```mermaid
flowchart LR
    subgraph Shared["Shared (iOS + macOS)"]
        Models["Models\n• Settings\n• SSHConnection"]
        Services["Services\n• Transcription\n• Transformation\n• Keychain"]
        Audio["Audio\n• AudioRecorder"]
        UI["UI Components\n• FloatingControls\n• SettingsViews"]
        Terminal["Terminal\n• SSHConnectionsView"]
    end

    subgraph macOS["macOS Target"]
        AppDelegate
        AudioManager
        PasteManager
        VADManager
        AppleSpeech["AppleSpeechAnalyzer"]
        MacTerminal["TerminalWindowController"]
    end

    subgraph iOS["iOS Target"]
        OmriApp["OmriApp"]
        DictationMgr["DictationManager"]
        SSHClient["SSHClientManager"]
        iOSTerminal["TerminalSessionView"]
    end

    Shared --> macOS
    Shared --> iOS
```

### Service Layer Architecture

```mermaid
classDiagram
    class TranscriptionService {
        <<protocol>>
        +transcribe(audioData, fileName, model, language) Response
    }

    class BaseHTTPService {
        +createRequest(contentType) URLRequest
        +performRequest(request, responseType) T
    }

    class GroqTranscriptionService {
        +transcribe()
        +translate()
    }

    class OpenAITranscriptionService {
        +transcribe()
    }

    class CustomTranscriptionService {
        +transcribe()
    }

    class OnDeviceTranscriptionManager {
        <<protocol>>
        +startSession(locale) AVAudioFormat
        +feedAudio(buffer)
        +stopSession()
        +isInitialized: Bool
    }

    class ParakeetTranscriptionManager {
        +initializeModels()
        +transcribeChunk(samples) String?
    }

    class AppleSpeechAnalyzerManager {
        +finishAudioInput()
    }

    TranscriptionService <|.. GroqTranscriptionService
    TranscriptionService <|.. OpenAITranscriptionService
    TranscriptionService <|.. CustomTranscriptionService
    BaseHTTPService <|-- GroqTranscriptionService
    BaseHTTPService <|-- OpenAITranscriptionService
    BaseHTTPService <|-- CustomTranscriptionService
    OnDeviceTranscriptionManager <|.. ParakeetTranscriptionManager
    OnDeviceTranscriptionManager <|.. AppleSpeechAnalyzerManager
```

### Audio Processing Pipeline

```mermaid
sequenceDiagram
    participant User
    participant AudioManager
    participant VAD as VADManager
    participant Provider as Transcription Provider
    participant PasteManager
    participant App as Target App

    User->>AudioManager: Hold fn key
    AudioManager->>AudioManager: Start AVAudioEngine

    alt VAD Enabled
        loop Audio Chunks
            AudioManager->>VAD: processAudioBuffer
            VAD-->>VAD: Detect speech
            VAD->>Provider: Speech chunk
            Provider-->>PasteManager: Partial text
            PasteManager->>App: Stream text
        end
    else Batch Mode
        AudioManager->>AudioManager: Collect buffers
    end

    User->>AudioManager: Release fn key
    AudioManager->>Provider: Process audio
    Provider-->>PasteManager: Final text

    alt AI Enhancement (fn+shift)
        PasteManager->>PasteManager: Transform with AI
    end

    PasteManager->>App: Paste text
```

### Terminal Architecture (iOS)

```mermaid
flowchart TB
    subgraph SwiftUI["SwiftUI Layer"]
        TSV["TerminalSessionView"]
        FDC["FloatingDictationControls"]
        GR["GeometryReader"]
    end

    subgraph UIKit["UIKit Bridge"]
        ITV["iOSTerminalView\n(UIViewRepresentable)"]
        COORD["Coordinator"]
        CTA["CustomTerminalAccessory"]
    end

    subgraph SwiftTerm["SwiftTerm"]
        TV["TerminalView"]
        TVD["TerminalViewDelegate"]
    end

    subgraph SSH["SSH Layer"]
        ITM["iOSTerminalManager"]
        SCM["SSHClientManager"]
        CITADEL["Citadel SSH"]
    end

    TSV --> GR
    GR --> ITV
    ITV --> COORD
    ITV --> TV
    TV --> CTA
    ITM --> TVD
    ITM --> SCM
    SCM --> CITADEL
    TSV --> FDC
```

### Settings & State Management

```mermaid
flowchart LR
    subgraph Storage["Persistent Storage"]
        UD["UserDefaults\n(@UserDefault)"]
        KC["Keychain\n(API Keys)"]
    end

    subgraph State["Observable State"]
        Settings["Settings.shared\n(ObservableObject)"]
        TermSettings["TerminalSettings.shared"]
        ConnState["ConnectionState\n(@Observable)"]
    end

    subgraph Views["SwiftUI Views"]
        SettingsView
        DictationSettings
        TerminalView
    end

    UD <--> Settings
    KC <--> Settings
    Settings --> Views
    TermSettings --> Views
    ConnState --> Views
```

## Screenshots

<table>
<tr>
<td width="50%">

### Menu Bar
![Menu Bar](screenshots/omri_menu.png)

</td>
<td width="50%">

### Dictation Settings
![Dictation](screenshots/omri-settings-dictation.png)

</td>
</tr>
<tr>
<td>

### AI Polish
![AI Polish](screenshots/omri-settings-ai-polish.png)

</td>
<td>

### General Settings
![General](screenshots/omri-settings-general.png)

</td>
</tr>
</table>

### About
![About](screenshots/omri-settings-about.png)

## Features

### macOS
- **Hold fn key** → speak → get text anywhere
- **Hold fn + shift** → AI-enhanced text
- **100% private on-device transcription** - Parakeet (macOS 14+, 25 languages) or Apple (macOS 26+)
- **Real-time streaming** - Parakeet streaming mode shows text as you speak (~0.5s latency)
- **ANE-accelerated** - runs on Apple Neural Engine for optimal performance
- Works in any macOS app
- Cloud APIs (Groq/OpenAI) or local AI models (Ollama, LM Studio)
- Menu bar app, stays out of your way

### iOS
- **SSH Terminal** with voice dictation - speak commands directly into terminal
- **Tap-to-dictate** interface with floating controls
- **On-device transcription** - Parakeet (iOS 17+) with streaming mode
- **Real-time preview** - volatile text shows in-progress transcription
- Cloud transcription (Groq/OpenAI/Custom endpoints)
- Saved SSH connections with Keychain password storage
- Powerline/Starship support (Hack Nerd Font built-in)

### SSH Terminal (Both Platforms) — WIP
- Full SSH terminal emulation via SwiftTerm
- Voice dictation directly into terminal sessions
- Connection manager with saved profiles
- Floating dictation controls with drag positioning (iOS)
- Clear button: tap for Ctrl+U, long-press for Ctrl+L

## Quick Start

1. **Choose Your Transcription Provider**
   - **Parakeet (On-Device)** (macOS 14+): 100% private, ANE-accelerated, 25 European languages, no API key
   - **Apple (On-Device)** (macOS 26+): 100% private, native macOS, no API key, works offline
   - **Cloud**: [Groq](https://console.groq.com/keys) (free tier) or [OpenAI](https://platform.openai.com/api-keys)
   - **Local AI Enhancement**: [Ollama](https://ollama.com), LM Studio, or any OpenAI-compatible API

2. **Download & Install**
   
   **Option A: Download Release (Recommended)**
   - Go to [Releases](https://github.com/nasedkinpv/omri/releases)
   - Download latest `Omri-vX.X.X-apple-silicon.zip`
   - Extract the zip file
   - Remove quarantine: `xattr -rd com.apple.quarantine Omri.app`
   - Move `Omri.app` to Applications

   **Option B: Build from Source**
   ```bash
   git clone https://github.com/nasedkinpv/omri.git
   cd omri
   open Omri.xcodeproj
   # Build and run in Xcode
   ```

3. **Setup**
   - Grant microphone permission
   - Grant accessibility permission  
   - Configure your AI provider in settings (API key for cloud, base URL for local)
   - Start dictating!

## Usage

- **Basic**: Hold `fn` key → speak → release
- **AI Enhanced**: Hold `fn + shift` → speak → release  
- Text appears where your cursor is

## Supported Models

**Transcription:**
- Parakeet (On-Device): `parakeet-tdt-v3` (macOS 14+, 25 European languages, streaming mode, no API key)
- Apple (On-Device): Built-in model (macOS 26+, batch mode, no API key)
- Groq: `whisper-large-v3-turbo` (fast), `whisper-large-v3` (best)
- OpenAI: `whisper-1`, `nova-1-whisper`

**AI Enhancement:**
- Groq: `llama-3.3-70b-versatile`
- OpenAI: `gpt-5`, `gpt-5-mini`
- Local: Any OpenAI-compatible model (Ollama, LM Studio, etc.)

## Requirements

### macOS
- macOS 14.0+ for Parakeet on-device transcription
- macOS 26.0+ for Apple on-device transcription
- macOS 15.0+ for cloud APIs (Groq/OpenAI)
- Microphone access
- Accessibility access (for universal pasting)

### iOS
- iOS 17.0+ for Parakeet on-device transcription
- iOS 26.0+ for latest features (Liquid Glass UI)
- Microphone access
- On-device (Parakeet) or Cloud API key (Groq/OpenAI)

### General
- Internet connection (for cloud APIs only, not required for on-device)

## Privacy

- **Parakeet (On-Device)**: 100% private, audio never leaves your Mac (macOS 14+), ANE-accelerated
- **Apple (On-Device)**: 100% private, audio never leaves your Mac (macOS 26+)
- **Cloud APIs**: Audio processed via your chosen API (Groq/OpenAI)
- API keys stored securely in macOS Keychain
- No telemetry or tracking
- Audio files deleted immediately after processing

## License

MIT License - see [LICENSE](LICENSE) file.

Created by [beneric.studio](https://github.com/nasedkinpv)