#!/usr/bin/env python3
"""Synthesizes the game sound effects in assets/audio/.

All sounds are generated from scratch by this script (no third-party
samples), so they carry no licensing obligations. Re-run after tweaking:

    python3 tool/generate_game_audio.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
random.seed(8)


def envelope(i, n, attack=0.01, release=0.6):
    t = i / RATE
    total = n / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r_start = total * (1 - release)
    r = 1.0 if t < r_start else max(0.0, 1 - (t - r_start) / (total - r_start + 1e-9))
    return a * r


def tone(freq_fn, seconds, volume=0.5, wave_shape="sine", attack=0.005, release=0.7, noise=0.0):
    n = int(RATE * seconds)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq_fn(i / n)
        phase += 2 * math.pi * f / RATE
        if wave_shape == "square":
            s = 1.0 if math.sin(phase) >= 0 else -1.0
            s *= 0.6
        elif wave_shape == "triangle":
            s = 2 / math.pi * math.asin(math.sin(phase))
        else:
            s = math.sin(phase)
        if noise:
            s = s * (1 - noise) + (random.random() * 2 - 1) * noise
        out.append(s * volume * envelope(i, n, attack, release))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def concat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.95 / peak)
    frames = b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)


def note(semitones_from_a4):
    return 440.0 * 2 ** (semitones_from_a4 / 12)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    write("shoot.wav", tone(lambda p: 1400 - 900 * p, 0.09, 0.35, "square", release=0.8))
    write("hit.wav", mix(
        tone(lambda p: 180 - 120 * p, 0.22, 0.6, "sine", noise=0.55, release=0.9),
        tone(lambda p: note(15) + 200 * p, 0.12, 0.25, "triangle"),
    ))
    write("wrong.wav", concat(
        tone(lambda p: 196, 0.12, 0.45, "square", release=0.3),
        tone(lambda p: 147, 0.22, 0.45, "square", release=0.6),
    ))
    write("combo.wav", concat(*[
        tone(lambda p, f=note(s): f, 0.07, 0.4, "triangle", release=0.5) for s in (3, 7, 10, 15)
    ]))
    write("powerup.wav", tone(lambda p: 300 + 1500 * p * p, 0.35, 0.4, "triangle", release=0.4))
    write("boss.wav", mix(
        tone(lambda p: 55 + 10 * math.sin(p * 40), 1.1, 0.7, "square", attack=0.08, release=0.5),
        tone(lambda p: 82.5, 1.1, 0.3, "sine", attack=0.2, release=0.5, noise=0.2),
    ))
    write("gameover.wav", concat(*[
        tone(lambda p, f=note(s): f, 0.18, 0.45, "triangle", release=0.5) for s in (7, 3, 0, -5)
    ]))
    write("select.wav", tone(lambda p: 900, 0.04, 0.25, "sine", release=0.8))
    write("solved.wav", concat(*[
        tone(lambda p, f=note(s): f, 0.11, 0.4, "triangle", release=0.4) for s in (0, 4, 7, 12, 16, 19, 24)
    ]))

    # 16-second background loop: bass + arpeggio in A minor, quiet.
    bars = [(-12, [0, 3, 7, 12]), (-16, [-4, 0, 3, 8]), (-19, [-7, -3, 0, 5]), (-14, [-2, 2, 5, 10])]
    loop = []
    for _ in range(2):
        for bass, chord in bars:
            bass_track = tone(lambda p, f=note(bass - 12): f, 2.0, 0.22, "triangle", attack=0.02, release=0.2)
            arp = []
            for k in range(16):
                f = note(chord[k % 4] + (12 if k % 8 >= 4 else 0))
                arp.extend(tone(lambda p, f=f: f, 0.125, 0.12, "square", attack=0.002, release=0.7))
            loop.extend(mix(bass_track, arp))
    write("music_loop.wav", loop)


if __name__ == "__main__":
    main()
