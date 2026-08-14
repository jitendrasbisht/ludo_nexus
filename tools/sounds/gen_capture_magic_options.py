import math
import random
import struct
import wave

SAMPLE_RATE = 44100


def write_wav(path, pcm):
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(struct.pack('<%dh' % len(pcm), *pcm))
    print(f"Wrote {path}")


def to_pcm(samples):
    peak = max(abs(s) for s in samples) or 1.0
    scale = 0.92 / peak
    return [max(-32000, min(32000, round(s * scale * 32000))) for s in samples]


def add_bell(samples, start_t, freq, amp=0.6, dur=0.35):
    # A bright, slightly inharmonic chime -- sine fundamental plus two
    # higher partials each decaying at their own rate, which is what
    # reads as "magical bell" rather than a plain tone.
    n = round(SAMPLE_RATE * dur)
    start_sample = round(start_t * SAMPLE_RATE)
    for j in range(n):
        idx = start_sample + j
        if idx < 0 or idx >= len(samples):
            continue
        tt = j / SAMPLE_RATE
        tone = (
            math.sin(2 * math.pi * freq * tt) * math.exp(-tt * 6) * 0.55
            + math.sin(2 * math.pi * freq * 2.4 * tt) * math.exp(-tt * 10) * 0.28
            + math.sin(2 * math.pi * freq * 3.8 * tt) * math.exp(-tt * 16) * 0.14
        )
        samples[idx] += tone * amp


def add_sparkle(samples, rand, start_t, end_t, count, freq_lo=2600, freq_hi=6000, amp_range=(0.12, 0.28)):
    for _ in range(count):
        t0 = start_t + rand.random() * (end_t - start_t)
        start_sample = round(t0 * SAMPLE_RATE)
        dur_samples = round(SAMPLE_RATE * (0.01 + rand.random() * 0.02))
        freq = freq_lo + rand.random() * (freq_hi - freq_lo)
        amp = amp_range[0] + rand.random() * (amp_range[1] - amp_range[0])
        for j in range(dur_samples):
            idx = start_sample + j
            if idx < 0 or idx >= len(samples):
                continue
            tt = j / SAMPLE_RATE
            env = math.exp(-tt * 220)
            samples[idx] += math.sin(2 * math.pi * freq * tt) * env * amp


# F -- sparkle rise: a quick ascending bell arpeggio with a shimmer of
# sparkle over the top -- "a piece is enchanted and whisked away".
def gen_sparkle_rise():
    rand = random.Random(21)
    duration_ms = 420
    n = round(SAMPLE_RATE * duration_ms / 1000)
    samples = [0.0] * n
    notes = [523.25, 659.25, 783.99, 1046.5]  # C5 E5 G5 C6
    for i, freq in enumerate(notes):
        add_bell(samples, i * 0.055, freq, amp=0.55, dur=0.3)
    add_sparkle(samples, rand, 0.05, duration_ms / 1000, 14)
    return to_pcm(samples)


# G -- magic poof: soft airy swell plus scattered sparkle -- a puff of
# magic smoke that carries the piece away.
def gen_magic_poof():
    rand = random.Random(29)
    duration_ms = 380
    n = round(SAMPLE_RATE * duration_ms / 1000)
    raw = [0.0] * n
    for i in range(n):
        raw[i] = rand.random() * 2 - 1
    # crude low-pass: 3-tap moving average, applied twice, to turn harsh
    # white noise into a soft "whoosh" bed.
    def smooth(sig):
        out = [0.0] * len(sig)
        for i in range(len(sig)):
            a = sig[i - 1] if i > 0 else sig[i]
            b = sig[i]
            c = sig[i + 1] if i < len(sig) - 1 else sig[i]
            out[i] = (a + b + c) / 3
        return out

    smoothed = smooth(smooth(smooth(raw)))
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        progress = i / n
        env = math.sin(math.pi * progress) ** 1.5
        samples[i] += smoothed[i] * env * 0.5
    add_sparkle(samples, rand, 0.05, duration_ms / 1000, 18, amp_range=(0.14, 0.3))
    add_bell(samples, 0.16, 1568.0, amp=0.3, dur=0.22)  # a light high "ting" as it vanishes
    return to_pcm(samples)


# H -- enchant chime: a single rich, shimmering bell -- simple and clean,
# reads as "a spell was cast" on its own.
def gen_enchant_chime():
    rand = random.Random(37)
    duration_ms = 550
    n = round(SAMPLE_RATE * duration_ms / 1000)
    samples = [0.0] * n
    add_bell(samples, 0.0, 1046.5, amp=0.75, dur=0.5)  # C6, long ring
    add_sparkle(samples, rand, 0.02, 0.3, 10, amp_range=(0.1, 0.22))
    return to_pcm(samples)


# I -- spell cast, descending: the mirror of F -- a piece being "unmade"
# and sent home by a downward magical arpeggio.
def gen_spell_descend():
    rand = random.Random(43)
    duration_ms = 420
    n = round(SAMPLE_RATE * duration_ms / 1000)
    samples = [0.0] * n
    notes = [1046.5, 783.99, 659.25, 523.25]  # C6 G5 E5 C5
    for i, freq in enumerate(notes):
        add_bell(samples, i * 0.06, freq, amp=0.55, dur=0.3)
    add_sparkle(samples, rand, 0.05, duration_ms / 1000, 14)
    return to_pcm(samples)


# J -- fairy dust burst: a dense glittery scatter of high chime blips all
# at once -- the most "magic happening right now" of the set.
def gen_fairy_dust():
    rand = random.Random(51)
    duration_ms = 320
    n = round(SAMPLE_RATE * duration_ms / 1000)
    samples = [0.0] * n
    add_sparkle(samples, rand, 0.0, duration_ms / 1000 - 0.05, 32, freq_lo=1800, freq_hi=6500, amp_range=(0.14, 0.32))
    add_bell(samples, 0.0, 880.0, amp=0.35, dur=0.3)
    return to_pcm(samples)


if __name__ == "__main__":
    write_wav("capture_f_sparkle_rise.wav", gen_sparkle_rise())
    write_wav("capture_g_magic_poof.wav", gen_magic_poof())
    write_wav("capture_h_enchant_chime.wav", gen_enchant_chime())
    write_wav("capture_i_spell_descend.wav", gen_spell_descend())
    write_wav("capture_j_fairy_dust.wav", gen_fairy_dust())
