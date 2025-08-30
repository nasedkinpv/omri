<div align="center">
  <img src="brand-icon.png" alt="Dictly Logo" width="120" height="120">
  
  # Dictly
  
  **macOS voice transcription with your own API keys**
</div>

An alternative to expensive transcription subscriptions. Use your own Groq, OpenAI API keys, or local AI models for fast, accurate voice-to-text with optional AI enhancement.

## Screenshots

### Main Settings Interface
![Dictation Settings](screenshots/dictly_dictation.png)

### Menu Bar Integration
![Menu Bar](screenshots/dictly_menu.png)

| Additional Features | |
|---|---|
| ![General Settings](screenshots/dictly_general.png) | ![AI Enhancement](screenshots/dictly_ai.png) |

## Features

- **Hold fn key** → speak → get text anywhere
- **Hold fn + shift** → AI-enhanced text 
- Works in any macOS app
- Cloud APIs (Groq/OpenAI) or local AI models (Ollama, LM Studio)
- Menu bar app, stays out of your way

## Quick Start

1. **Choose Your AI Provider**
   - **Cloud**: [Groq](https://console.groq.com/keys) (free tier) or [OpenAI](https://platform.openai.com/api-keys)
   - **Local**: [Ollama](https://ollama.com), LM Studio, or any OpenAI-compatible API

2. **Download & Install**
   
   **Option A: Download Release (Recommended)**
   - Go to [Releases](https://github.com/nasedkinpv/dictly/releases)
   - Download latest `Dictly-vX.X.X-apple-silicon.zip`
   - Extract the zip file
   - Remove quarantine: `xattr -rd com.apple.quarantine Dictly.app`
   - Move `Dictly.app` to Applications

   **Option B: Build from Source**
   ```bash
   git clone https://github.com/nasedkinpv/dictly.git
   cd dictly
   open Dictly.xcodeproj
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
- Groq: `whisper-large-v3-turbo` (fast), `whisper-large-v3` (best)  
- OpenAI: `whisper-1`, `nova-1-whisper`

**AI Enhancement:**
- Groq: `llama-3.3-70b-versatile`
- OpenAI: `gpt-5`, `gpt-5-mini`
- Local: Any OpenAI-compatible model (Ollama, LM Studio, etc.)

## Requirements

- macOS 15.0+
- Microphone access
- Accessibility access (for universal pasting)

## Privacy

- Audio processed via your chosen API (Groq/OpenAI)
- API keys stored in macOS Keychain
- No telemetry or tracking
- Audio files deleted immediately after processing

## License

MIT License - see [LICENSE](LICENSE) file.

Created by [beneric.studio](https://github.com/nasedkinpv)