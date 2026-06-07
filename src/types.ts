export interface AppPreset {
  id: string;
  name: string;
  description: string;
  speed: number;
  pitch: number;
  reverbWet: number;
  bassBoost: number;
  isCustom?: boolean;
}

export interface WebImportedFile {
  name: string;
  size: number;
  type: string;
  duration: number; // in seconds
  sampleRate: number;
  bitrate?: number;
  audioBuffer: AudioBuffer | null;
}

export const KNOWN_PRESETS: AppPreset[] = [
  {
    id: 'slowed_reverb',
    name: 'Slowed + Reverb',
    description: 'The iconic lofi sound: relaxed tape slowdown paired with wide hall reverberation.',
    speed: 0.82,
    pitch: 0.82,
    reverbWet: 0.60,
    bassBoost: 0.35,
  },
  {
    id: 'night_drive',
    name: 'Night Drive',
    description: 'Enveloping sub-bass and smooth reflections optimal for highway cruising.',
    speed: 0.88,
    pitch: 0.88,
    reverbWet: 0.50,
    bassBoost: 0.55,
  },
  {
    id: 'deep_bass',
    name: 'Deep Bass Boost',
    description: 'Unleash full sub-frequencies while keeping mid-vocal fidelity pristine.',
    speed: 0.85,
    pitch: 0.85,
    reverbWet: 0.30,
    bassBoost: 0.90,
  },
  {
    id: 'dreamy',
    name: 'Dreamy Space',
    description: 'Infinite shimmering cave dimensions. Warm slow speed with long decay trails.',
    speed: 0.78,
    pitch: 0.80,
    reverbWet: 0.85,
    bassBoost: 0.20,
  },
  {
    id: 'vintage',
    name: 'Vintage Vinyl',
    description: 'Nostalgic resonance resembling dusty, low-fidelity analog vinyl grooves.',
    speed: 0.95,
    pitch: 0.93,
    reverbWet: 0.40,
    bassBoost: 0.15,
  },
];
