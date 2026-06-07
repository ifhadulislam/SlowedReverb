class AudioPreset {
  final String id;
  final String name;
  final String description;
  final double speed;      // 0.50 to 1.50
  final double pitch;      // 0.50 to 1.50
  final double reverbWet;  // 0.0 to 1.0 (0% to 100%)
  final double bassBoost;  // 0.0 to 1.0 (0% to 100%)
  final bool isCustom;

  const AudioPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.speed,
    required this.pitch,
    required this.reverbWet,
    required this.bassBoost,
    this.isCustom = false,
  });

  // Factory constructor for custom presets
  factory AudioPreset.custom({
    required String id,
    required String name,
    required double speed,
    required double pitch,
    required double reverbWet,
    required double bassBoost,
  }) {
    return AudioPreset(
      id: id,
      name: name,
      description: "Custom user-generated preset",
      speed: speed,
      pitch: pitch,
      reverbWet: reverbWet,
      bassBoost: bassBoost,
      isCustom: true,
    );
  }

  // Common built-in presets
  static const List<AudioPreset> builtInPresets = [
    AudioPreset(
      id: 'slowed_reverb',
      name: 'Slowed + Reverb',
      description: 'The classic aesthetic sound: slowed tape rate with spacious studio reverb.',
      speed: 0.85,
      pitch: 0.85,
      reverbWet: 0.65,
      bassBoost: 0.30,
    ),
    AudioPreset(
      id: 'night_drive',
      name: 'Night Drive',
      description: 'Deep, enveloping vibes ideal for late-night cruising. Heavy reverb, moderate slowdown.',
      speed: 0.90,
      pitch: 0.90,
      reverbWet: 0.55,
      bassBoost: 0.50,
    ),
    AudioPreset(
      id: 'deep_bass',
      name: 'Deep Bass Boost',
      description: 'Maximum bass amplification with high sub-bass resonance and slow heavy pitch.',
      speed: 0.88,
      pitch: 0.88,
      reverbWet: 0.35,
      bassBoost: 0.85,
    ),
    AudioPreset(
      id: 'dreamy',
      name: 'Dreamy Space',
      description: 'Extreme ethereal reverb environment that sounds like floating in an infinite cave.',
      speed: 0.80,
      pitch: 0.85,
      reverbWet: 0.85,
      bassBoost: 0.20,
    ),
    AudioPreset(
      id: 'vintage',
      name: 'Vintage Vinyl',
      description: 'Classic warmth resembling dusty vinyl tape with low-fidelity tape decay simulation.',
      speed: 0.95,
      pitch: 0.93,
      reverbWet: 0.40,
      bassBoost: 0.15,
    ),
  ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'speed': speed,
      'pitch': pitch,
      'reverbWet': reverbWet,
      'bassBoost': bassBoost,
      'isCustom': isCustom,
    };
  }

  factory AudioPreset.fromJson(Map<String, dynamic> json) {
    return AudioPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      speed: (json['speed'] as num).toDouble(),
      pitch: (json['pitch'] as num).toDouble(),
      reverbWet: (json['reverbWet'] as num).toDouble(),
      bassBoost: (json['bassBoost'] as num).toDouble(),
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  AudioPreset copyWith({
    String? name,
    double? speed,
    double? pitch,
    double? reverbWet,
    double? bassBoost,
  }) {
    return AudioPreset(
      id: id,
      name: name ?? this.name,
      description: description,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      reverbWet: reverbWet ?? this.reverbWet,
      bassBoost: bassBoost ?? this.bassBoost,
      isCustom: isCustom,
    );
  }
}
