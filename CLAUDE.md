# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Lint
flutter analyze

# Format code
dart format lib/ test/
```

## Architecture

**Medexplain** is a Flutter mobile app that captures audio from a doctor's explanation and processes it through a real-time speech-to-text (STT) WebSocket pipeline.

### Core Data Flow

```
AudioSource (PCM stream)
    └─> StreamSessionController (session lifecycle + reconnection)
            └─> WsTransport (WebSocket connection)
                    └─> TranscriptStore (ChangeNotifier → UI)
```

### `lib/stt/` Module

- **`models.dart`** — `AudioConfig`, `WsEvent`, `SttEvent` data classes
- **`audio_source.dart`** — Abstract `AudioSource` interface (PCM stream); `StubAudioSource` for tests
- **`ws_transport.dart`** — WebSocket wrapper; exposes connection state and events as streams
- **`stream_session_controller.dart`** — Orchestrates session lifecycle (idle → starting → streaming → ending) with exponential backoff reconnection; wires `AudioSource` to `WsTransport`
- **`transcript_store.dart`** — `ChangeNotifier` that accumulates `SttEvent`s and notifies UI listeners
- **`translation_store.dart`** — Stub for future translation features (not yet implemented)

### State Management

Uses Flutter's built-in `ChangeNotifier` pattern. `TranscriptStore` is the primary state holder; UI widgets subscribe to it via `ListenableBuilder` or `Provider`.

### Key Dependencies

| Package | Version | Purpose |
|---|---|---|
| `record` | ^6.2.0 | Audio capture from device microphone |
| `web_socket_channel` | ^3.0.3 | WebSocket STT backend connection |
| `path_provider` | ^2.1.5 | App documents directory access |

### Android Configuration

The Android build uses Kotlin DSL (`build.gradle.kts`). Flutter SDK integration is handled via the Flutter Gradle plugin declared in `android/settings.gradle.kts`.
