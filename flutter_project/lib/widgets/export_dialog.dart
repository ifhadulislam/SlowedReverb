import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/audio_file.dart';
import '../models/preset.dart';
import '../services/export_service.dart';
import 'glass_card.dart';

class ExportDialog extends ConsumerStatefulWidget {
  final ImportedAudioFile sourceFile;
  final AudioPreset activePreset;

  const ExportDialog({
    Key? key,
    required this.sourceFile,
    required this.activePreset,
  }) : super(key: key);

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> with SingleTickerProviderStateMixin {
  final ExportService _exportService = ExportService();
  
  String _selectedFormat = 'mp3';
  String _selectedQuality = '320k';
  
  bool _isExporting = false;
  double _progress = 0.0;
  String? _finalPath;
  String? _errorMessage;

  late AnimationController _doneAnimController;

  final List<String> _formats = ['mp3', 'wav', 'aac', 'flac', 'ogg'];
  final List<String> _qualities = ['128k', '192k', '256k', '320k', 'lossless'];

  @override
  void initState() {
    super.initState();
    _doneAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _doneAnimController.dispose();
    super.dispose();
  }

  Future<void> _startExport() async {
    setState(() {
      _isExporting = true;
      _progress = 0.0;
      _errorMessage = null;
    });

    try {
      final Directory docDir = await getApplicationDocumentsDirectory();
      final String safeName = widget.sourceFile.name.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final String outName = "slowed_${widget.activePreset.speed}_reverb_${safeName.split('.').first}.$_selectedFormat";
      final String fullOutPath = "${docDir.path}/$outName";

      await _exportService.exportAudio(
        srcFile: widget.sourceFile,
        preset: widget.activePreset,
        format: _selectedFormat,
        quality: _selectedQuality,
        outputPath: fullOutPath,
        onProgress: (p) {
          setState(() {
            _progress = p;
          });
        },
        onCompleted: (path) {
          setState(() {
            _isExporting = false;
            _finalPath = path;
          });
          _doneAnimController.forward();
        },
        onError: (err) {
          setState(() {
            _isExporting = false;
            _errorMessage = err;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isExporting = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _shareTrack() {
    if (_finalPath != null) {
      Share.shareXFiles([XFile(_finalPath!)], text: 'Created with Slowed Reverb Studio 🎧');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: GlassCard(
        blur: 25,
        fillOpacity: 0.12,
        borderOpacity: 0.20,
        padding: const EdgeInsets.all(24),
        borderRadius: const BorderRadius.all(Radius.circular(30)),
        child: Container(
          width: double.infinity,
          maxWidth: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "EXPORT TRACK",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  if (!_isExporting)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const SizedBox(height: 15),

              if (!_isExporting && _finalPath == null && _errorMessage == null) ...[
                // Formatting selectors
                const Text("OUTPUT FORMAT", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _formats.map((fmt) {
                    final isSelected = _selectedFormat == fmt;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedFormat = fmt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF00F2FE).withOpacity(0.15) : Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF00F2FE) : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          fmt.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Bitrate settings
                const Text("QUALITY PROFILE", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _qualities.map((qual) {
                    final isSelected = _selectedQuality == qual;
                    // Disable bitrate options for high-fidelity lossless formats
                    final isWavOrFlac = _selectedFormat == 'wav' || _selectedFormat == 'flac';
                    final isOptionMuted = isWavOrFlac && qual != 'lossless';
                    final finalSelected = isWavOrFlac ? (qual == 'lossless') : isSelected;

                    return GestureDetector(
                      onTap: isOptionMuted ? null : () => setState(() => _selectedQuality = qual),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: finalSelected ? const Color(0xFF9B51E0).withOpacity(0.15) : Colors.white10.withOpacity(isOptionMuted ? 0.02 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: finalSelected ? const Color(0xFF9B51E0) : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          qual.toUpperCase(),
                          style: TextStyle(
                            color: isOptionMuted ? Colors.white30 : (finalSelected ? Colors.white : Colors.white60),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 30),

                // Speed summary card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, color: Color(0xFF00F2FE), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Processing speed set to ${widget.activePreset.speed.toStringAsFixed(2)}x and Reverb Wet amount to ${(widget.activePreset.reverbWet * 100).toInt()}%. Output includes high-fidelity sub-bass boost filters.",
                          style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // Action buttons
                ElevatedButton(
                  onPressed: _startExport,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    "COMPILE & SAVE",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ] else if (_isExporting) ...[
                // Rendering state
                const SizedBox(height: 10),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 110,
                        width: 110,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 4,
                          color: const Color(0xFF00F2FE),
                          backgroundColor: Colors.white10,
                        ),
                      ),
                      Text(
                        "${(_progress * 100).toInt()}%",
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  "ENCODING HIGH-FIDELITY TRACK...",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Using isolated background processes. Your phone's UI is running smoothly.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white30, fontSize: 10),
                ),
              ] else if (_finalPath != null) ...[
                // Complete State
                const SizedBox(height: 10),
                Center(
                  child: ScaleTransition(
                    scale: CurvedAnimation(parent: _doneAnimController, curve: Curves.elasticOut),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.greenAccent,
                      size: 90,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "EXPORT SUCCESSFUL!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  "Saved to: .../${_finalPath!.split('/').last}",
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                          side: const BorderSide(color: Colors.white30),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("CLOSE", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _shareTrack,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                          backgroundColor: const Color(0xFF00F2FE),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share, color: Colors.black, size: 16),
                            SizedBox(width: 6),
                            Text("SHARE", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              ] else if (_errorMessage != null) ...[
                // Failure state
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 70),
                const SizedBox(height: 15),
                const Text(
                  "COMPILE FAILURE",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: () => setState(() => _errorMessage = null),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                  child: const Text("RETRY", style: TextStyle(color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
