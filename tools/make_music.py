#!/usr/bin/env python3
"""Generate the layered score for Hand and Seal.

    python tools/make_music.py

WHAT THIS IS, PLAINLY
---------------------
This is a PLACEHOLDER SCORE, and it is a placeholder in the same sense as
tools/make_placeholder_audio.py: it exists so the music SYSTEM is exercised and
tuned from the first day, because retrofitting adaptive music into a finished
game is the miserable job. It is four synthesised stems from the standard
library. It is not a composer, and a composer should replace it.

Replacing it needs no code change at all. Drop four seamlessly looping files
named music_bed / music_work / music_close / music_cold into audio/ and the game
picks them up: AudioDirector addresses everything by event name, and
SessionController._drive_music only ever asks for a mix of the four.

WHY THESE FOUR
--------------
The game already has four moods and they are already legible from the state
machine, so the stems are cut to them rather than to a guess:

  music_bed    always under everything. A drone on the open fifth D--A. It is
               the room, not a tune, and it is the only layer present while a
               petitioner is speaking.
  music_work   the melody, and it plays ONLY while the clock is running. That
               makes the score say the one thing the game most needs said: this
               is your time being spent. It stops when the wax is struck.
  music_close  the same mode gone dark. Fades in as the candle passes its
               guttering threshold, so the light going and the music going are
               one event.
  music_cold   the ledger, after the flame is out. Bare fifths, no melody, and
               the only layer with no drone under it -- the warmth is what has
               been removed.

THE MUSIC ITSELF
----------------
D Dorian, which is the church mode a chancery clerk would have had in his ears,
and an open-fifth drone under it: that is organum, and it is the sound of the
period without being a pastiche of a specific piece. Slow -- a note every two
and a half seconds -- because the player is reading, and anything with a pulse
competes with the reading.

Every stem is built to a whole number of bars and then crossfaded head-to-tail,
so the loop point is inaudible. Deterministic, so regenerating does not churn.
"""

import math
import os
import random
import struct
import wave

# HALF THE RATE OF THE SOUND EFFECTS, ON PURPOSE. The highest partial anywhere
# in these stems is the melody's seventh at about 1 kHz, so Nyquist at 11025 is
# five times the content and nothing audible is lost — while four forty-second
# stereo-length loops at 22050 put 6.6 MB of PLACEHOLDER into the repository,
# which is a poor trade for a file a composer is expected to overwrite. The
# effects stay at 22050 because a wax drip and a page turn live entirely in the
# top end that this does not have.
SAMPLE_RATE = 11025
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")

rng = random.Random(0x53454C4F)  # "SELO"

# ------------------------------------------------------------------- theory

# D Dorian from D3. The sixth is major, which is the whole character of the mode
# -- it is a minor scale with one note that refuses to be sad, and that is the
# right feeling for this game: the room is grim and the work is not hopeless.
D3 = 146.832


def step(degrees, octave=0):
    """A scale degree in D Dorian, 0 = D3. Semitones: 0 2 3 5 7 9 10."""
    table = [0, 2, 3, 5, 7, 9, 10]
    o, d = divmod(degrees, 7)
    return D3 * (2.0 ** (octave + o)) * (2.0 ** (table[d] / 12.0))


BEAT = 2.5          # seconds a note lasts. Slow on purpose; see the header.
BARS = 8            # phrase length. 8 * 2 * BEAT = 40 s of loop.
BAR_NOTES = 2


# --------------------------------------------------------------- primitives

def silence(dur):
    return [0.0] * int(dur * SAMPLE_RATE)


def mix(*buffers):
    n = max(len(b) for b in buffers)
    out = [0.0] * n
    for b in buffers:
        for i, x in enumerate(b):
            out[i] += x
    return out


def gain(buf, g):
    return [x * g for x in buf]


def lowpass(buf, cutoff):
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / SAMPLE_RATE)
    out, y = [], 0.0
    for x in buf:
        y += a * (x - y)
        out.append(y)
    return out


def bowed(dur, freq, partials=6, vibrato=0.16, tilt=1.0, seed=0):
    """One sustained note with a bow on it.

    Additive, because a bowed string IS a harmonic series and a sawtooth run
    through a filter is a synthesiser pretending to be one. Amplitudes fall off
    as 1/n^tilt, each partial is detuned by a few cents in a fixed direction, and
    the whole thing carries a slow vibrato that starts AFTER the attack -- a
    player does not begin a note with vibrato, they arrive at it.
    """
    n = int(dur * SAMPLE_RATE)
    r = random.Random(seed if seed else int(freq * 100))
    out = [0.0] * n
    for p in range(1, partials + 1):
        detune = 1.0 + r.uniform(-0.0016, 0.0016) * p
        amp = 1.0 / (p ** tilt)
        # Odd partials a touch stronger reads as bowed rather than as an organ.
        if p % 2 == 1:
            amp *= 1.18
        phase = r.uniform(0.0, math.tau)
        w = math.tau * freq * p * detune / SAMPLE_RATE
        for i in range(n):
            t = i / SAMPLE_RATE
            vib = 1.0 + vibrato * 0.01 * math.sin(math.tau * 4.6 * t) \
                * min(1.0, max(0.0, (t - 0.45) / 0.8))
            out[i] += amp * math.sin(phase + w * i * vib)
    return out


def swell(buf, attack=0.34, release=0.42):
    """Bow pressure: on slowly, off slowly, never a click and never a pluck."""
    n = len(buf)
    a = max(1, int(attack * SAMPLE_RATE))
    r = max(1, int(release * SAMPLE_RATE))
    out = []
    for i, x in enumerate(buf):
        if i < a:
            g = (i / a) ** 1.6
        elif i > n - r:
            g = ((n - i) / r) ** 1.5
        else:
            g = 1.0
        out.append(x * g)
    return out


def loop_seam(buf, seconds=1.6):
    """Fold the tail back over the head so the loop point cannot be heard.

    The buffer is shortened by exactly the crossfade, which is what keeps the
    phrase an integer number of bars after the fold.
    """
    n = int(seconds * SAMPLE_RATE)
    n = min(n, len(buf) // 3)
    head = buf[:-n]
    tail = buf[-n:]
    for i in range(n):
        g = i / n
        head[i] = head[i] * g + tail[i] * (1.0 - g)
    return head


def normalise(buf, peak=0.72):
    m = max((abs(x) for x in buf), default=0.0)
    if m < 1e-9:
        return buf
    return [x * (peak / m) for x in buf]


def write(name, buf):
    buf = normalise(buf)
    os.makedirs(os.path.normpath(OUT_DIR), exist_ok=True)
    path = os.path.join(os.path.normpath(OUT_DIR), name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in buf))
    print("  %-14s %5.1f s" % (name, len(buf) / SAMPLE_RATE))


# ------------------------------------------------------------------- stems

def line(notes, octave=0, dur=BEAT, partials=6, tilt=1.0, vib=0.16):
    """A melodic line. `None` is a rest, which the mode needs as much as a note."""
    out = []
    for i, d in enumerate(notes):
        if d is None:
            out.extend(silence(dur))
            continue
        out.extend(swell(bowed(dur, step(d, octave), partials, vib, tilt,
                               seed=1000 + i)))
    return out


def music_bed():
    """The room. An open fifth, breathing, with no tune in it whatever.

    D and A only -- no third, so it commits to neither major nor minor and can
    sit under any of the other three layers without arguing with them.
    """
    total = BARS * BAR_NOTES * BEAT
    low = bowed(total, step(0, -1), partials=5, vibrato=0.05, tilt=1.25, seed=7)
    fifth = bowed(total, step(4, -1), partials=4, vibrato=0.05, tilt=1.35, seed=8)
    bed = mix(gain(low, 0.62), gain(fifth, 0.34))
    # Very slow breathing, so a long drone does not become a dial tone.
    out = []
    for i, x in enumerate(bed):
        t = i / SAMPLE_RATE
        out.append(x * (0.80 + 0.20 * math.sin(math.tau * t / 19.0)))
    return loop_seam(lowpass(out, 1500))


def music_work():
    """The melody, and it plays only while the candle is burning.

    Stepwise and narrow, because a leap draws attention and the player is
    reading. It rises to the sixth once per phrase -- the note that makes the
    mode Dorian -- and does not resolve, because the day does not either.
    """
    phrase = [4, 3, 4, 5, None, 4, 2, 3,
              1, 2, 3, 5, 4, None, 2, 0]
    voice = line(phrase, octave=0, partials=7, tilt=0.92, vib=0.22)
    # A second voice a fifth below at half speed: organum, and it is what stops
    # a single line sounding like a test tone.
    under = line([4, None, 2, None, 0, None, 1, None],
                 octave=-1, dur=BEAT * 2, partials=5, tilt=1.2, vib=0.08)
    return loop_seam(mix(gain(lowpass(voice, 2600), 0.52),
                         gain(lowpass(under, 1200), 0.30)))


def music_close():
    """The same mode with the light going out of it.

    Flatten the sixth and the tune stops being Dorian and becomes Aeolian: the
    one note that refused to be sad gives up. Nothing else changes, which is why
    it can crossfade under the working layer without a seam.
    """
    phrase = [4, 3, 2, 3, None, 1, 2, 1,
              0, None, 1, 0, None, None, 0, None]
    voice = line(phrase, octave=0, partials=5, tilt=1.15, vib=0.10)
    drone = bowed(BARS * BAR_NOTES * BEAT, step(0, -1) * (2 ** (-1 / 12.0)),
                  partials=4, vibrato=0.03, tilt=1.4, seed=11)
    return loop_seam(mix(gain(lowpass(voice, 1500), 0.40),
                         gain(lowpass(drone, 700), 0.34)))


def music_cold():
    """The ledger, after the flame. Bare fifths and no drone under them.

    The warmth is what has been taken away, so this layer is defined by what it
    does not have: no low D holding the room together, and no melody at all.
    """
    out = []
    for i, d in enumerate([0, 4, 3, 0, None, 4, 2, None]):
        if d is None:
            out.extend(silence(BEAT * 2))
            continue
        a = bowed(BEAT * 2, step(d, 0), partials=3, vibrato=0.03, tilt=1.5,
                  seed=300 + i)
        b = bowed(BEAT * 2, step(d + 4, 0), partials=3, vibrato=0.03, tilt=1.6,
                  seed=400 + i)
        out.extend(swell(mix(gain(a, 0.5), gain(b, 0.3)), 0.5, 0.6))
    return loop_seam(lowpass(out, 2200), 1.2)


STEMS = {
    "music_bed": music_bed,
    "music_work": music_work,
    "music_close": music_close,
    "music_cold": music_cold,
}


def main():
    print("Writing the score to %s" % os.path.normpath(OUT_DIR))
    for name in sorted(STEMS):
        write(name, STEMS[name]())
    print("Done: %d stems. Replace them with a composer's; the names are the "
          "whole contract." % len(STEMS))


if __name__ == "__main__":
    main()
