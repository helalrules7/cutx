#!/usr/bin/env python3
"""Regenerates every file in Resources/sounds/.

Two kinds of sound live there:

  * Synthesized tones, defined entirely by the code below.
  * Foley trimmed from the royalty-free originals in assets/sounds-original/.
    UI sounds must finish before the user's fingers leave the keys, so each one
    is cut to 130 ms starting at its onset, faded out, and normalized to a
    common peak so no option is jarringly louder than another.

Run from the repository root:  python3 scripts/make-sounds.py
"""
import math
import os
import struct
import subprocess
import tempfile
import wave

RATE = 44100
OUT = "Resources/sounds"
ORIGINALS = "assets/sounds-original"

CLIP_SECONDS = 0.130
FADE_SECONDS = 0.045
TARGET_PEAK = 0.55

FOLEY = {
    "scissors": "mrstokes302-scissors-cut-sfx-mrstokes302-531236.mp3",
    "paper": "creatorshome-tear-a-paper-328149.mp3",
    "knife": "floraphonic-knife-cut-veggies-foley-2-211702.mp3",
    "bush": "freesound_community-bush-cut-103503.mp3",
}


def write(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(s)) for s in samples))
    print("%-14s %4.0f ms" % (name + ".wav", len(samples) / RATE * 1000))


# --- synthesized tones -------------------------------------------------------

def tone(freq, duration, volume=0.28, decay=6.0):
    frames = int(RATE * duration)
    out = []
    for i in range(frames):
        # Short attack then exponential decay — reads as a click, not a beep.
        envelope = min(i / (RATE * 0.004), 1.0) * math.exp(-decay * i / frames)
        out.append(volume * envelope * math.sin(2 * math.pi * freq * i / RATE) * 32767)
    return out


def silence(duration):
    return [0] * int(RATE * duration)


# --- foley trimming ----------------------------------------------------------

def decode(mp3_path, wav_path):
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", "LEI16@44100", "-c", "1", mp3_path, wav_path],
        check=True,
        capture_output=True,
    )


def read(path):
    with wave.open(path) as f:
        raw = f.readframes(f.getnframes())
    return list(struct.unpack("<%dh" % (len(raw) // 2), raw))


def onset(samples):
    """First sample above 10% of peak, backed up 4 ms to keep the attack."""
    peak = max(abs(s) for s in samples) or 1
    threshold = peak * 0.10
    for i, s in enumerate(samples):
        if abs(s) > threshold:
            return max(0, i - int(RATE * 0.004))
    return 0


def trim(samples):
    start = onset(samples)
    clip = samples[start:start + int(RATE * CLIP_SECONDS)]
    if not clip:
        return clip

    fade = int(RATE * FADE_SECONDS)
    for i in range(max(0, len(clip) - fade), len(clip)):
        k = (len(clip) - i) / fade
        clip[i] = clip[i] * k * k

    peak = max(abs(s) for s in clip) or 1
    gain = (TARGET_PEAK * 32767) / peak
    return [max(-32767, min(32767, s * gain)) for s in clip]


def main():
    os.makedirs(OUT, exist_ok=True)

    # Cut: two quick close ticks, like a snip. The default.
    write("snip", tone(1400, 0.03, volume=0.2, decay=12.0)
                  + silence(0.028)
                  + tone(1650, 0.045, volume=0.2, decay=12.0))
    # Cut: a single soft high tick, the most unobtrusive option.
    write("tick", tone(1200, 0.055, volume=0.22, decay=9.0))
    # Paste: lower and softer than any cut sound, so the ear reads it as
    # "landed and settled" rather than "lifted".
    write("paste", tone(440, 0.09, volume=0.24, decay=8.0))

    with tempfile.TemporaryDirectory() as tmp:
        for name, filename in FOLEY.items():
            source = os.path.join(ORIGINALS, filename)
            if not os.path.exists(source):
                print("skipping %s — %s not found" % (name, source))
                continue
            decoded = os.path.join(tmp, name + ".wav")
            decode(source, decoded)
            write(name, trim(read(decoded)))


if __name__ == "__main__":
    main()
