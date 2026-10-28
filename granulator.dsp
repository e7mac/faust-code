declare name "Granulator";
declare author "Mayank Sanganeria";
declare version "1.1";
declare description "Granular processor based on a single shared delay line";

import("stdfaust.lib");

// =====================================================
// Constants
// =====================================================

// Maximum number of simultaneous grains.
// Lower this (e.g. 16) if you get xruns on a Raspberry Pi.
maxN = 32;

// Size of the shared delay buffer in samples (power of two).
// 524288 samples is about 10.9 s at 48 kHz.
// Faust allocates only ONE buffer, shared by all grains.
maxDelay = 1 << 19;

// =====================================================
// Controls
// =====================================================

// Number of active grains (smoothed to avoid zipper noise and clicks)
N = hslider("grain density", 1, 1, maxN, 1) : si.smoo;

// Grain length in seconds (smoothed so the grain rate changes without jumps)
gLength = hslider("grain length", 0.1, 0.01, 0.5, 0.01) : si.smoo;

// Maximum random delay in seconds. This only affects newly started grains,
// so changing it never produces clicks.
dLength = hslider("delay length", 10, 0.5, 10, 0.1);

// =====================================================
// Grain phases
// =====================================================

// Master ramp 0..1 whose period equals the grain length
master = os.lf_sawpos(1.0 / gLength);

// Phase of grain i. Grains are evenly spaced across the cycle (offset i/N),
// so the overlapping windows sum to a roughly constant level.
phase(i) = ma.frac(master + i / max(1, N));

// Trigger pulse at the first sample of each new grain
// (the phase wrapped around from ~1 back to ~0).
trig(i) = phase(i) < phase(i)';

// Hann window: smoothly goes 0 -> 1 -> 0 over one grain.
// sin^2(pi * phase) is zero at both ends, so there are no discontinuities.
window(i) = sin(ma.PI * phase(i)) ^ 2;

// Soft on/off gate for grain i depending on density.
// Grains fade in/out instead of switching abruptly.
gate(i) = min(1, max(0, N - i));

// =====================================================
// Randomness
// =====================================================

// Independent noise generator per grain, scaled to the 0..1 range
rnd(i) = no.noises(maxN, i) * 0.5 + 0.5;

// Random delay time (in samples) for grain i.
// Sample & hold: the value changes ONLY when a new grain starts.
// At that moment the window is ~0, so the jump is inaudible.
// The delay stays constant during the grain, so the read head moves at the
// same speed as the write head (no pitch change, no read/write head crossing).
grainDelay(i) = rnd(i) * min(maxDelay - 1, dLength * ma.SR) : ba.sAndH(trig(i));

// =====================================================
// A single grain
// =====================================================

// Read from the shared delay line at the random delay,
// then apply the window and the density gate.
grain(i) = de.delay(maxDelay, int(grainDelay(i))) * window(i) * gate(i);

// =====================================================
// Output
// =====================================================

// Mono input -> maxN parallel grains -> sum -> level compensation -> stereo out.
// Dividing by sqrt(N) keeps the loudness roughly constant as density changes.
process = _ <: par(i, maxN, grain(i)) :> _
            : *(1.0 / sqrt(max(1, N)))
            <: _, _;
