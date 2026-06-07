import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/audio_file.dart';
import '../providers/audio_provider.dart';
import '../widgets/glass_card.dart';
import 'studio_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  Future<void> _pickAudio(BuildContext context, WidgetRef ref) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowCompression: false,
      );

      if (result != null && result.files.single.path != null) {
        final platformFile = result.files.single;
        
        final importedTrack = ImportedAudioFile(
          path: platformFile.path!,
          name: platformFile.name,
          sizeInBytes: platformFile.size,
          duration: const Duration(minutes: 3, seconds: 45), // Default placeholder parsed at loading
          format: platformFile.extension?.toLowerCase() ?? 'mp3',
          sampleRate: 44100,
          bitrate: 320,
        );

        // Load into Riverpod state structure
        await ref.read(studioProvider.notifier).setAudioFile(importedTrack);

        // Transition with smooth Material page routing
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StudioScreen()),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error picking audio: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0C1B), // Midnight deep blue
              Color(0xFF060309), // True deep space black
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 30),
                // Premium Styled Logo Branding
                Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF00F2FE), Color(0xFF4FACFE), Color(0xFF9B51E0)],
                    ).createShader(bounds),
                    child: Text(
                      "SLOWED & REVERB STUDIO",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        textStyle: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    "High-Fidelity Audio Engineering Sandbox",
                    style: GoogleFonts.inter(
                      textStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.white30,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                
                const Spacer(),

                // Drag and drop glass hub
                GestureDetector(
                  onTap: () => _pickAudio(context, ref),
                  child: GlassCard(
                    blur: 20,
                    fillOpacity: 0.05,
                    borderOpacity: 0.12,
                    padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated pulse core
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00F2FE).withOpacity(0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00F2FE).withOpacity(0.20),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 45,
                            color: Color(0xFF00F2FE),
                          ),
                        ),
                        const SizedBox(height: 25),
                        Text(
                          "IMPORT TRACK TO BEGIN",
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Tap to select MP3, WAV, AAC, FLAC, OGG, or M4A",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white30,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Info spec rails
                GlassCard(
                  blur: 10,
                  fillOpacity: 0.03,
                  borderOpacity: 0.06,
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on, color: Color(0xFF9B51E0), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Hardware Accelerated DSP",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "All speed & reverb filters compile instantly using isolated multi-threaded FFmpeg. Zero UI rendering freezes.",
                              style: GoogleFonts.inter(
                                color: Colors.white30,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
