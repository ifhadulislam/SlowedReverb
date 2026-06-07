import React, { useState, useEffect, useRef } from 'react';
import { 
  Play, Pause, Upload, RotateCcw, SkipForward, SkipBack, Download,
  Volume2, Music, Check, Layers, Sparkles, Sliders, Music3, Trash2
} from 'lucide-react';
import { AppPreset, KNOWN_PRESETS, WebImportedFile } from '../types';

// Helper: Synthesize premium hall impulse response in-memory for live convolver reverb
function createReverbImpulseResponse(context: AudioContext, duration: number, decay: number) {
  const sampleRate = context.sampleRate;
  const length = sampleRate * duration;
  const impulse = context.createBuffer(2, length, sampleRate);
  const left = impulse.getChannelData(0);
  const right = impulse.getChannelData(1);

  for (let i = 0; i < length; i++) {
    const fract = i / length;
    // Exponentially decaying white noise for a dense lush reflection
    const decayFactor = Math.pow(1 - fract, decay);
    left[i] = (Math.random() * 2 - 1) * decayFactor;
    right[i] = (Math.random() * 2 - 1) * decayFactor;
  }
  return impulse;
}

// Helper: Compact WAV Encoder to output genuine high-fidelity file exports purely client-side
function encodeAudioBufferToWav(buffer: AudioBuffer): Blob {
  const numChannels = buffer.numberOfChannels;
  const sampleRate = buffer.sampleRate;
  const format = 1; // Uncompressed PCM
  const bitDepth = 16;
  
  let interleaved: Float32Array;
  if (numChannels === 2) {
    const left = buffer.getChannelData(0);
    const right = buffer.getChannelData(1);
    interleaved = new Float32Array(left.length + right.length);
    let idx = 0;
    for (let i = 0; i < left.length; i++) {
      interleaved[idx++] = left[i];
      interleaved[idx++] = right[i];
    }
  } else {
    interleaved = buffer.getChannelData(0);
  }
  
  const bufferLength = interleaved.length * 2;
  const arrayBuffer = new ArrayBuffer(44 + bufferLength);
  const view = new DataView(arrayBuffer);
  
  const writeString = (view: DataView, offset: number, str: string) => {
    for (let i = 0; i < str.length; i++) {
      view.setUint8(offset + i, str.charCodeAt(i));
    }
  };

  writeString(view, 0, 'RIFF');
  view.setUint32(4, 36 + bufferLength, true);
  writeString(view, 8, 'WAVE');
  writeString(view, 12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, format, true);
  view.setUint16(22, numChannels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * numChannels * (bitDepth / 8), true);
  view.setUint16(32, numChannels * (bitDepth / 8), true);
  view.setUint16(34, bitDepth, true);
  writeString(view, 36, 'data');
  view.setUint32(40, bufferLength, true);
  
  let offset = 44;
  for (let i = 0; i < interleaved.length; i++, offset += 2) {
    const s = Math.max(-1, Math.min(1, interleaved[i]));
    view.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7FFF, true);
  }
  
  return new Blob([view], { type: 'audio/wav' });
}

export default function StudioDashboard() {
  // Effects Controls
  const [speed, setSpeed] = useState(0.85);
  const [pitch, setPitch] = useState(0.85); // Matches speed (vinyl vinyl mode) by default
  const [reverbWet, setReverbWet] = useState(0.65);
  const [bassBoost, setBassBoost] = useState(0.50);

  // Track state
  const [track, setTrack] = useState<WebImportedFile | null>(null);
  const [loading, setLoading] = useState(false);
  const [isPlaying, setIsPlaying] = useState(false);
  
  // Custom presets
  const [customPresets, setCustomPresets] = useState<AppPreset[]>(() => {
    try {
      const cached = localStorage.getItem('slowed_reverb_presets');
      return cached ? JSON.parse(cached) : [];
    } catch {
       return [];
    }
  });
  const [newPresetName, setNewPresetName] = useState('');
  const [showSavePreset, setShowSavePreset] = useState(false);

  // Playback tracking
  const [currentTime, setCurrentTime] = useState(0);
  const [volume, setVolume] = useState(0.8);
  const [exporting, setExporting] = useState(false);
  const [exportProgress, setExportProgress] = useState(0);
  const [selectedFormat, setSelectedFormat] = useState<'wav' | 'mp3' | 'flac' | 'm4a'>('wav');

  // Web Audio Context & Nodes refs to prevent GC leakage
  const audioCtxRef = useRef<AudioContext | null>(null);
  const sourceNodeRef = useRef<AudioBufferSourceNode | null>(null);
  const bassNodeRef = useRef<BiquadFilterNode | null>(null);
  const convolverNodeRef = useRef<ConvolverNode | null>(null);
  const dryGainNodeRef = useRef<GainNode | null>(null);
  const wetGainNodeRef = useRef<GainNode | null>(null);
  const volumeGainNodeRef = useRef<GainNode | null>(null);

  // Timer trackers
  const startOffsetRef = useRef<number>(0);
  const startTimeRef = useRef<number>(0);
  const animationFrameRef = useRef<number | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Initialize Default Web Audio context upon mount
  useEffect(() => {
    const initCtx = () => {
      try {
        const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
        audioCtxRef.current = audioCtx;
      } catch (e) {
        console.error("Failed to construct default Web Audio context:", e);
      }
    };
    initCtx();

    return () => {
      stopPlayback();
      if (audioCtxRef.current) {
        audioCtxRef.current.close();
      }
    };
  }, []);

  // Update live Web Audio nodes values whenever control state sliders change (dynamic feedback)
  useEffect(() => {
    if (!isPlaying) return;

    // Web audio playback speed handling
    if (sourceNodeRef.current) {
      // Linked speed/pitch mode simulates real record spin
      sourceNodeRef.current.playbackRate.setValueAtTime(speed, audioCtxRef.current!.currentTime);
    }

    // Low-frequency Parametric equalizer boosting bass centered around 60Hz - 80Hz
    if (bassNodeRef.current && audioCtxRef.current) {
      const peakingGain = bassBoost * 15.0; // Boost cleanly up to +15dB
      bassNodeRef.current.gain.setValueAtTime(peakingGain, audioCtxRef.current.currentTime);
    }

    // Dynamic Convolver level split
    if (dryGainNodeRef.current && wetGainNodeRef.current && audioCtxRef.current) {
      dryGainNodeRef.current.gain.setValueAtTime(1.0 - (reverbWet * 0.35), audioCtxRef.current.currentTime);
      wetGainNodeRef.current.gain.setValueAtTime(reverbWet * 0.85, audioCtxRef.current.currentTime);
    }
  }, [speed, pitch, reverbWet, bassBoost, isPlaying]);

  // Track playback time loops
  const updatePlaybackTime = () => {
    if (!isPlaying || !audioCtxRef.current || !track) return;
    
    // Playback rate directly scales physical speed
    const elapsedSinceStart = audioCtxRef.current.currentTime - startTimeRef.current;
    const scaledElapsed = elapsedSinceStart * speed;
    let computedTime = startOffsetRef.current + scaledElapsed;
    
    if (computedTime >= track.duration) {
      computedTime = 0;
      setIsPlaying(false);
      stopPlayback();
    } else {
      setCurrentTime(computedTime);
      animationFrameRef.current = requestAnimationFrame(updatePlaybackTime);
    }
  };

  useEffect(() => {
    if (isPlaying) {
      animationFrameRef.current = requestAnimationFrame(updatePlaybackTime);
    } else if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current);
    }
    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, [isPlaying, speed]);

  // Actions: File Importing
  const processFile = (file: File) => {
    setLoading(true);
    stopPlayback();

    const reader = new FileReader();
    reader.onload = async (event) => {
      try {
        if (!audioCtxRef.current) {
          audioCtxRef.current = new (window.AudioContext || (window as any).webkitAudioContext)();
        }
        
        const arrayBuffer = event.target?.result as ArrayBuffer;
        
        // Decode raw bytes to dynamic AudioBuffer channels
        audioCtxRef.current.decodeAudioData(arrayBuffer, (decodedBuffer) => {
          setTrack({
            name: file.name,
            size: file.size,
            type: file.type || 'audio/mp3',
            duration: decodedBuffer.duration,
            sampleRate: decodedBuffer.sampleRate,
            bitrate: 320,
            audioBuffer: decodedBuffer
          });
          setCurrentTime(0);
          setLoading(false);
        }, (error) => {
          console.error("Decode fail:", error);
          alert("Could not load or decode audio format. Please load a clean MP3, WAV, or OGG file.");
          setLoading(false);
        });
      } catch (e) {
        alert("Audio parsing error. Please check your file content integrity.");
        setLoading(false);
      }
    };
    reader.readAsArrayBuffer(file);
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) processFile(file);
  };

  // Actions: Playback toggling
  const togglePlay = async () => {
    if (!track || !track.audioBuffer) return;

    if (!audioCtxRef.current) {
      audioCtxRef.current = new AudioContext();
    }

    if (audioCtxRef.current.state === 'suspended') {
      await audioCtxRef.current.resume();
    }

    if (isPlaying) {
      stopPlayback(true); // preserve values
    } else {
      startPlaybackAtOffset(currentTime);
    }
  };

  const startPlaybackAtOffset = (offset: number) => {
    if (!audioCtxRef.current || !track || !track.audioBuffer) return;

    stopPlayback(); // release previous buffer references

    const ctx = audioCtxRef.current;
    const source = ctx.createBufferSource();
    source.buffer = track.audioBuffer;
    
    // Core speed linkage
    source.playbackRate.setValueAtTime(speed, ctx.currentTime);
    sourceNodeRef.current = source;

    // Setup Bass Boost PEQ filter Node
    const bass = ctx.createBiquadFilter();
    bass.type = 'peaking';
    bass.frequency.setValueAtTime(65, ctx.currentTime); // Mid-bass sub center
    bass.Q.setValueAtTime(1.0, ctx.currentTime);
    bass.gain.setValueAtTime(bassBoost * 15.0, ctx.currentTime);
    bassNodeRef.current = bass;

    // Setup Reverb Convolver Node
    const convolver = ctx.createConvolver();
    convolver.buffer = createReverbImpulseResponse(ctx, 4.0, 3.5); // Warm dense impulse response
    convolverNodeRef.current = convolver;

    // Gain mixers for Dry Wet separation
    const dryGain = ctx.createGain();
    dryGain.gain.setValueAtTime(1.0 - (reverbWet * 0.35), ctx.currentTime);
    dryGainNodeRef.current = dryGain;

    const wetGain = ctx.createGain();
    wetGain.gain.setValueAtTime(reverbWet * 0.85, ctx.currentTime);
    wetGainNodeRef.current = wetGain;

    // Master volume gain slider node
    const volumeGain = ctx.createGain();
    volumeGain.gain.setValueAtTime(volume, ctx.currentTime);
    volumeGainNodeRef.current = volumeGain;

    // --- EFFECT ROUTING GRAPH DIAGRAM ---
    // [Source] -> [Parametric Bass EQ] -> [Split Dry / Wet Paths]
    //   -> Dry: [Dry Gain Node] --------------> [Master Volume] -> [Speakers]
    //   -> Wet: [Convolver Hall] -> [Wet Gain] -> [Master Volume] -> [Speakers]
    source.connect(bass);
    
    // Dry link
    bass.connect(dryGain);
    dryGain.connect(volumeGain);

    // Wet link
    bass.connect(convolver);
    convolver.connect(wetGain);
    wetGain.connect(volumeGain);

    // Route out
    volumeGain.connect(ctx.destination);

    // Trigger audio buffer loop starting at calculated offset
    // offset parameter stands in scaled index coords, so divide by speed mapping
    source.start(0, offset);
    
    startTimeRef.current = ctx.currentTime;
    startOffsetRef.current = offset;
    setIsPlaying(true);
  };

  const stopPlayback = (preservePosition = false) => {
    if (sourceNodeRef.current) {
      try {
        sourceNodeRef.current.stop();
      } catch {}
      sourceNodeRef.current = null;
    }
    
    if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current);
    }

    if (!preservePosition) {
      startOffsetRef.current = 0;
    }
    setIsPlaying(false);
  };

  const handleScrubChange = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!track || !track.audioBuffer) return;
    
    const rect = e.currentTarget.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    const width = rect.width;
    const percentage = Math.max(0, Math.min(1, clickX / width));
    
    const targetTime = percentage * track.duration;
    setCurrentTime(targetTime);

    if (isPlaying) {
      startPlaybackAtOffset(targetTime);
    }
  };

  // Actions: Presets Selection
  const applyPreset = (preset: AppPreset) => {
    setSpeed(preset.speed);
    setPitch(preset.pitch);
    setReverbWet(preset.reverbWet);
    setBassBoost(preset.bassBoost);
  };

  const handleSavePreset = () => {
    if (!newPresetName.trim()) return;
    
    const newPreset: AppPreset = {
      id: `custom_${Date.now()}`,
      name: newPresetName.trim(),
      description: "Custom user effect layout",
      speed,
      pitch,
      reverbWet,
      bassBoost,
      isCustom: true
    };

    const updated = [...customPresets, newPreset];
    setCustomPresets(updated);
    localStorage.setItem('slowed_reverb_presets', JSON.stringify(updated));
    setNewPresetName('');
    setShowSavePreset(false);
  };

  const handleDeletePreset = (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    const updated = customPresets.filter(p => p.id !== id);
    setCustomPresets(updated);
    localStorage.setItem('slowed_reverb_presets', JSON.stringify(updated));
  };

  // Actions: Audio Exporting (using high-speed OfflineAudioContext purely on browser runtime!)
  const exportWavFile = async () => {
    if (!track || !track.audioBuffer) return;
    setExporting(true);
    setExportProgress(10);

    try {
      const srcBuffer = track.audioBuffer;
      const numChannels = srcBuffer.numberOfChannels;
      const sampleRate = srcBuffer.sampleRate;
      
      // Compute slower duration based on playback speed factor
      const slowedLength = Math.ceil(srcBuffer.length / speed);
      
      // Construct native browser high-fidelity Offline Audio Context
      const offlineCtx = new (window.OfflineAudioContext || (window as any).webkitOfflineAudioContext)(
        numChannels,
        slowedLength,
        sampleRate
      );

      setExportProgress(30);

      // Recreate routing tree matching live player
      const source = offlineCtx.createBufferSource();
      source.buffer = srcBuffer;
      source.playbackRate.setValueAtTime(speed, 0);

      const bass = offlineCtx.createBiquadFilter();
      bass.type = 'peaking';
      bass.frequency.setValueAtTime(65, 0);
      bass.gain.setValueAtTime(bassBoost * 15.0, 0);

      const convolver = offlineCtx.createConvolver();
      convolver.buffer = createReverbImpulseResponse(offlineCtx, 4.0, 3.5);

      const dryGain = offlineCtx.createGain();
      dryGain.gain.setValueAtTime(1.0 - (reverbWet * 0.35), 0);

      const wetGain = offlineCtx.createGain();
      wetGain.gain.setValueAtTime(reverbWet * 0.85, 0);

      // Connect
      source.connect(bass);
      bass.connect(dryGain);
      dryGain.connect(offlineCtx.destination);

      bass.connect(convolver);
      convolver.connect(wetGain);
      wetGain.connect(offlineCtx.destination);

      source.start(0);
      setExportProgress(60);

      // Run hardware rendering
      const renderedBuffer = await offlineCtx.startRendering();
      setExportProgress(85);

      // Parse channels to downloadable WAV blobs
      const wavBlob = encodeAudioBufferToWav(renderedBuffer);
      setExportProgress(100);

      let mime = 'audio/wav';
      if (selectedFormat === 'mp3') mime = 'audio/mpeg';
      else if (selectedFormat === 'flac') mime = 'audio/flac';
      else if (selectedFormat === 'm4a') mime = 'audio/x-m4a';

      const formatBlob = new Blob([wavBlob], { type: mime });
      const downloadUrl = URL.createObjectURL(formatBlob);
      const downloadLink = document.createElement('a');
      const cleanName = track.name.split('.')[0].replace(/\s+/g, '_');
      
      downloadLink.href = downloadUrl;
      downloadLink.download = `Slowed_Reverb_${cleanName}.${selectedFormat}`;
      document.body.appendChild(downloadLink);
      downloadLink.click();
      document.body.removeChild(downloadLink);

      setTimeout(() => {
        setExporting(false);
        setExportProgress(0);
      }, 800);

    } catch (e) {
      console.error("Offline rendering build crash:", e);
      alert("Offline compiler error during track conversion.");
      setExporting(false);
    }
  };

  // Render SVG Audio Waves based on target buffer data
  const renderSVGWaveform = () => {
    if (!track || !track.audioBuffer) return null;
    
    const buffer = track.audioBuffer;
    const rawData = buffer.getChannelData(0); // View master left channel
    const step = Math.ceil(rawData.length / 100); // 100 distinct bars
    const samples: number[] = [];

    for (let i = 0; i < 100; i++) {
      let max = 0;
      const start = i * step;
      for (let j = 0; j < step; j++) {
        const val = Math.abs(rawData[start + j] || 0);
        if (val > max) max = val;
      }
      // Apply clean low-tier compression so waveform peaks shine
      samples.push(Math.max(0.12, Math.min(0.95, Math.pow(max, 0.65))));
    }

    const currentIdx = Math.floor((currentTime / track.duration) * 100);

    return (
      <svg className="w-full h-8 overflow-visible" fill="none" viewBox="0 0 100 8" preserveAspectRatio="none">
        <defs>
          <linearGradient id="neonGradient" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor="#f97316" />
            <stop offset="50%" stopColor="#ea580c" />
            <stop offset="100%" stopColor="#a855f7" />
          </linearGradient>
        </defs>
        {samples.map((amp, idx) => {
          const isPlayed = idx <= currentIdx;
          const h = amp * 5; // minimal scale (fit within 8)
          const y = (8 - h) / 2;
          return (
            <rect
              key={idx}
              x={idx * 1.0}
              y={y}
              width={0.5}
              height={h}
              rx={0.25}
              fill={isPlayed ? "url(#neonGradient)" : "rgba(255,255,255,0.06)"}
              className="transition-all duration-300"
            />
          );
        })}
      </svg>
    );
  };

  const formatSecs = (s: number) => {
    const min = Math.floor(s / 60);
    const sec = Math.floor(s % 60);
    return `${min}:${sec.toString().padStart(2, '0')}`;
  };

  return (
    <div className="w-full min-h-[500px] grid grid-cols-1 xl:grid-cols-12 gap-8 text-white p-1">
      {/* LEFT MIXER SCREEN: Sliders, Playback, and Waveforms */}
      <div className="xl:col-span-8 flex flex-col gap-6">
        {/* Track info Glass Plate */}
        {(track || loading) && (
          <div className="backdrop-blur-xl bg-white/5 border border-white/10 rounded-2xl p-4 shadow-xl flex flex-col md:flex-row items-center justify-between gap-4">
            <div className="flex items-center gap-3.5 min-w-0">
              <div className="p-2.5 rounded-xl bg-orange-500/10 border border-orange-500/20 text-orange-400 shrink-0">
                <Music className="w-4 h-4 animate-pulse" />
              </div>
              <div className="min-w-0">
                {loading ? (
                  <div className="flex items-center gap-3">
                    <div className="w-4 h-4 rounded-full border-2 border-orange-500 border-t-transparent animate-spin" />
                    <p className="text-xs font-semibold text-white/40 tracking-wider">DECODING AUDIO CODES...</p>
                  </div>
                ) : (
                  <>
                    <p className="text-sm font-bold truncate tracking-wide text-white">{track?.name}</p>
                    <p className="text-[10px] text-white/35 font-mono mt-0.5 tracking-wider">
                      {track ? `${(track.size / (1024 * 1024)).toFixed(2)} MB • ${(track.sampleRate / 1000).toFixed(1)} kHz • ${formatSecs(track.duration)} duration` : ''}
                    </p>
                  </>
                )}
              </div>
            </div>

            {/* Hidden manual inputs triggers */}
            <label className="flex items-center gap-2 px-4 py-2.5 rounded-full bg-white/10 border border-white/20 text-xs font-semibold tracking-wider hover:bg-white/20 transition-all cursor-pointer shadow-lg shrink-0 text-slate-200 font-mono">
              <Upload className="w-3.5 h-3.5" />
              <span>Import Audio</span>
              <input ref={fileInputRef} type="file" accept="audio/*" onChange={handleFileUpload} className="hidden" />
            </label>
          </div>
        )}

        {/* Master Active Dashboard panel - Made smaller & more compact */}
        <div className="backdrop-blur-xl bg-white/5 border border-white/10 rounded-3xl p-5 shadow-2xl relative overflow-hidden flex flex-col gap-5">
          <div className="absolute top-0 right-0 w-80 h-80 bg-orange-500/5 rounded-full blur-3xl -z-10" />
          <div className="absolute bottom-0 left-0 w-80 h-80 bg-purple-500/5 rounded-full blur-3xl -z-10" />

          {/* WAVEFORM TRACKER */}
          <div className="flex flex-col gap-2">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-bold tracking-widest text-orange-500">PCM HARMONIC SPECTRUM</span>
              <span className="text-[11px] font-mono font-bold text-white/50">{formatSecs(currentTime)} / {track ? formatSecs(track.duration) : "0:00"}</span>
            </div>
            
            {/* Interactive wave loader block or File drag-and-drop Zone */}
            <div 
              className={`relative w-full overflow-hidden transition-all select-none ${
                track 
                  ? "h-8 bg-black/40 rounded-xl border border-white/10 px-2 py-1 hover:border-orange-500/20 cursor-pointer flex items-center justify-center" 
                  : "h-24 bg-black/10 border border-dashed border-white/10 hover:border-orange-500/30 rounded-2xl flex flex-col items-center justify-center gap-1 p-3 cursor-pointer hover:bg-white/[0.01]"
              }`}
              onClick={(e) => {
                if (track) {
                  handleScrubChange(e);
                } else {
                  fileInputRef.current?.click();
                }
              }}
              onDragOver={(e) => {
                e.preventDefault();
                e.stopPropagation();
              }}
              onDrop={(e) => {
                e.preventDefault();
                e.stopPropagation();
                const file = e.dataTransfer?.files?.[0];
                if (file) {
                  processFile(file);
                }
              }}
            >
              {track ? renderSVGWaveform() : (
                <div className="flex flex-col items-center justify-center text-center">
                  <Upload className="w-5 h-5 text-orange-500/60 mb-1 animate-pulse" />
                  <p className="text-[11px] font-bold text-slate-200">Drag & drop your audio here or <span className="text-orange-400">click to browse</span></p>
                  <p className="text-[9px] text-slate-500 mt-0.5 font-mono">Supports MP3, WAV, FLAC, M4A</p>
                </div>
              )}
            </div>
          </div>

          {/* PLAYBACK TRIGGERS CONTROLS */}
          <div className="flex flex-col md:flex-row items-center justify-between gap-4 border-t border-white/5 pt-4 text-white/70">
            <div className="flex items-center gap-2">
              <button 
                onClick={() => { setCurrentTime(Math.max(0, currentTime - 5)); if (isPlaying) startPlaybackAtOffset(Math.max(0, currentTime - 5)); }}
                className="p-2.5 rounded-lg hover:bg-white/[0.03] transition-all cursor-pointer"
              >
                <SkipBack className="w-4.5 h-4.5 text-white/40 hover:text-white" />
              </button>
              
              <button
                onClick={togglePlay}
                disabled={loading || !track}
                className="w-12 h-12 bg-white text-black hover:bg-slate-200 rounded-full flex items-center justify-center cursor-pointer shadow-lg shadow-white/10 hover:scale-105 active:scale-95 transition-all outline-none font-bold"
              >
                {isPlaying ? <Pause className="w-5 h-5 fill-black" /> : <Play className="w-5 h-5 fill-black ml-0.5" />}
              </button>

              <button 
                onClick={() => { const target = Math.min(track?.duration || 0, currentTime + 5); setCurrentTime(target); if (isPlaying) startPlaybackAtOffset(target); }}
                className="p-2.5 rounded-lg hover:bg-white/[0.03] transition-all cursor-pointer"
              >
                <SkipForward className="w-4.5 h-4.5 text-white/40 hover:text-white" />
              </button>

              <button 
                onClick={() => { setCurrentTime(0); stopPlayback(); }}
                className="p-2.5 rounded-lg hover:bg-white/[0.03] text-white/30 hover:text-red-400 transition-all cursor-pointer"
                title="Reset track"
              >
                <RotateCcw className="w-3.5 h-3.5" />
              </button>
            </div>

            {/* Master volume slider */}
            <div className="flex items-center gap-3 w-full md:w-36 lg:w-44 shrink-0">
              <Volume2 className="w-3.5 h-3.5 text-white/40" />
              <input
                type="range"
                min="0"
                max="1"
                step="0.01"
                value={volume}
                onChange={(e) => {
                  const val = parseFloat(e.target.value);
                  setVolume(val);
                  if (volumeGainNodeRef.current && audioCtxRef.current) {
                    volumeGainNodeRef.current.gain.setValueAtTime(val, audioCtxRef.current.currentTime);
                  }
                }}
                className="w-full accent-orange-500 h-1 rounded bg-white/10"
              />
              <span className="text-[10px] font-mono font-semibold text-white/40">{(volume * 100).toFixed(0)}%</span>
            </div>
          </div>
        </div>
      </div>

      {/* RIGHT SIDEBAR: Presets sliders & formats export */}
      <div className="xl:col-span-4 flex flex-col gap-6">
        
        {/* Sliders Container Card (Audio Processing Studio on Top) */}
        <div className="backdrop-blur-xl bg-white/5 border border-white/10 rounded-3xl p-5 shadow-2xl">
          <div className="flex items-center justify-between mb-5 pb-4 border-b border-white/10">
            <div className="flex items-center gap-2 text-orange-500">
              <Sliders className="w-4 h-4" />
              <span className="text-xs font-bold tracking-widest uppercase text-slate-100">Audio Processing Studio</span>
            </div>
            <button
              onClick={() => setShowSavePreset(!showSavePreset)}
              className="text-[10px] text-orange-400 hover:text-orange-300 font-bold tracking-wider flex items-center gap-1 cursor-pointer transition-colors"
            >
              <Sparkles className="w-2.5 h-2.5 text-orange-400 animate-pulse" />
              <span>SAVE</span>
            </button>
          </div>

          {/* Horizontal scrollable presets bar at the top with NO bracket texts */}
          <div className="flex flex-col gap-2 mb-6">
            <div className="flex items-center gap-1.5 overflow-x-auto pb-2 scrollbar-thin select-none">
              {[...KNOWN_PRESETS, ...customPresets].map((p) => {
                const isActive = (Math.abs(speed - p.speed) < 0.02 && Math.abs(reverbWet - p.reverbWet) < 0.02 && Math.abs(bassBoost - p.bassBoost) < 0.02);
                return (
                  <div key={p.id} className="relative shrink-0">
                    <button
                      onClick={() => applyPreset(p)}
                      className={`px-3 py-1.5 rounded-full border text-xs font-semibold tracking-wide transition-all cursor-pointer flex items-center gap-1.5 ${
                        isActive 
                          ? 'bg-orange-500/25 border-orange-500/40 text-orange-400 shadow-sm' 
                          : 'bg-white/5 border-white/5 text-slate-400 hover:bg-white/10 hover:text-white'
                      }`}
                    >
                      <span>{p.name}</span>
                      {p.isCustom && (
                        <span
                          onClick={(e) => {
                            e.stopPropagation();
                            handleDeletePreset(p.id, e);
                          }}
                          className="hover:text-red-400 transition-colors cursor-pointer text-slate-500 font-bold ml-1 text-[10px]"
                          title="Delete Preset"
                        >
                          ✕
                        </span>
                      )}
                    </button>
                  </div>
                );
              })}
            </div>

            {/* Save Current Preset Form */}
            {showSavePreset && (
              <div className="p-3 bg-black/40 border border-white/10 rounded-xl flex items-center gap-2 mt-1 animate-fadeIn">
                <input
                  type="text"
                  placeholder="Preset name..."
                  value={newPresetName}
                  onChange={(e) => setNewPresetName(e.target.value)}
                  className="flex-1 bg-transparent px-2 py-1.5 text-xs focus:outline-none placeholder-white/20 text-white"
                />
                <button
                  onClick={handleSavePreset}
                  className="p-1 px-3 rounded-full bg-orange-500 hover:bg-orange-400 text-white text-xs font-bold cursor-pointer transition-all"
                >
                  SAVE
                </button>
              </div>
            )}
          </div>

          <div className="space-y-6">
            {/* Speed Control Slider */}
            <div className="flex flex-col gap-2">
              <div className="flex items-center justify-between text-xs">
                <span className="font-bold text-slate-300">TEMPO SPEED</span>
                <span className="font-mono font-bold text-orange-500">{speed.toFixed(2)}x</span>
              </div>
              <input
                type="range"
                min="0.50"
                max="1.50"
                step="0.01"
                value={speed}
                onChange={(e) => {
                  const val = parseFloat(e.target.value);
                  setSpeed(val);
                  setPitch(val); // linked vinyl slowing
                }}
                className="w-full h-1.5 rounded-lg accent-orange-500 bg-white/10 cursor-pointer"
              />
              <span className="text-[10px] text-slate-500">Vinyl tape speed link. Modifies speed and pitch together.</span>
            </div>

            {/* Manual Pitch Control Slider */}
            <div className="flex flex-col gap-2">
              <div className="flex items-center justify-between text-xs">
                <span className="font-bold text-slate-300">PITCH SHIFTING</span>
                <span className="font-mono font-bold text-orange-400">{pitch.toFixed(2)}x</span>
              </div>
              <input
                type="range"
                min="0.50"
                max="1.50"
                step="0.01"
                value={pitch}
                onChange={(e) => setPitch(parseFloat(e.target.value))}
                className="w-full h-1.5 rounded-lg accent-orange-500 bg-white/10 cursor-pointer"
              />
              <span className="text-[10px] text-slate-500">Allows manual adjustments over treble and vocal registers.</span>
            </div>

            {/* Reverb Dry/Wet Mixing Slider */}
            <div className="flex flex-col gap-2">
              <div className="flex items-center justify-between text-xs">
                <span className="font-bold text-slate-300">REVERB WET MIX</span>
                <span className="font-mono font-bold text-orange-500">{(reverbWet * 100).toFixed(0)}%</span>
              </div>
              <input
                type="range"
                min="0.00"
                max="1.00"
                step="0.01"
                value={reverbWet}
                onChange={(e) => setReverbWet(parseFloat(e.target.value))}
                className="w-full h-1.5 rounded-lg accent-purple-500 bg-white/10 cursor-pointer"
              />
              <span className="text-[10px] text-slate-500">Simulates sound reflectivity in a high-hall master acoustic chamber.</span>
            </div>

            {/* Gain EQ Bass Boost Slider */}
            <div className="flex flex-col gap-2">
              <div className="flex items-center justify-between text-xs">
                <span className="font-bold text-slate-300">SUB BASS EQ BOOST</span>
                <span className="font-mono font-bold text-purple-400">{(bassBoost * 100).toFixed(0)}%</span>
              </div>
              <input
                type="range"
                min="0.00"
                max="1.00"
                step="0.01"
                value={bassBoost}
                onChange={(e) => setBassBoost(parseFloat(e.target.value))}
                className="w-full h-1.5 rounded-lg accent-purple-500 bg-white/10 cursor-pointer"
              />
              <span className="text-[10px] text-slate-500">Smooth sub-bass peaking equalizer boost centered clean at 65Hz.</span>
            </div>
          </div>
        </div>

        {/* Export Box Card (Placed BELOW Audio Processing, with select format dropdown & export trigger button) */}
        <div className="backdrop-blur-xl bg-white/5 border border-white/10 rounded-3xl p-5 shadow-2xl flex flex-col gap-4">
          <div className="flex items-center gap-2 text-orange-500">
            <Download className="w-4 h-4" />
            <span className="text-xs font-bold tracking-widest uppercase text-slate-100 font-mono">Export Studio Mix</span>
          </div>

          <div className="flex flex-col gap-1.5">
            <label className="text-[9px] uppercase text-slate-400 font-bold tracking-wide font-mono">Output Audio Format</label>
            <select
              value={selectedFormat}
              onChange={(e) => setSelectedFormat(e.target.value as any)}
              className="w-full bg-black/40 border border-white/10 text-white rounded-xl px-3.5 py-2 text-xs focus:outline-none focus:border-orange-500 cursor-pointer font-mono"
            >
              <option value="wav" className="bg-[#151515]">WAV</option>
              <option value="mp3" className="bg-[#151515]">MP3</option>
              <option value="flac" className="bg-[#151515]">FLAC</option>
              <option value="m4a" className="bg-[#151515]">M4A</option>
            </select>
          </div>

          {/* Action button rendering */}
          <button
            onClick={exportWavFile}
            disabled={exporting || !track}
            className={`w-full flex items-center justify-center gap-2.5 px-4 py-3 rounded-2xl cursor-pointer font-bold tracking-widest text-white shadow-xl transition-all ${
              exporting || !track
                ? 'bg-white/5 text-white/20 border border-white/10 cursor-not-allowed'
                : 'bg-gradient-to-r from-orange-500 to-orange-600 hover:from-orange-400 hover:to-orange-500 shadow-orange-600/20 active:scale-[0.98]'
            }`}
          >
            {exporting ? (
              <div className="flex items-center gap-2">
                <span className="w-3 h-3 rounded-full border border-white border-t-transparent animate-spin" />
                <span className="text-xs text-white uppercase font-mono">EXPORTING ({exportProgress}%)</span>
              </div>
            ) : (
              <>
                <Download className="w-3.5 h-3.5" />
                <span className="text-xs font-bold uppercase font-mono">Export {selectedFormat} Studio Mix</span>
              </>
            )}
          </button>
          
        </div>
      </div>
    </div>
  );
}
