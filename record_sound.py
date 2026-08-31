#!/usr/bin/env python3
"""MindShaft mic recorder — records your microphone and saves a .wav into the
game's assets/audio/ folder. Run it, make your sound, done.

Usage:
    python record_sound.py <name> [seconds]
    python record_sound.py footstep 2

Saves to: assets/audio/<name>.wav
"""
import sys
import os
import wave
import sounddevice as sd

AUDIO_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "audio")
SAMPLE_RATE = 44100


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python record_sound.py <name> [seconds]")
        print("Example: python record_sound.py footstep 2")
        sys.exit(1)
    name = sys.argv[1]
    if not name.endswith(".wav"):
        name += ".wav"
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 3.0

    os.makedirs(AUDIO_DIR, exist_ok=True)
    out_path = os.path.join(AUDIO_DIR, name)

    print(f"Recording {seconds}s from your mic... make your sound NOW!")
    audio = sd.rec(int(seconds * SAMPLE_RATE), samplerate=SAMPLE_RATE, channels=1, dtype="int16")
    sd.wait()
    print("Done! Saving...")

    with wave.open(out_path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(audio.tobytes())

    print(f"Saved: {out_path}")
    print("Tell me the name and what it's for, and I'll wire it into the game.")


if __name__ == "__main__":
    main()
