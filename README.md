<div align="center">
  <img src="brand-icon.png" alt="Dictly Logo" width="120" height="120">
  
  # Dictly
  
  **macOS voice transcription with your own API keys**
</div>

An alternative to expensive transcription subscriptions. Use your own Groq or OpenAI API keys for fast, accurate voice-to-text with optional AI enhancement.

## Screenshots

### Main Settings Interface
![Dictation Settings](screenshots/screenshot_5.png)

### Menu Bar Integration
![Menu Bar](screenshots/screenshot_2.png)

| Additional Features | |
|---|---|
| ![Permissions Setup](screenshots/screenshot_3.png) | ![AI Enhancement](screenshots/screenshot_4.png) |

## Features

- **Hold fn key** → speak → get text anywhere
- **Hold fn + shift** → AI-enhanced text 
- Works in any macOS app
- Your own API keys (Groq/OpenAI)
- Menu bar app, stays out of your way

## Quick Start

1. **Get API Key**
   - [Groq](https://console.groq.com/keys) (recommended - has free tier)
   - [OpenAI](https://platform.openai.com/api-keys) 

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
   - Add your API key in settings
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