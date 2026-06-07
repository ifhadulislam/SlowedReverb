import 'dart:io';

class ImportedAudioFile {
  final String path;
  final String name;
  final int sizeInBytes;
  final Duration duration;
  final int? sampleRate; // Hz
  final int? bitrate;    // kbps
  final String format;   // mp3, wav, flac, etc
  final String? artworkPath; // Extracted thumbnail artwork if any

  ImportedAudioFile({
    required this.path,
    required this.name,
    required this.sizeInBytes,
    required this.duration,
    this.sampleRate,
    this.bitrate,
    required this.format,
    this.artworkPath,
  });

  String get sizeString {
    double sizeInMb = sizeInBytes / (1024 * 1024);
    if (sizeInMb >= 1.0) {
      return "${sizeInMb.toStringAsFixed(2)} MB";
    } else {
      double sizeInKb = sizeInBytes / 1024;
      return "${sizeInKb.toStringAsFixed(1)} KB";
    }
  }

  String get durationString {
    int minutes = duration.inMinutes;
    int seconds = duration.inSeconds % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  String get sampleRateString {
    if (sampleRate == null) return "Unknown";
    return "${(sampleRate! / 1000).toStringAsFixed(1)} kHz";
  }

  String get bitrateString {
    if (bitrate == null) return "Unknown";
    return "$bitrate kbps";
  }

  File get file => File(path);

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'sizeInBytes': sizeInBytes,
      'durationMs': duration.inMilliseconds,
      'sampleRate': sampleRate,
      'bitrate': bitrate,
      'format': format,
      'artworkPath': artworkPath,
    };
  }

  factory ImportedAudioFile.fromMap(Map<String, dynamic> map) {
    return ImportedAudioFile(
      path: map['path'] as String,
      name: map['name'] as String,
      sizeInBytes: map['sizeInBytes'] as int,
      duration: Duration(milliseconds: map['durationMs'] as int),
      sampleRate: map['sampleRate'] as int?,
      bitrate: map['bitrate'] as int?,
      format: map['format'] as String,
      artworkPath: map['artworkPath'] as String?,
    );
  }
}
