# VoiceScribe Simplistic

A minimal macOS menubar app for voice-to-text input — no LLM, no frills. Hold the **Right Option** key to record, release to transcribe — text is injected directly into any focused input field.

This is the stripped-down version of [VoiceScribe](https://github.com/alexmercertomoki/voiceScribeWithLLM), with all LLM refinement code removed for maximum simplicity and reliability.

## Features

- **Hold Right Option** → record voice
- **Release** → Apple Speech Recognition transcribes and injects text into the active field
- **Multi-language support**: 简体中文, English, 繁體中文, 日本語, 한국어
- **Live waveform overlay** with spring animations while recording
- **Menubar app** — runs silently in the background, no Dock icon
- **No LLM dependency** — pure Apple Speech Recognition, works offline
- **Ad-hoc signed** — no Apple Developer account required

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (arm64)
- Xcode Command Line Tools (`xcode-select --install`)

## Build & Install

```bash
# Build
make build

# Install to /Applications
make install

# Launch
open /Applications/VoiceScribe.app
```

## Permissions Required

On first launch, grant the following in **System Settings → Privacy & Security**:

| Permission | Purpose |
|---|---|
| Microphone | Record voice input |
| Speech Recognition | Transcribe audio via Apple's on-device/cloud API |
| Accessibility | Monitor the global Right Option key press |

## Project Structure

```
Sources/VoiceScribe/
├── main.swift                     # App entry point
├── AppDelegate.swift              # Menubar setup, language selection
├── AudioRecorder.swift            # AVAudioEngine recording + RMS metering
├── SpeechRecognizer.swift         # Apple Speech Recognition + text injection
├── RoKeyMonitor.swift             # Global Right Option key event tap
├── OverlayWindowController.swift  # Floating capsule overlay UI
├── WaveformView.swift             # Animated waveform bars (CVDisplayLink)
├── TextInjector.swift             # CGEvent-based text injection
└── Resources/
    ├── Info.plist
    └── AppIcon.icns
```

## Difference from VoiceScribe (Full Version)

| Feature | VoiceScribe | VoiceScribe Simplistic |
|---|---|---|
| Apple Speech Recognition | ✅ | ✅ |
| Multi-language | ✅ | ✅ |
| Waveform overlay | ✅ | ✅ |
| LLM Refinement | ✅ | ❌ |
| Settings window | ✅ | ❌ |

## License

MIT
