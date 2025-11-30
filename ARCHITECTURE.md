# Omri Architecture

Detailed technical architecture diagrams for developers.

## Cross-Platform Code Sharing

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

## Service Layer

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

## Audio Processing Pipeline

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

## Terminal Architecture (iOS)

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

## Settings & State Management

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
