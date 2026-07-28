#!/usr/bin/env python3
"""Generate placeholder sound effects for Hand and Seal.

These are synthesised stubs, not final audio. They exist so the audio hooks are
exercised from day one -- a silent build hides timing mistakes that are miserable
to find later. Everything is deterministic (fixed seed) so regenerating does not
churn the repo.

Run from the project root:

    python tools/make_placeholder_audio.py

Standard library only: no numpy, no external deps.
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")

rng = random.Random(0x48414E44)  # "HAND"


# ---------------------------------------------------------------- primitives

def silence(dur):
    return [0.0] * int(dur * SAMPLE_RATE)


def noise(dur):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(dur * SAMPLE_RATE))]


def sine(dur, freq, phase=0.0):
    n = int(dur * SAMPLE_RATE)
    w = 2.0 * math.pi * freq / SAMPLE_RATE
    return [math.sin(phase + w * i) for i in range(n)]


def sweep(dur, f0, f1, curve=1.0):
    """Sine whose frequency glides f0 -> f1 over the buffer."""
    n = int(dur * SAMPLE_RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = (i / max(1, n - 1)) ** curve
        f = f0 + (f1 - f0) * t
        phase += 2.0 * math.pi * f / SAMPLE_RATE
        out.append(math.sin(phase))
    return out


def lowpass(buf, cutoff):
    """One-pole lowpass. Crude, but this is placeholder audio."""
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / SAMPLE_RATE)
    out, y = [], 0.0
    for x in buf:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(buf, cutoff):
    return [x - y for x, y in zip(buf, lowpass(buf, cutoff))]


def env(buf, attack, decay, curve=2.0):
    """Attack/decay envelope expressed as fractions of the buffer length."""
    n = len(buf)
    a = max(1, int(attack * n))
    d = max(1, int(decay * n))
    out = []
    for i, x in enumerate(buf):
        if i < a:
            g = i / a
        elif i > n - d:
            g = ((n - i) / d) ** curve
        else:
            g = 1.0
        out.append(x * g)
    return out


def mix(*buffers):
    n = max(len(b) for b in buffers)
    out = [0.0] * n
    for b in buffers:
        for i, x in enumerate(b):
            out[i] += x
    return out


def cat(*buffers):
    out = []
    for b in buffers:
        out.extend(b)
    return out


def gain(buf, g):
    return [x * g for x in buf]


def normalise(buf, peak=0.86):
    m = max((abs(x) for x in buf), default=0.0)
    if m < 1e-9:
        return buf
    k = peak / m
    return [x * k for x in buf]


def fade_edges(buf, ms=4):
    """Kill start/end discontinuities so nothing clicks on playback."""
    n = int(SAMPLE_RATE * ms / 1000.0)
    n = min(n, len(buf) // 2)
    for i in range(n):
        g = i / n
        buf[i] *= g
        buf[-1 - i] *= g
    return buf


def write(name, buf):
    buf = fade_edges(normalise(list(buf)))
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in buf
        )
        w.writeframes(frames)
    print("  %-22s %5.2fs" % (name + ".wav", len(buf) / SAMPLE_RATE))


# ------------------------------------------------------------------- recipes
# Paper is filtered noise with a fast attack. Wood and books are low thumps with
# a noise transient on top. Metal is a stack of detuned sines. That is the whole
# palette; it is enough to tell the events apart while tuning.

def paper_pickup():
    body = env(highpass(noise(0.09), 1400), 0.01, 0.9, 2.2)
    tick = env(highpass(noise(0.015), 3800), 0.02, 0.95, 1.4)
    return mix(gain(body, 0.7), gain(tick, 0.55))


def paper_drop():
    body = env(lowpass(noise(0.13), 2600), 0.01, 0.85, 1.8)
    thud = env(sine(0.10, 118), 0.02, 0.9, 2.0)
    return mix(gain(body, 0.62), gain(thud, 0.34))


def paper_slide():
    # Looped while a sheet is actually moving; deliberately dull so it can sit
    # under everything without fighting the transients.
    n = lowpass(highpass(noise(0.60), 900), 5200)
    wobble = [1.0 + 0.35 * math.sin(2 * math.pi * 7.3 * i / SAMPLE_RATE)
              for i in range(len(n))]
    return [x * w * 0.5 for x, w in zip(n, wobble)]


def page_turn():
    swish = env(highpass(noise(0.26), 1100), 0.06, 0.6, 1.6)
    # A second, brighter pass a beat later reads as the sheet flopping over.
    flop = cat(silence(0.16), env(highpass(noise(0.12), 2400), 0.02, 0.85, 2.0))
    return mix(gain(swish, 0.6), gain(flop, 0.5))


def book_open():
    creak = env(lowpass(sweep(0.34, 190, 128), 1800), 0.08, 0.55, 1.4)
    rustle = env(highpass(noise(0.34), 1300), 0.1, 0.6, 1.5)
    return mix(gain(creak, 0.4), gain(rustle, 0.45))


def book_close():
    thud = env(sine(0.22, 84), 0.005, 0.9, 2.4)
    slap = env(lowpass(noise(0.18), 2200), 0.005, 0.9, 2.0)
    return mix(gain(thud, 0.7), gain(slap, 0.5))


def wax_drip():
    # A drop landing: tiny tick, then a soft low bloop as it spreads.
    tick = env(highpass(noise(0.012), 4200), 0.05, 0.9, 1.2)
    bloop = env(sweep(0.13, 420, 165, 0.6), 0.05, 0.8, 2.2)
    return mix(gain(tick, 0.4), gain(bloop, 0.55))


def spoon_clink():
    # A small brass utensil, brighter and shorter than the heavy signet.
    metal = mix(sine(0.24, 1410), gain(sine(0.24, 2115), 0.52),
                gain(sine(0.24, 3290), 0.25))
    touch = env(highpass(noise(0.018), 3100), 0.01, 0.95, 1.4)
    return mix(gain(env(metal, 0.003, 0.94, 3.1), 0.55), gain(touch, 0.3))


def wax_melt():
    # Low wet simmer. Several slow oscillations keep it from reading as static.
    n = lowpass(highpass(noise(0.80), 420), 2600)
    wobble = [0.45 + 0.25 * math.sin(2 * math.pi * 4.7 * i / SAMPLE_RATE)
              + 0.12 * math.sin(2 * math.pi * 11.3 * i / SAMPLE_RATE)
              for i in range(len(n))]
    return gain([x * w for x, w in zip(n, wobble)], 0.55)


def wax_ready():
    # A tiny viscous pop marks the transition without sounding like UI.
    pop = env(sweep(0.14, 310, 128, 0.55), 0.02, 0.88, 2.3)
    skin = env(lowpass(noise(0.09), 1800), 0.01, 0.9, 1.8)
    return mix(gain(pop, 0.62), gain(skin, 0.25))


def wax_pour():
    return gain(lowpass(highpass(noise(0.7), 260), 1500), 0.5)


def wax_sizzle():
    return gain(highpass(noise(0.5), 5200), 0.32)


def ring_pickup():
    ting = mix(sine(0.28, 1870), gain(sine(0.28, 2640), 0.5),
               gain(sine(0.28, 3910), 0.28))
    return env(ting, 0.004, 0.92, 3.0)


def ring_press():
    # The resistance phase: a low strained creak, no impact yet.
    return gain(env(lowpass(sweep(0.30, 96, 74), 900), 0.2, 0.5, 1.2), 0.75)


def ring_seat():
    # The give. Hard low thump plus a short bright click as metal meets wood.
    thump = env(sine(0.16, 68), 0.003, 0.9, 2.6)
    click = env(highpass(noise(0.02), 3000), 0.02, 0.95, 1.3)
    ring = env(gain(sine(0.16, 1240), 0.18), 0.01, 0.9, 3.0)
    return mix(gain(thump, 0.85), gain(click, 0.4), ring)


def ring_lift():
    # The peel: rising, sticky, ending in a small release.
    peel = env(lowpass(highpass(noise(0.22), 700), 4400), 0.15, 0.5, 1.2)
    rise = env(sweep(0.22, 210, 640, 1.8), 0.2, 0.5, 1.6)
    snap = cat(silence(0.19), env(highpass(noise(0.03), 2600), 0.03, 0.9, 1.4))
    return mix(gain(peel, 0.5), gain(rise, 0.22), gain(snap, 0.45))


def door_knock():
    def rap():
        return mix(
            env(sine(0.11, 96), 0.004, 0.9, 2.6),
            gain(env(lowpass(noise(0.09), 1700), 0.004, 0.9, 2.2), 0.5),
        )
    return cat(rap(), silence(0.15), rap(), silence(0.17), rap(), silence(0.25))


def door_open():
    creak = env(lowpass(sweep(0.55, 150, 95), 1200), 0.15, 0.6, 1.3)
    return gain(creak, 0.55)


def door_close():
    return mix(env(sine(0.24, 62), 0.004, 0.9, 2.4),
               gain(env(lowpass(noise(0.16), 1400), 0.004, 0.9, 2.0), 0.45))


def cloth_shift():
    return gain(env(highpass(noise(0.30), 1900), 0.2, 0.6, 1.4), 0.42)


def quill_scratch():
    n = highpass(noise(0.42), 2600)
    grain = [1.0 + 0.6 * math.sin(2 * math.pi * 41 * i / SAMPLE_RATE)
             for i in range(len(n))]
    return gain(env([x * g for x, g in zip(n, grain)], 0.05, 0.4, 1.3), 0.4)


def ledger_thud():
    return mix(env(sine(0.42, 52), 0.003, 0.92, 2.2),
               gain(env(lowpass(noise(0.3), 1100), 0.003, 0.9, 1.9), 0.5))


def candle_light():
    return gain(env(lowpass(highpass(noise(0.28), 500), 3600), 0.12, 0.65, 1.5), 0.5)


def candle_catch():
    # The first disturbed paper changes the candle from light to clock: a tiny
    # intake of air and a bright dry tick, audible only once per matter.
    breath = env(lowpass(highpass(noise(0.24), 420), 2800), 0.05, 0.78, 1.7)
    tick = env(sweep(0.11, 1180, 620, 1.3), 0.01, 0.92, 2.4)
    return mix(gain(breath, 0.42), gain(tick, 0.18))


def room_tone():
    # 3s loopable bed: low rumble plus a hint of air. Kept very quiet.
    rumble = lowpass(noise(3.0), 110)
    air = gain(lowpass(highpass(noise(3.0), 1800), 5000), 0.06)
    return gain(mix(rumble, air), 0.22)


def stamp_set():
    return mix(env(sine(0.13, 140), 0.004, 0.9, 2.4),
               gain(env(highpass(noise(0.05), 2200), 0.01, 0.9, 1.6), 0.35))


def stow_in():
    # Something heavy sliding into a wooden pigeonhole and stopping against the
    # back of it: a short scrape, then a soft knock.
    scrape = env(lowpass(highpass(noise(0.20), 600), 3200), 0.08, 0.55, 1.3)
    knock = cat(silence(0.15),
                mix(env(sine(0.11, 108), 0.005, 0.9, 2.3),
                    gain(env(lowpass(noise(0.09), 1500), 0.005, 0.9, 2.0), 0.45)))
    return mix(gain(scrape, 0.42), gain(knock, 0.62))


def stow_out():
    # The same in reverse: a knock as it clears the lip, then the scrape.
    tug = env(lowpass(noise(0.05), 2400), 0.02, 0.9, 1.6)
    scrape = cat(silence(0.03),
                 env(lowpass(highpass(noise(0.22), 700), 3600), 0.10, 0.6, 1.2))
    return mix(gain(tug, 0.5), gain(scrape, 0.45))


def candle_gutter():
    # The wick reaching its own wax: a wet stutter in the flame, low and uneven.
    body = lowpass(highpass(noise(0.85), 180), 1400)
    stutter = [1.0 + 0.85 * math.sin(2 * math.pi * 5.3 * i / SAMPLE_RATE)
               * math.sin(2 * math.pi * 1.7 * i / SAMPLE_RATE)
               for i in range(len(body))]
    return gain(env([x * s for x, s in zip(body, stutter)], 0.15, 0.45, 1.2), 0.42)


def candle_out():
    # The end of the day. A last soft puff, then room tone with nothing in it.
    puff = env(lowpass(highpass(noise(0.26), 240), 2600), 0.03, 0.80, 1.5)
    drop = env(sweep(0.30, 190, 62, 1.4), 0.05, 0.70, 2.0)
    return mix(gain(puff, 0.60), gain(drop, 0.22))


def stylus_scratch():
    # Bronze cutting cold wax: thinner, drier and grittier than a quill, and
    # looped while the nib is actually moving.
    n = highpass(noise(0.55), 3400)
    grain = [1.0 + 0.75 * math.sin(2 * math.pi * 63 * i / SAMPLE_RATE)
             for i in range(len(n))]
    return gain([x * g for x, g in zip(n, grain)], 0.34)


def wax_smooth():
    # The flat of the stylus dragging marks back under. Soft, low, brief.
    return gain(env(lowpass(highpass(noise(0.18), 420), 1900), 0.12, 0.6, 1.4),
                0.40)


def view_shift():
    # A chair and a back taking the strain as the notary sits up off close work.
    # Low, woody, brief — it must never sound like a UI transition.
    creak = env(lowpass(highpass(noise(0.38), 130), 900), 0.16, 0.55, 1.3)
    body = env(sweep(0.30, 84, 62, 1.2), 0.14, 0.6, 1.8)
    return mix(gain(creak, 0.42), gain(body, 0.26))


def footfall():
    # One boot on a board floor, heard across a room: a soft low thud with a
    # little grit, and no ring.
    thud = env(sine(0.11, 74), 0.006, 0.9, 2.5)
    grit = env(lowpass(highpass(noise(0.07), 900), 3600), 0.02, 0.9, 1.7)
    return mix(gain(thud, 0.62), gain(grit, 0.28))


RECIPES = {
    "view_shift": view_shift,
    "footfall": footfall,
    "stylus_scratch": stylus_scratch,
    "wax_smooth": wax_smooth,
    "candle_gutter": candle_gutter,
    "candle_catch": candle_catch,
    "candle_out": candle_out,
    "stow_in": stow_in,
    "stow_out": stow_out,
    "paper_pickup": paper_pickup,
    "paper_drop": paper_drop,
    "paper_slide": paper_slide,
    "page_turn": page_turn,
    "book_open": book_open,
    "book_close": book_close,
    "spoon_clink": spoon_clink,
    "wax_melt": wax_melt,
    "wax_ready": wax_ready,
    "wax_drip": wax_drip,
    "wax_pour": wax_pour,
    "wax_sizzle": wax_sizzle,
    "ring_pickup": ring_pickup,
    "ring_press": ring_press,
    "ring_seat": ring_seat,
    "ring_lift": ring_lift,
    "door_knock": door_knock,
    "door_open": door_open,
    "door_close": door_close,
    "cloth_shift": cloth_shift,
    "quill_scratch": quill_scratch,
    "ledger_thud": ledger_thud,
    "candle_light": candle_light,
    "room_tone": room_tone,
    "stamp_set": stamp_set,
}


def main():
    out = os.path.normpath(OUT_DIR)
    os.makedirs(out, exist_ok=True)
    print("Writing placeholder audio to %s" % out)
    for name in sorted(RECIPES):
        write(name, RECIPES[name]())
    print("Done: %d files." % len(RECIPES))


if __name__ == "__main__":
    main()
