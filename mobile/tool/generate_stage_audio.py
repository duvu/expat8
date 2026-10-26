#!/usr/bin/env python3
"""Synthesizes the per-stage game music and the stage-tier sound effects.

Everything is generated from scratch here (no third-party samples), so it
carries no licensing obligations. Requires numpy and ffmpeg (for OGG):

    python3 tool/generate_stage_audio.py

Music: 2 themes x 5 stages. Each stage adds layers and tempo so a level-up is
audible: 1 pad+bass, 2 +melody, 3 +drums, 4 +arpeggio/snare, 5 +choir,
shimmer and a darker, more mysterious harmony.
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 32000
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
rng = np.random.default_rng(8)

A4 = 440.0
NOTE = {n: i for i, n in enumerate(
    ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def hz(name, octave):
    return A4 * 2 ** ((NOTE[name] + 12 * (octave + 1) - 69) / 12)


def chord_freqs(root, quality, octave=3):
    base = NOTE[root] + 12 * (octave + 1)
    steps = {"maj": [0, 4, 7], "min": [0, 3, 7], "maj7": [0, 4, 7, 11],
             "min7": [0, 3, 7, 10], "sus": [0, 5, 7], "dom": [0, 4, 7, 10]}[quality]
    return [A4 * 2 ** ((base + s - 69) / 12) for s in steps]


# ─── oscillators & envelopes ───────────────────────────────────────────────

def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def osc(freq, seconds, shape="sine", detune=0.0):
    t = t_axis(seconds)
    f = freq * (1 + detune)
    ph = 2 * np.pi * f * t
    if shape == "sine":
        return np.sin(ph)
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if shape == "saw":  # band-limited via a few harmonics
        out = np.zeros_like(t)
        for k in range(1, 9):
            if f * k > RATE / 2.2:
                break
            out += np.sin(ph * k) / k
        return out * 0.6
    if shape == "square":
        out = np.zeros_like(t)
        for k in range(1, 12, 2):
            if f * k > RATE / 2.2:
                break
            out += np.sin(ph * k) / k
        return out * 0.8
    raise ValueError(shape)


def adsr(n, a=0.01, d=0.1, s=0.7, r=0.2):
    env = np.ones(n) * s
    an, dn, rn = int(a * RATE), int(d * RATE), int(r * RATE)
    an = max(1, min(an, n))
    env[:an] = np.linspace(0, 1, an)
    dn = min(dn, n - an)
    if dn > 0:
        env[an:an + dn] = np.linspace(1, s, dn)
    rn = min(rn, n)
    if rn > 0:
        env[-rn:] *= np.linspace(1, 0, rn)
    return env


def lowpass(x, cutoff):
    # One-pole low-pass, applied twice for a gentler 12 dB slope.
    a = np.exp(-2 * np.pi * cutoff / RATE)
    for _ in range(2):
        y = np.empty_like(x)
        acc = 0.0
        b = 1 - a
        for i in range(len(x)):
            acc = b * x[i] + a * acc
            y[i] = acc
        x = y
    return x


def place(track, sound, start):
    i = int(start * RATE)
    end = min(len(track), i + len(sound))
    if i < len(track):
        track[i:end] += sound[:end - i]


def echo(x, delay, feedback, mix):
    d = int(delay * RATE)
    y = x.copy()
    for i in range(d, len(y)):
        y[i] += y[i - d] * feedback
    return x * (1 - mix) + y * mix


# ─── instruments ───────────────────────────────────────────────────────────

def pad(freqs, seconds, bright, shape="saw"):
    out = sum(osc(f, seconds, shape, d) for f in freqs for d in (-0.004, 0.004))
    out = out / (len(freqs) * 2)
    if bright < 1:
        out = out * 0.5 + osc(freqs[0], seconds, "sine") * 0.5 * (1 - bright)
    return out * adsr(len(out), a=0.4, d=0.3, s=0.85, r=0.5)


def pluck(freq, seconds, shape="tri", decay=6.0):
    t = t_axis(seconds)
    return osc(freq, seconds, shape) * np.exp(-decay * t)


def bell(freq, seconds):
    t = t_axis(seconds)
    tone = (np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * freq * 2.76 * t)
            + 0.2 * np.sin(2 * np.pi * freq * 5.4 * t))
    return tone * np.exp(-3.5 * t) * 0.5


def kick(seconds=0.35):
    t = t_axis(seconds)
    f = 120 * np.exp(-18 * t) + 42
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-9 * t)


def snare(seconds=0.25):
    t = t_axis(seconds)
    noise = rng.uniform(-1, 1, len(t))
    return (noise * 0.7 + np.sin(2 * np.pi * 190 * t) * 0.3) * np.exp(-16 * t)


def hat(seconds=0.06):
    t = t_axis(seconds)
    noise = rng.uniform(-1, 1, len(t))
    noise = noise - lowpass(noise, 6000)
    return noise * np.exp(-60 * t)


# ─── songs ─────────────────────────────────────────────────────────────────

THEMES = {
    "space": {
        # Minor, cinematic; stage 5 drifts into a darker Phrygian colour.
        "prog": [("A", "min"), ("F", "maj7"), ("D", "min7"), ("E", "dom")],
        "prog5": [("A", "min"), ("A#", "maj"), ("G", "min"), ("E", "dom")],
        "scale": ["A", "B", "C", "D", "E", "F", "G"],
        "lead": "square", "pad": "saw", "arp": "saw", "melody_octave": 5,
    },
    "easter": {
        # Major and bouncy; stage 5 (moonlit castle) turns mysterious minor.
        "prog": [("C", "maj"), ("G", "maj"), ("A", "min"), ("F", "maj")],
        "prog5": [("A", "min"), ("F", "maj7"), ("C", "maj"), ("E", "dom")],
        "scale": ["C", "D", "E", "G", "A"],
        "lead": "tri", "pad": "tri", "arp": "tri", "melody_octave": 5,
    },
}
TEMPOS = [92, 100, 110, 120, 128]


def song(theme, stage):
    cfg = THEMES[theme]
    bpm = TEMPOS[stage - 1]
    beat = 60 / bpm
    bars = 8
    seconds = bars * 4 * beat
    tail = 2.0
    track = np.zeros(int(RATE * (seconds + tail)))
    prog = cfg["prog5"] if stage == 5 else cfg["prog"]
    melody_rng = np.random.default_rng(100 * stage + (1 if theme == "space" else 2))

    for bar in range(bars):
        root, quality = prog[bar % len(prog)]
        start = bar * 4 * beat
        freqs = chord_freqs(root, quality, 3)
        # 1+: pad and bass
        p = pad(freqs, 4 * beat, bright=0.4 + 0.15 * stage, shape=cfg["pad"])
        place(track, p * (0.22 if theme == "space" else 0.18), start)
        bass_f = hz(root, 2)
        bass_hits = [0, 2] if stage < 4 else [0, 1.5, 2, 3, 3.5]
        for b in bass_hits:
            n = osc(bass_f, beat * 0.9, "tri" if theme == "easter" else "saw")
            place(track, n * adsr(len(n), 0.01, 0.1, 0.6, 0.1) * 0.28, start + b * beat)
        # 2+: melody
        if stage >= 2:
            scale = cfg["scale"]
            steps = [0, 1, 1.5, 2, 3] if stage < 4 else [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
            for s in steps:
                note = scale[melody_rng.integers(len(scale))]
                octv = cfg["melody_octave"] - (1 if melody_rng.random() < 0.3 else 0)
                dur = beat * (0.9 if stage < 4 else 0.45)
                tone = (pluck(hz(note, octv), dur, cfg["lead"], decay=4 if theme == "space" else 7)
                        * 0.16)
                place(track, tone, start + s * beat)
        # 3+: drums
        if stage >= 3:
            for b in range(4):
                if b in (0, 2) or (stage == 5 and b == 3):
                    place(track, kick() * 0.55, start + b * beat)
                for half in (0, 0.5):
                    place(track, hat() * (0.12 if stage < 5 else 0.16), start + (b + half) * beat)
        # 4+: arpeggio and snare
        if stage >= 4:
            arp = chord_freqs(root, quality, 4)
            for k in range(16):
                f = arp[k % len(arp)] * (2 if k % 8 >= 4 else 1)
                n = pluck(f, beat / 4 * 0.95, cfg["arp"], decay=10)
                place(track, n * 0.07, start + k * beat / 4)
            for b in (1, 3):
                place(track, snare() * 0.25, start + b * beat)
        # 5: choir pad, sub bass and shimmering bells
        if stage == 5:
            choir = sum(osc(f * 2, 4 * beat, "sine", d) for f in freqs for d in (-0.006, 0, 0.006))
            choir = choir / (len(freqs) * 3) * adsr(len(choir), 0.6, 0.3, 0.8, 0.6)
            place(track, choir * 0.2, start)
            place(track, osc(bass_f / 2, 4 * beat, "sine") * adsr(int(4 * beat * RATE), 0.05, 0.2, 0.8, 0.3) * 0.22, start)
            for k in (0, 1.5, 2.5):
                place(track, bell(freqs[int(k) % len(freqs)] * 4, beat * 1.5) * 0.12, start + k * beat)

    wet = 0.25 + 0.05 * stage if theme == "space" else 0.15 + 0.04 * stage
    track = echo(track, beat * 0.75, 0.35, wet)
    # Fold the tail onto the start so the loop is seamless.
    n = int(seconds * RATE)
    loop = track[:n].copy()
    loop[:len(track) - n] += track[n:]
    loop /= max(1e-9, np.max(np.abs(loop))) / 0.89
    return loop


# ─── effects ───────────────────────────────────────────────────────────────

def shot(tier):
    """Stage 1 pew → 2 twin laser → 3 plasma → 4 ion beam → 5 nova."""
    dur = [0.14, 0.18, 0.26, 0.34, 0.45][tier - 1]
    t = t_axis(dur)
    if tier == 1:
        f = 1500 * np.exp(-14 * t) + 300
        s = np.sin(2 * np.pi * np.cumsum(f) / RATE)
    elif tier == 2:
        f = 2200 * np.exp(-12 * t) + 400
        s = (np.sign(np.sin(2 * np.pi * np.cumsum(f) / RATE)) * 0.4
             + np.sign(np.sin(2 * np.pi * np.cumsum(f * 1.01) / RATE)) * 0.4)
    elif tier == 3:
        f = 900 * np.exp(-6 * t) + 180
        wob = 1 + 0.3 * np.sin(2 * np.pi * 30 * t)
        s = np.sin(2 * np.pi * np.cumsum(f * wob) / RATE) + 0.3 * rng.uniform(-1, 1, len(t)) * np.exp(-10 * t)
    elif tier == 4:
        f = 140 + 60 * t
        s = sum(np.sin(2 * np.pi * np.cumsum(f * k) / RATE) / k for k in range(1, 7))
        s = s * (0.7 + 0.3 * np.sin(2 * np.pi * 45 * t))
    else:
        f = 2600 * np.exp(-5 * t) + 220
        sweep = np.sin(2 * np.pi * np.cumsum(f) / RATE)
        chord = sum(np.sin(2 * np.pi * hz(n, 5) * t) for n in ("C", "E", "G"))
        s = sweep * 0.6 + chord * 0.25 + 0.25 * rng.uniform(-1, 1, len(t)) * np.exp(-8 * t)
    s = s * adsr(len(s), 0.004, 0.05, 0.8, dur * 0.7)
    return s / max(1e-9, np.max(np.abs(s))) * 0.8


def level_up():
    notes = [("C", 5), ("E", 5), ("G", 5), ("C", 6), ("E", 6)]
    track = np.zeros(int(RATE * 1.4))
    for i, (n, o) in enumerate(notes):
        place(track, bell(hz(n, o), 0.9) * 0.6, i * 0.09)
        place(track, pluck(hz(n, o), 0.3, "square", decay=8) * 0.15, i * 0.09)
    place(track, pad(chord_freqs("C", "maj", 4), 1.0, 1.0, "saw") * 0.18, 0.4)
    return track / max(1e-9, np.max(np.abs(track))) * 0.85


# ─── output ────────────────────────────────────────────────────────────────

def write_wav(path, samples):
    data = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def write_ogg(path, samples):
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        write_wav(wav, samples)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
                        "-c:a", "libvorbis", "-q:a", "3", str(path)], check=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for theme in THEMES:
        for stage in range(1, 6):
            write_ogg(OUT / f"music_{theme}_{stage}.ogg", song(theme, stage))
            print("music", theme, stage)
    for tier in range(1, 6):
        write_wav(OUT / f"shot_{tier}.wav", shot(tier))
    write_wav(OUT / "levelup.wav", level_up())
    print("done")


if __name__ == "__main__":
    main()
