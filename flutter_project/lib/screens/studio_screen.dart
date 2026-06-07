import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/preset.dart';
import '../providers/audio_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/waveform_painter.dart';
import '../widgets/export_dialog.dart';

class StudioScreen extends ConsumerWidget {
  const StudioScreen({Key? key}) : super(key: key);

  void _showExportDialog(BuildContext context, WidgetRef ref, StudioState state) {
    if (state.currentFile == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ExportDialog(
          sourceFile: state.currentFile!,
          activePreset: AudioPreset(
            id: 'export',
            name: 'Studio Render',
            description: '',
            speed: state.speed,
            pitch: state.pitch,
            reverbWet: state.reverbWet,
            bassBoost: state.bassBoost,
          ),
        );
      },
    );
  }

  void _showSavePresetDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            fillOpacity: 0.15,
            borderOpacity: 0.20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "SAVE CUSTOM PRESET",
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Preset Name (e.g. My Slowed Lounge)",
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00F2FE)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty) {
                          ref.read(studioProvider.notifier).saveCustomPreset(controller.text.trim());
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F2FE)),
                      child: const Text("SAVE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioProvider);
    final notifier = ref.read(studioProvider.notifier);

    if (state.currentFile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final track = state.currentFile!;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF07050F),
              Color(0xFF0C0913),
              Color(0xFF030107),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Controls bar
              _buildHeader(context, track),

              // Scrollable mixing workspace
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Active track info tag
                      _buildTrackInfoCard(track),
                      const SizedBox(height: 18),

                      // Floating Interactive Waveform scrubbing hub
                      _buildWaveformCard(state, notifier),
                      const SizedBox(height: 18),

                      // Audio DSP slider control panel
                      _buildDspControlsCard(state, notifier),
                      const SizedBox(height: 18),

                      // Presets selector row
                      _buildPresetsCard(context, state, notifier),
                      const SizedBox(height: 25),

                      // Primary render export action
                      ElevatedButton(
                        onPressed: () => _showExportDialog(context, ref, state),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(18),
                          backgroundColor: const Color(0xFF00F2FE),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 10,
                          shadowColor: const Color(0xFF00F2FE).withOpacity(0.3),
                        ),
                        child: Text(
                          "EXPORT MASTER MASTERING",
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Column(
            children: [
              Text(
                "STUDIO INTERFACE",
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "LIVE RUNNING",
                    style: GoogleFonts.inter(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white70, size: 22),
            onPressed: () {
              // Info triggers on device specs
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrackInfoCard(dynamic track) {
    return GlassCard(
      blur: 8,
      fillOpacity: 0.04,
      borderOpacity: 0.08,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      borderRadius: BorderRadius.circular(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF9B51E0).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.music_note, color: Color(0xFF9B51E0), size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      track.format.toString().toUpperCase(),
                      style: GoogleFonts.inter(color: const Color(0xFF00F2FE), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      track.sizeString,
                      style: GoogleFonts.inter(color: Colors.white30, fontSize: 10),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      track.sampleRateString,
                      style: GoogleFonts.inter(color: Colors.white30, fontSize: 10),
                    )
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildWaveformCard(StudioState state, StudioNotifier notifier) {
    final String currentPos = _formatDuration(state.position);
    final String fullDur = _formatDuration(state.duration);

    return GlassCard(
      blur: 15,
      fillOpacity: 0.06,
      borderOpacity: 0.12,
      child: Column(
        children: [
          // Waveform element
          InteractiveWaveform(
            position: state.position,
            duration: state.duration,
            onScrub: (pos) => notifier.seek(pos),
          ),
          const SizedBox(height: 15),

          // Running playhead timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentPos,
                style: GoogleFonts.jetBrainsMono(color: const Color(0xFF00F2FE), fontSize: 12, fontWeight: FontWeight.bold),
              ),
              if (state.isRenderingPreview)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white70)),
                      const SizedBox(width: 6),
                      Text("RENDERING", style: GoogleFonts.inter(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              Text(
                fullDur,
                style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Action playback bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white70, size: 28),
                onPressed: () => notifier.skipBackward(),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: state.isPlaying ? () => notifier.pause() : () => notifier.play(),
                child: Container(
                  height: 60,
                  width: 60,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF00F2FE), Color(0xFF9B51E0)],
                    ),
                  ),
                  child: state.isBuffering
                      ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)))
                      : Icon(
                          state.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.black,
                          size: 32,
                        ),
                ),
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white70, size: 28),
                onPressed: () => notifier.skipForward(),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDspControlsCard(StudioState state, StudioNotifier notifier) {
    return GlassCard(
      blur: 15,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "EFFECT SOUND DESIGNS",
            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5),
          ),
          const SizedBox(height: 15),

          // 1. Playback speed slider
          _buildSliderCombo(
            label: "SPEED CONTROL",
            value: state.speed,
            min: 0.50,
            max: 1.50,
            unit: "x",
            activeColor: const Color(0xFF00F2FE),
            onChanged: (v) => notifier.updateSpeed(v),
          ),
          const SizedBox(height: 15),

          // 2. Pitch tuning slider
          _buildSliderCombo(
            label: "PITCH ADJUSTMENT",
            value: state.pitch,
            min: 0.50,
            max: 1.50,
            unit: "x",
            activeColor: const Color(0xFF4FACFE),
            onChanged: (v) => notifier.updatePitch(v),
          ),
          const SizedBox(height: 15),

          // 3. Reverb mix volume
          _buildSliderCombo(
            label: "REVERB AMOUNT",
            value: state.reverbWet * 100,
            min: 0,
            max: 100,
            unit: "%",
            activeColor: const Color(0xFF9B51E0),
            onChanged: (v) => notifier.updateReverb(v / 100),
          ),
          const SizedBox(height: 15),

          // 4. Sub Bass boost peq
          _buildSliderCombo(
            label: "BASS BOOST LEVEL",
            value: state.bassBoost * 100,
            min: 0,
            max: 100,
            unit: "%",
            activeColor: const Color(0xFFFF5E62),
            onChanged: (v) => notifier.updateBass(v / 100),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderCombo({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required Color activeColor,
    required Function(double v) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            Text(
              "${value.toStringAsFixed(unit == 'x' ? 2 : 0)}$unit",
              style: GoogleFonts.jetBrainsMono(color: activeColor, fontSize: 12, fontWeight: FontWeight.bold),
            )
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: activeColor,
            inactiveTrackColor: Colors.white.withOpacity(0.08),
            thumbColor: Colors.white,
            overlayColor: activeColor.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPresetsCard(BuildContext context, StudioState state, StudioNotifier notifier) {
    final presets = AudioPreset.builtInPresets;
    final customPresets = state.customPresets;

    return GlassCard(
      blur: 15,
      padding: const EdgeInsets.only(top: 15, bottom: 20, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "PRESETS PRESETS",
                style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5),
              ),
              GestureDetector(
                onTap: () => _showSavePresetDialog(context, notifier as WidgetRef), // Trick workaround or wrap dialog cleanly
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 14, color: Color(0xFF00F2FE)),
                    const SizedBox(width: 3),
                    Text(
                      "SAVE CUSTOM",
                      style: GoogleFonts.inter(color: const Color(0xFF00F2FE), fontSize: 10, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),

          // Grid style visual presets
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                ...presets.map((p) => _buildPresetButton(p, state, notifier)),
                if (customPresets.isNotEmpty)
                  ...customPresets.map((p) => _buildPresetButton(p, state, notifier, canDelete: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(AudioPreset p, StudioState state, StudioNotifier notifier, {bool canDelete = false}) {
    final bool isSelected = state.activePreset?.id == p.id ||
        (state.speed == p.speed && state.pitch == p.pitch && state.reverbWet == p.reverbWet && state.bassBoost == p.bassBoost);

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => notifier.selectPreset(p),
        onLongPress: canDelete ? () => notifier.deleteCustomPreset(p.id) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00F2FE).withOpacity(0.12) : Colors.white10,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF00F2FE) : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.name,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => notifier.deleteCustomPreset(p.id),
                  child: const Icon(Icons.close, size: 12, color: Colors.white30),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}
