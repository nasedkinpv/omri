# Privacy Policy

**Last updated: July 7, 2026**

Omri is a voice dictation app for macOS and iOS. It is built to be private by default: transcription runs on your device, and the developer operates no servers and collects no data about you.

## What Omri does with your data

**Microphone / audio.** When you start dictation, Omri records your voice to transcribe it into text. By default, transcription runs entirely **on your device** (using the on-device Nemotron or Apple speech models) and your audio never leaves your device.

**Cloud transcription (optional).** If you explicitly choose a cloud provider (Groq, OpenAI, or a custom endpoint) in Settings, your audio and the resulting text are sent to that provider using an API key **you** supply, solely to perform the transcription you requested. This data is handled under that provider's privacy policy:
- Groq: https://groq.com/privacy-policy/
- OpenAI: https://openai.com/policies/privacy-policy/

Omri does not route this through any server of ours — the request goes directly from your device to the provider you selected.

**Transcribed text.** The text produced from your speech is inserted into the app you are using (or placed on your clipboard). Omri does not store, log, or transmit your transcripts anywhere else.

**Credentials.** API keys and, if you use the SSH terminal feature, SSH passwords are stored locally in your device's Keychain. They are never sent anywhere except to the service they authenticate.

**Accessibility (macOS).** With your permission, Omri uses the macOS Accessibility API only to insert your transcribed text at the cursor in the app you are actively using. It does not read your screen or observe other apps.

## What Omri does NOT do

- No analytics, telemetry, tracking, or advertising.
- No user accounts and no servers operated by the developer.
- No collection or sale of personal data.
- Temporary audio files created during processing are deleted afterward.

## Children

Omri is not directed at children and collects no personal information from anyone.

## Changes

If this policy changes, the updated version will be posted at this URL with a new date above.

## Contact

Questions or requests: open an issue at https://github.com/nasedkinpv/omri/issues

Omri is open source; you can inspect exactly how it handles data at https://github.com/nasedkinpv/omri
