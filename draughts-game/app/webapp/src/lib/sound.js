import { useEffect, useRef } from 'react';

/*
 * Sounds, made in the browser with the Web Audio API: there are no audio files to host, load or
 * keep in step with the board. Each one is a few short oscillator and noise bursts shaped to
 * sound like what it stands for -- a piece set down on wood, a clash of two pieces, a chime.
 *
 * Browsers only let a page make sound after the person has touched it, so the audio context is
 * made (or woken) on the first tap, click or key press; anything that fires before that, such as
 * an opponent's move arriving while the page is still untouched, is simply silent.
 */

let context = null;
let enabled = true;

function ensureContext() {
  if (context) return context;
  const Ctor = typeof window !== 'undefined' && (window.AudioContext || window.webkitAudioContext);
  if (!Ctor) return null;
  try {
    context = new Ctor();
  } catch {
    context = null;
  }
  return context;
}

/** Wake the context on a user gesture. */
function unlock() {
  const ctx = ensureContext();
  if (ctx && ctx.state === 'suspended') ctx.resume().catch(() => {});
}
if (typeof window !== 'undefined') {
  for (const type of ['pointerdown', 'keydown', 'touchstart']) {
    window.addEventListener(type, unlock, { passive: true });
  }
}

export function setSoundEnabled(on) {
  enabled = on;
}

/** A short burst of filtered noise: the "knock" of wood on wood. */
function knock(ctx, at, { gain = 0.5, freq = 1400, q = 1.2, length = 0.045 } = {}) {
  const frames = Math.max(1, Math.floor(ctx.sampleRate * length));
  const buffer = ctx.createBuffer(1, frames, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < frames; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / frames) ** 2;
  const source = ctx.createBufferSource();
  source.buffer = buffer;
  const filter = ctx.createBiquadFilter();
  filter.type = 'bandpass';
  filter.frequency.value = freq;
  filter.Q.value = q;
  const volume = ctx.createGain();
  volume.gain.setValueAtTime(gain, at);
  volume.gain.exponentialRampToValueAtTime(0.001, at + length);
  source.connect(filter).connect(volume).connect(ctx.destination);
  source.start(at);
}

/** A tone that falls (or rises) in pitch and fades: the body of a thud, or a bell. */
function tone(ctx, at, { from, to = from, length = 0.12, gain = 0.3, type = 'sine' } = {}) {
  const osc = ctx.createOscillator();
  osc.type = type;
  osc.frequency.setValueAtTime(from, at);
  if (to !== from) osc.frequency.exponentialRampToValueAtTime(to, at + length);
  const volume = ctx.createGain();
  volume.gain.setValueAtTime(0.0001, at);
  volume.gain.exponentialRampToValueAtTime(gain, at + 0.008);
  volume.gain.exponentialRampToValueAtTime(0.0001, at + length);
  osc.connect(volume).connect(ctx.destination);
  osc.start(at);
  osc.stop(at + length + 0.02);
}

/** A piece set down on the board. */
const thud = (ctx, at, gain = 1) => {
  knock(ctx, at, { gain: 0.55 * gain });
  tone(ctx, at, { from: 190, to: 80, length: 0.1, gain: 0.45 * gain });
};

const SOUNDS = {
  /** A piece picked up. */
  select: (ctx, t) => knock(ctx, t, { gain: 0.18, freq: 2600, length: 0.02 }),
  /** A piece set down. */
  move: (ctx, t) => thud(ctx, t),
  /** A capture: the piece lands harder, and the one it took clacks away. */
  capture: (ctx, t) => {
    thud(ctx, t, 1.15);
    knock(ctx, t + 0.07, { gain: 0.45, freq: 2200, q: 2, length: 0.05 });
    thud(ctx, t + 0.13, 0.7);
  },
  /** A man crowned: the move, then a small rising chime. */
  king: (ctx, t) => {
    thud(ctx, t);
    tone(ctx, t + 0.12, { from: 784, length: 0.22, gain: 0.16, type: 'triangle' });
    tone(ctx, t + 0.2, { from: 1175, length: 0.32, gain: 0.16, type: 'triangle' });
  },
  /** The other player has come into the room. */
  join: (ctx, t) => {
    tone(ctx, t, { from: 523, length: 0.16, gain: 0.18, type: 'triangle' });
    tone(ctx, t + 0.12, { from: 659, length: 0.24, gain: 0.18, type: 'triangle' });
  },
  win: (ctx, t) => {
    [523, 659, 784, 1047].forEach((f, i) =>
      tone(ctx, t + i * 0.11, { from: f, length: i === 3 ? 0.55 : 0.2, gain: 0.2, type: 'triangle' })
    );
  },
  lose: (ctx, t) => {
    [392, 330, 262].forEach((f, i) =>
      tone(ctx, t + i * 0.16, { from: f, to: f * 0.96, length: i === 2 ? 0.5 : 0.22, gain: 0.2, type: 'sawtooth' })
    );
  },
  draw: (ctx, t) => {
    tone(ctx, t, { from: 440, length: 0.22, gain: 0.16, type: 'triangle' });
    tone(ctx, t + 0.16, { from: 440, length: 0.34, gain: 0.16, type: 'triangle' });
  },
  /** A clock running low. */
  tick: (ctx, t) => {
    knock(ctx, t, { gain: 0.3, freq: 3200, q: 3, length: 0.02 });
    tone(ctx, t, { from: 1500, length: 0.04, gain: 0.08 });
  },
  /** A move that was refused. */
  error: (ctx, t) => tone(ctx, t, { from: 160, to: 110, length: 0.14, gain: 0.2, type: 'square' }),
};

/** Play a named sound, if sound is on and the browser allows it yet. */
export function play(name) {
  if (!enabled) return;
  const ctx = ensureContext();
  if (!ctx || ctx.state !== 'running') return;
  try {
    SOUNDS[name]?.(ctx, ctx.currentTime + 0.005);
  } catch {
    // Sound is never worth breaking the game for.
  }
}

/**
 * Sounds for a game as it unfolds, from its state alone.
 *
 * Whenever one or more moves have been added since last time it plays the last one -- a quiet
 * move, a capture, or a crowning -- so a move sounds the same whoever made it, on this screen or
 * the other player's. When the game ends it plays the result: for `you`, a win or a loss; with
 * nobody in particular (two people at one screen) a win for either. Nothing sounds on first
 * load, or when a new game replaces the old one.
 *
 * @param state  the game, as either service sends it (or null)
 * @param you    'Black' or 'White' if one side is the person listening, else null
 */
export function useGameSounds(state, you = null) {
  const seen = useRef(null);

  useEffect(() => {
    if (!state) {
      seen.current = null;
      return;
    }
    const plies = state.history.length;
    const previous = seen.current;
    seen.current = { plies, status: state.status, waiting: Boolean(state.waiting) };
    if (!previous) return;

    if (plies < previous.plies) return; // a new game: start afresh, silently

    if (previous.waiting && !state.waiting) play('join');

    if (plies > previous.plies) {
      const last = state.history[plies - 1];
      play(last.crowned ? 'king' : last.captures > 0 ? 'capture' : 'move');
    }

    if (previous.status === 'Ongoing' && state.status !== 'Ongoing') {
      const winner = state.status === 'BlackWins' ? 'Black' : state.status === 'WhiteWins' ? 'White' : null;
      const delay = plies > previous.plies ? 450 : 0; // let the last move be heard first
      const result = winner === null ? 'draw' : you === null || winner === you ? 'win' : 'lose';
      setTimeout(() => play(result), delay);
    }
  }, [state, you]);
}
