import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audio_file.dart';
import '../models/preset.dart';
import '../services/audio_processor_service.dart';

// State definitions
class StudioState {
  final ImportedAudioFile? currentFile;
  final bool isFileLoading;
  
  // Real-time slider states
  final double speed;
  final double pitch;
  final double reverbWet;
  final double bassBoost;
  
  // Audio playback states
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isBuffering;
  
  // Presets and presets cache
  final List<AudioPreset> customPresets;
  final AudioPreset? activePreset;
  
  // Preview rendering state
  final bool isRenderingPreview;
  final String? activePreviewPath;

  StudioState({
    this.currentFile,
    this.isFileLoading = false,
    this.speed = 1.0,
    this.pitch = 1.0,
    this.reverbWet = 0.0,
    this.bassBoost = 0.0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isBuffering = false,
    this.customPresets = const [],
    this.activePreset,
    this.isRenderingPreview = false,
    this.activePreviewPath,
  });

  StudioState copyWith({
    ImportedAudioFile? Function()? currentFile,
    bool? isFileLoading,
    double? speed,
    double? pitch,
    double? reverbWet,
    double? bassBoost,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isBuffering,
    List<AudioPreset>? customPresets,
    AudioPreset? Function()? activePreset,
    bool? isRenderingPreview,
    String? Function()? activePreviewPath,
  }) {
    return StudioState(
      currentFile: currentFile != null ? currentFile() : this.currentFile,
      isFileLoading: isFileLoading ?? this.isFileLoading,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      reverbWet: reverbWet ?? this.reverbWet,
      bassBoost: bassBoost ?? this.bassBoost,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isBuffering: isBuffering ?? this.isBuffering,
      customPresets: customPresets ?? this.customPresets,
      activePreset: activePreset != null ? activePreset() : this.activePreset,
      isRenderingPreview: isRenderingPreview ?? this.isRenderingPreview,
      activePreviewPath: activePreviewPath != null ? activePreviewPath() : this.activePreviewPath,
    );
  }
}

// State notifier for Studio Workspace
class StudioNotifier extends StateNotifier<StudioState> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioProcessorService _processorService = AudioProcessorService();
  Timer? _debounceTimer;
  StreamSubscription? _posSub;
  StreamSubscription? _playerSub;

  StudioNotifier() : super(StudioState()) {
    _initPlayerListeners();
  }

  void _initPlayerListeners() {
    _posSub = _audioPlayer.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _playerSub = _audioPlayer.playerStateStream.listen((playerState) {
      state = state.copyWith(
        isPlaying: playerState.playing,
        isBuffering: playerState.processingState == ProcessingState.buffering ||
                     playerState.processingState == ProcessingState.loading,
        duration: _audioPlayer.duration ?? Duration.zero,
      );
    });
  }

  /// Sets the selected audio file.
  Future<void> setAudioFile(ImportedAudioFile file) async {
    state = state.copyWith(isFileLoading: true);
    
    // Reset player state
    await _audioPlayer.stop();
    
    state = state.copyWith(
      currentFile: () => file,
      isFileLoading: false,
      position: Duration.zero,
      duration: file.duration,
    );

    // Initial silent compile preview to seed the audio player
    await _compileLivePreview(force: true);
  }

  /// Interactive controls handler
  void updateSpeed(double value) {
    state = state.copyWith(speed: value, activePreset: () => null);
    _triggerPreviewUpdate();
  }

  void updatePitch(double value) {
    state = state.copyWith(pitch: value, activePreset: () => null);
    _triggerPreviewUpdate();
  }

  void updateReverb(double value) {
    state = state.copyWith(reverbWet: value, activePreset: () => null);
    _triggerPreviewUpdate();
  }

  void updateBass(double value) {
    state = state.copyWith(bassBoost: value, activePreset: () => null);
    _triggerPreviewUpdate();
  }

  /// Select a studio preset.
  void selectPreset(AudioPreset preset) {
    state = state.copyWith(
      speed: preset.speed,
      pitch: preset.pitch,
      reverbWet: preset.reverbWet,
      bassBoost: preset.bassBoost,
      activePreset: () => preset,
    );
    _triggerPreviewUpdate(force: true);
  }

  /// Debounces slider dragging to prevent redundant heavy background rendering.
  void _triggerPreviewUpdate({bool force = false}) {
    _debounceTimer?.cancel();
    if (force) {
      _compileLivePreview();
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 650), () {
        _compileLivePreview();
      });
    }
  }

  /// Renders a temporary 10-second segment corresponding to playhead start point
  Future<void> _compileLivePreview({bool force = false}) async {
    if (state.currentFile == null) return;

    state = state.copyWith(isRenderingPreview: true);
    final currentPlayheadSec = state.position.inSeconds.toDouble();

    try {
      final tempDir = await getTemporaryDirectory();
      
      // Load preset context
      final tempPreset = AudioPreset(
        id: 'tmp',
        name: 'temp',
        description: '',
        speed: state.speed,
        pitch: state.pitch,
        reverbWet: state.reverbWet,
        bassBoost: state.bassBoost,
      );

      final outPath = await _processorService.renderPreviewSegment(
        srcFile: state.currentFile!,
        preset: tempPreset,
        startSecond: currentPlayheadSec,
        outputDir: tempDir.path,
      );

      // Cache previous file and release resource
      final oldPath = state.activePreviewPath;
      
      // Load generated preview file into player
      await _audioPlayer.setFilePath(outPath);
      
      // Resume playback cleanly if in active state
      if (state.isPlaying) {
        _audioPlayer.play();
      }

      state = state.copyWith(
        isRenderingPreview: false,
        activePreviewPath: () => outPath,
      );

      // Delete old cached files asynchronously
      if (oldPath != null && oldPath != outPath) {
        final f = File(oldPath);
        if (await f.exists()) {
          await f.delete();
        }
      }
    } catch (e) {
      state = state.copyWith(isRenderingPreview: false);
      // Fail gracefully, fall back if needed in production loggers
    }
  }

  // Playback engine controls mapped directly to audio player
  Future<void> play() async {
    if (state.currentFile == null) return;
    await _audioPlayer.play();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
    // When seeker completes, trigger updated preview at new offset
    _triggerPreviewUpdate(force: true);
  }

  Future<void> skipForward() async {
    final target = state.position + const Duration(seconds: 10);
    final maxDur = state.duration;
    if (target < maxDur) {
      await seek(target);
    }
  }

  Future<void> skipBackward() async {
    final target = state.position - const Duration(seconds: 10);
    if (target > Duration.zero) {
      await seek(target);
    } else {
      await seek(Duration.zero);
    }
  }

  /// Saves a custom preset configuration
  void saveCustomPreset(String name) {
    final newPreset = AudioPreset.custom(
      id: "custom_${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      speed: state.speed,
      pitch: state.pitch,
      reverbWet: state.reverbWet,
      bassBoost: state.bassBoost,
    );
    
    state = state.copyWith(
      customPresets: [...state.customPresets, newPreset],
      activePreset: () => newPreset,
    );
  }

  void deleteCustomPreset(String id) {
    state = state.copyWith(
      customPresets: state.customPresets.where((p) => p.id != id).toList(),
      activePreset: state.activePreset?.id == id ? () => null : () => state.activePreset,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _posSub?.cancel();
    _playerSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

// Global Provider declaration
final studioProvider = StateNotifierProvider<StudioNotifier, StudioState>((ref) {
  return StudioNotifier();
});
