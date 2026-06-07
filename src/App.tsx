import React from 'react';
import { Sparkles, Cpu, Info } from 'lucide-react';
import StudioDashboard from './components/StudioDashboard';

export default function App() {
  return (
    <div className="min-h-screen bg-[#050505] text-slate-100 flex flex-col font-sans transition-all relative overflow-x-hidden select-none">
      {/* Backdrops Radial Ambient Neon Orbs */}
      <div className="absolute top-[-10%] left-[-10%] w-[50vw] h-[50vw] bg-purple-900/20 rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute bottom-[-10%] right-[-10%] w-[50vw] h-[50vw] bg-orange-900/20 rounded-full blur-[120px] pointer-events-none" />

      {/* HEADER BAR */}
      <header className="w-full border-b border-white/10 bg-black/40 backdrop-blur-md shrink-0 z-10">
        <div className="max-w-7xl mx-auto px-6 py-5 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
          
          {/* Logo and Tagline */}
          <div className="flex items-center gap-3">
            <div className="relative py-2.5 px-3.5 rounded-2xl bg-gradient-to-tr from-orange-500 to-purple-600 font-extrabold text-white text-sm tracking-wider shadow-xl shadow-orange-500/10">
              SRS
            </div>
            <div>
              <h1 className="text-sm md:text-base font-bold tracking-[0.05em] text-white flex items-center gap-2">
                <span className="uppercase font-bold tracking-tight italic">SLOWED <span className="text-orange-500">REVERB</span> STUDIO</span>
                <span className="hidden sm:inline-block px-2 py-0.5 text-[8px] bg-orange-500/15 border border-orange-500/30 text-orange-400 font-bold tracking-widest rounded-full uppercase">
                  V2.0
                </span>
              </h1>
            </div>
          </div>


        </div>
      </header>

      {/* CORE WORKSPACE INNER CONTENT */}
      <main className="flex-grow w-full max-w-7xl mx-auto px-6 py-8 flex flex-col min-h-0">
        <div className="animate-fadeIn">
          <StudioDashboard />
        </div>
      </main>

      {/* MINIMALIST COMPASS GLASSMETRIC FOOTER BAR */}
      <footer className="w-full py-5 border-t border-white/10 bg-black/40 flex items-center justify-center shrink-0">
        <div className="max-w-7xl mx-auto px-6 w-full flex flex-col md:flex-row items-center justify-between gap-4 text-[10px] md:text-xs text-slate-600 font-medium">
          <div className="flex items-center gap-1">
            <Sparkles className="w-3.5 h-3.5 text-orange-500" />
            <span>Slowed Reverb Studio © 2026</span>
          </div>
        </div>
      </footer>
    </div>
  );
}
