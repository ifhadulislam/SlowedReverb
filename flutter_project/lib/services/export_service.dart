import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../models/audio_file.dart';
import '../models/preset.dart';
import 'audio_processor_service.dart';

class ExportService {
  /// Renders and exports the full-length audio file.
  /// 
  /// Triggers [onProgress] callback with double (0.0 to 1.0) and [onCompleted] with path.
  Future<void> exportAudio({
    required ImportedAudioFile srcFile,
    required AudioPreset preset,
    required String format, // 'mp3', 'wav', 'aac', 'flac', 'ogg'
    required String quality, // '128k', '192k', '256k', '320k', 'lossless'
    required String outputPath,
    required Function(double progress) onProgress,
    required Function(String outPath) onCompleted,
    required Function(String errorMessage) onError,
  }) async {
    try {
      final String filters = AudioProcessorService.buildFFmpegFilterGraph(
        speed: preset.speed,
        pitch: preset.pitch,
        reverbWet: preset.reverbWet,
        bassBoost: preset.bassBoost,
        originalSampleRate: srcFile.sampleRate ?? 44100,
      );

      // Format & codec settings
      String codecArgs = "";
      switch (format.toLowerCase()) {
        case 'mp3':
          codecArgs = "-c:a libmp3lame ";
          if (quality == 'lossless') {
            codecArgs += "-b:a 320k"; // Max quality MP3
          } else {
            codecArgs += "-b:a $quality";
          }
          break;
        case 'wav':
          codecArgs = "-c:a pcm_s16le"; // Standard 16-bit PCM (Lossless WAV)
          break;
        case 'aac':
          codecArgs = "-c:a aac ";
          if (quality == 'lossless') {
            codecArgs += "-b:a 320k";
          } else {
            codecArgs += "-b:a $quality";
          }
          break;
        case 'flac':
          codecArgs = "-c:a flac"; // Native lossless FLAC compression
          break;
        case 'ogg':
          codecArgs = "-c:a libvorbis ";
          if (quality == 'lossless') {
            codecArgs += "-b:a 256k";
          } else {
            codecArgs += "-b:a $quality";
          }
          break;
        default:
          codecArgs = "-c:a copy";
          break;
      }

      // Preserve metadata & artwork
      // -map_metadata 0 copy global metadata (ID3 tags like Title, Artist, Album)
      // -map 0:v? -c:v copy copies video stream (Album Art cover) if present
      // -map 0:a targeting the audio stream
      final String artworkArgs = "-map 0:a -map 0:v? -c:v copy -map_metadata 0";

      // Final FFmpeg arguments
      final String command = "-y -i \"${srcFile.path}\" -filter_complex \"$filters\" $artworkArgs $codecArgs \"$outputPath\"";

      // Register high-precision progress update callbacks
      // Duration in ms helps us determine progress completion ratio
      double totalDurationMs = srcFile.duration.inMilliseconds.toDouble();
      if (totalDurationMs <= 0) totalDurationMs = 180000; // Mock safety barrier

      FFmpegKitConfig.enableStatisticsCallback((stats) {
        final int timeInMs = stats.getTime();
        if (timeInMs > 0) {
          double progressPercent = timeInMs / totalDurationMs;
          if (progressPercent > 1.0) progressPercent = 1.0;
          if (progressPercent < 0.0) progressPercent = 0.0;
          onProgress(progressPercent);
        }
      });

      FFmpegKit.executeAsync(command, (session) async {
        final returnCode = await session.getReturnCode();
        FFmpegKitConfig.enableStatisticsCallback(null); // Clear callbacks

        if (ReturnCode.isSuccess(returnCode)) {
          onCompleted(outputPath);
        } else {
          final failLog = await session.getAllLogsAsString();
          onError("FFmpeg export failed details:\n$failLog");
        }
      });
    } catch (e) {
      onError(e.toString());
    }
  }
}
