# Dictly v1.1.0

## Local AI Model Support

Run AI text enhancement completely offline with your own models.

### What's New

- **Local AI Integration**: Use Ollama, LM Studio, or any OpenAI-compatible service
- **No API Keys Required**: Local models work offline without internet connection  
- **Custom Models**: Input any model name your local service supports
- **Simple Setup**: Pre-configured for Ollama with easy base URL configuration

### Quick Start with Ollama

1. Install [Ollama](https://ollama.com): `ollama pull llama3.2`
2. In Dictly: AI Polish → Provider → "OpenAI Compatible"
3. Model: `llama3.2`
4. Hold fn+shift → speak → get enhanced text offline

### For LM Studio Users

1. Provider: "OpenAI Compatible"
2. Base URL: `http://localhost:1234/v1/chat/completions`
3. Model: Your loaded model name

All existing Groq and OpenAI settings work exactly as before.