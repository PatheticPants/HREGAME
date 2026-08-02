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


# A NOTE EVERY 1.5 SECONDS, NOT EVERY 2.5.
#
# The first version was so slow it was not a tune, it was a drone with events in
# it -- reported as wanting something more melodic. 1.5 s is still far slower
# than anything with a pulse (the player is reading and a beat competes with
# reading) but it is fast enough that a phrase HANGS TOGETHER: at 2.5 s the ear
# has forgotten the first note before the fourth arrives, and a melody you cannot
# hold in your head is a sequence of pitches.
BEAT = 1.5


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


def plucked(dur, freq, seed=0):
    """A soft attack transient, layered under the bow.

    A note that only swells has no moment of arrival, and a tune made entirely of
    swells is a fog. This is the finger leaving the string: a fast decay with the
    upper partials strongest at the front, which is what gives a phrase its
    rhythm without giving it a beat.
    """
    n = int(dur * SAMPLE_RATE)
    r = random.Random(seed if seed else int(freq * 7))
    out = [0.0] * n
    for p in range(1, 7):
        amp = 1.0 / (p ** 1.5)
        phase = r.uniform(0.0, math.tau)
        w = math.tau * freq * p / SAMPLE_RATE
        # Higher partials die first, exactly as a plucked string does.
        decay = 2.6 + p * 2.2
        for i in range(n):
            t = i / SAMPLE_RATE
            out[i] += amp * math.exp(-decay * t) * math.sin(phase + w * i)
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

def line(notes, octave=0, dur=BEAT, partials=6, tilt=1.0, vib=0.16, pluck=0.0):
    """A melodic line. `None` is a rest, which the mode needs as much as a note.

    A note may be a bare degree or a (degree, beats) pair -- a tune whose notes
    are all the same length is a scale exercise, and the long note at the end of
    a phrase is most of what makes it sound like a phrase.
    """
    out = []
    for i, d in enumerate(notes):
        beats = 1.0
        if isinstance(d, tuple):
            d, beats = d
        span = dur * beats
        if d is None:
            out.extend(silence(span))
            continue
        f = step(d, octave)
        note = swell(bowed(span, f, partials, vib, tilt, seed=1000 + i),
                     0.22, 0.30)
        if pluck > 0.0:
            note = mix(note, gain(plucked(span, f, seed=2000 + i), pluck))
        out.extend(note)
    return out


# THE TUNE.
#
# D Dorian, and it is written to be HELD IN THE HEAD rather than merely to be in
# the right mode. Four phrases in an AABA shape, which is the oldest way there is
# of making thirty seconds feel like a piece rather than a loop:
#
#   A  climbs stepwise off the tonic and falls back, unresolved. Twice, so the
#      ear has it before anything happens to it.
#   B  goes up to the sixth -- the note that makes this Dorian rather than minor,
#      the one that refuses to be sad -- holds it, and comes down the long way.
#   A' the same opening, and this time it lands on the tonic and stays there.
#
# The rests are load-bearing. A tune with no gaps in it cannot be under anything.
PHRASE_A = [0, 2, 3, (4, 2), 3, 2, (1, 2), None,
            2, 3, 4, (5, 2), 4, 3, (2, 3), None]

PHRASE_B = [4, 5, (6, 3), 5, 4, (5, 2), None,
            3, 4, (3, 2), 1, 2, (1, 3), None]

PHRASE_A2 = [0, 2, 3, (4, 2), 3, 2, (1, 2), None,
             2, 1, 2, 3, (2, 2), 1, (0, 4), None]

MELODY = PHRASE_A + PHRASE_A + PHRASE_B + PHRASE_A2

# A bass that MOVES. The first version held one drone under everything, which is
# correct for a room and wrong for a tune: a melody over a static fifth has no
# harmony, so nothing it does can feel like an arrival. This walks under the
# phrases and lands on the tonic exactly where the melody does.
#
# THE BEAT COUNTS MUST MATCH THE MELODY'S, PHRASE FOR PHRASE. The four stems play
# as independent looping voices, so a bass one beat longer than the tune drifts
# against it a little further round every loop, and by the third pass the melody
# is arriving on the wrong chord. `main()` asserts the totals agree rather than
# leaving it to whoever edits a phrase next.
#
#   A  21 beats -> 7 + 7 + 7
#   B  20        -> 7 + 7 + 6
#   A2 22        -> 7 + 7 + 8, the last one held under the final cadence
BASS = ([(0, 7), (4, 7), (0, 7)]
        + [(0, 7), (4, 7), (0, 7)]
        + [(3, 7), (4, 7), (5, 6)]
        + [(0, 7), (4, 7), (0, 8)])


def melody_seconds():
    total = 0.0
    for d in MELODY:
        total += BEAT * (d[1] if isinstance(d, tuple) else 1.0)
    return total


def music_bed():
    """The room, under everything -- and now it MOVES.

    It was one held fifth for forty seconds, which is a room and not a bed: the
    melody above it had no harmony to arrive on, so nothing the tune did could
    feel like an arrival. It walks the same four-chord ground the tune is written
    over and lands on the tonic exactly where the tune does.
    """
    low = line(BASS, octave=-1, partials=5, tilt=1.3, vib=0.04)
    fifth = line([(d[0] + 4, d[1]) for d in BASS], octave=-1, partials=4,
                 tilt=1.45, vib=0.04)
    bed = mix(gain(low, 0.60), gain(fifth, 0.26))
    # Very slow breathing, so a long line does not become a dial tone.
    out = []
    for i, x in enumerate(bed):
        t = i / SAMPLE_RATE
        out.append(x * (0.82 + 0.18 * math.sin(math.tau * t / 23.0)))
    return loop_seam(lowpass(out, 1500))


def music_work():
    """The tune, and it plays only while the candle is burning.

    AABA over the walking bass, with a plucked attack under the bow so a phrase
    has rhythm without having a beat, and a counter-line moving at half speed --
    which is what stops a single voice sounding like a test tone, and what makes
    the sixth in phrase B land as a colour rather than as a note.
    """
    voice = line(MELODY, octave=0, partials=7, tilt=0.90, vib=0.20, pluck=0.34)
    under = line([(d[0] + 2, d[1] * 0.5) for d in BASS], octave=-1,
                 dur=BEAT * 2, partials=5, tilt=1.2, vib=0.06)
    return loop_seam(mix(gain(lowpass(voice, 3000), 0.50),
                         gain(lowpass(under, 1100), 0.22)))


def music_close():
    """The same tune with the light going out of it.

    Same phrase, same bass, same length -- only the colour is taken out: the
    voice loses its pluck and most of its top, and the pedal underneath is
    flattened a quarter tone so it leans without ever resolving. Nothing about
    the melody changes, which is exactly why it can crossfade under the working
    layer with no seam. The player should not be able to say when it happened,
    only that it has.
    """
    voice = line(MELODY, octave=0, partials=5, tilt=1.2, vib=0.08, pluck=0.06)
    pedal = []
    for i, d in enumerate(BASS):
        f = step(d[0], -1) * (2 ** (-0.5 / 12.0))
        pedal.extend(swell(bowed(BEAT * d[1], f, partials=4, vibrato=0.02,
                                 tilt=1.45, seed=500 + i), 0.4, 0.5))
    return loop_seam(mix(gain(lowpass(voice, 1400), 0.34),
                         gain(lowpass(pedal, 700), 0.36)))


def music_cold():
    """The ledger, after the flame. The tune's bones and nothing else.

    Bare fifths on the cadence notes of the phrase, with no bass under them and
    no melody over them. It is the same piece with the warmth removed, so it
    reads as an ending rather than as a different track starting.
    """
    out = []
    for i, d in enumerate([(0, 4), (4, 4), (3, 4), (0, 6), (None, 2),
                           (4, 4), (3, 4), (0, 8), (None, 2)]):
        if d[0] is None:
            out.extend(silence(BEAT * d[1]))
            continue
        span = BEAT * d[1]
        a = bowed(span, step(d[0], 0), partials=3, vibrato=0.02, tilt=1.5,
                  seed=300 + i)
        b = bowed(span, step(d[0] + 4, 0), partials=3, vibrato=0.02, tilt=1.6,
                  seed=400 + i)
        out.extend(swell(mix(gain(a, 0.5), gain(b, 0.28)), 0.42, 0.5))
    return loop_seam(lowpass(out, 2200), 1.2)


STEMS = {
    "music_bed": music_bed,
    "music_work": music_work,
    "music_close": music_close,
    "music_cold": music_cold,
}


def beats(notes):
    total = 0.0
    for d in notes:
        total += d[1] if isinstance(d, tuple) else 1.0
    return total


def main():
    # THE VOICES ARE INDEPENDENT LOOPS AND MUST BE THE SAME LENGTH.
    #
    # AudioDirector plays all four continuously and only fades their volumes, so
    # they stay sample-locked from the moment they start -- but only if they are
    # the same number of beats. A bass one beat longer than the tune drifts a
    # little further every loop until the melody is arriving on the wrong chord,
    # and nothing about that failure looks like a bug in a diff. It is not
    # theoretical: the first version of this file had a 128-beat bass under an
    # 84-beat tune, which left the melody silent for the last quarter of every
    # pass.
    if beats(MELODY) != beats(BASS):
        raise SystemExit(
            "melody is %g beats and the bass is %g: they will drift apart"
            % (beats(MELODY), beats(BASS)))
    print("Writing the score to %s" % os.path.normpath(OUT_DIR))
    for name in sorted(STEMS):
        write(name, STEMS[name]())
    print("Done: %d stems. Replace them with a composer's; the names are the "
          "whole contract." % len(STEMS))


if __name__ == "__main__":
    main()
