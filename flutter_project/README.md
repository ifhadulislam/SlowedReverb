# Slowed Reverb Studio (Flutter Version) 🎧

Slowed Reverb Studio is a physics-informed audio mixing application built with **Flutter**, featuring real-time audio previews, detailed track analysis, and high-fidelity, dual-channel background exporting. It utilizes **Riverpod** for declarative state management, **just_audio** for playback, and **ffmpeg_kit_flutter_new** to run high-performance background audio engineering filters.

---

## Technical Specifications & Stack
* **Framework:** Flutter stable (v3.0.0+)
* **State Management:** Riverpod 2.0 StateNotifiers
* **Audio Playback:** `just_audio` (multi-source, streaming, buffer handling)
* **Audio DSP Engine:** `ffmpeg_kit_flutter_new` (compiled with Freeverb & multi-band PEQ equalizers)
* **Design Philosophy:** Material 3 Dark theme, customized Gaussian blurs (Glassmorphism), and neon radial accent glows.

---

## App Folder Structure

The project has been organized following Flutter clean architecture guidelines:

```
/lib
  ├── models/                 # Data class definitions
  │   ├── audio_file.dart     # Track details & sample-rates
  │   └── preset.dart         # Built-in (Dreamy, Night Drive) & User custom presets
  ├── providers/              # Declared Riverpod state engines
  │   └── audio_provider.dart # Core workspace states, controls, & update streams
  ├── services/               # Dynamic services interfacing with hardware
  │   ├── audio_processor.dart# Raw FFmpeg command generator
  │   └── export_service.dart # Non-blocking track compilers & progress channels
  ├── widgets/                # UI sub-modules
  │   ├── glass_card.dart     # Translucent container styled with backdrop filters
  │   ├── waveform_painter.dart # Canvas painter drawing deterministic soundwaves
  │   └── export_dialog.dart  # Floating dialog reporting rendering status
  ├── screens/                # Prime app viewpoints
  │   ├── home_screen.dart    # Dashboard where tracks are picked
  │   └── studio_screen.dart  # Workspace panel hosting slider mixing boards
  └── main.dart               # Theme configs and bootstrap initialization
```

---

## Getting Started

Follow these steps to run the application on your physical device or simulator:

### 1. Prerequisites
Make sure your machine has the Flutter SDK installed and environment paths matched:
```bash
flutter --version
```

### 2. Dependency Resolution
Pull the exact lock version of required dependencies outlined in `pubspec.yaml`:
```bash
flutter pub get
```

### 3. Running App
Launch on connected Android emulator or iOS simulator:
```bash
flutter run
```

---

## Features Showcase & Design Core

### Vinyl-Linked Pitch/Speed Shift
Slowed+reverb tracks sound best when speed and pitch decrease together. This imitates dust tape recording plates slowed manually:
```ffmpeg
asetrate=r=44100*0.85, aresample=44100
```
This is fully configured inside `/lib/services/audio_processor.dart` and automatically applied dynamically.

### Sub-Bass Peaking EQ Boost
Enhances sub-bass depth cleanly in-range up to +14dB at 60Hz without distortion:
```ffmpeg
equalizer=f=60:width_type=h:width=50:g=10.0, bass=g=3.0
```

### Schroeder Reverb Model
Simulates vast, spacious cave or stadium reverberation using FFmpeg's `freeverb` algorithms, preserving pristine treble detail:
```ffmpeg
freeverb=roomsize=0.88:damping=0.4:wet=0.65:dry=0.55
```
