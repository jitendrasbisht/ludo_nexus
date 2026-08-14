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


def noise_sample(rand, t, decay_rate, cutoff_mix=0.5):
    # crude "filtered" noise: blend raw white noise with a smoothed
    # (lag-averaged) version to soften the harshness a bit.
    return (rand.random() * 2 - 1) * math.exp(-t * decay_rate)


# A -- whack + thud: a noisy impact transient over a low multi-harmonic
# thud, like a piece getting knocked off the board.
def gen_whack_thud():
    rand = random.Random(11)
    duration_ms = 220
    n = round(SAMPLE_RATE * duration_ms / 1000)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        noise = noise_sample(rand, t, 55) * 0.5
        thud = (
            math.sin(2 * math.pi * 110 * t) * 0.6
            + math.sin(2 * math.pi * 220 * t) * 0.3
        ) * math.exp(-t * 16)
        samples[i] = noise + thud
    return to_pcm(samples)


# B -- swoosh downfall + landing: the captured piece flying back to base --
# a descending sweep then a soft thud on landing.
def gen_swoosh_downfall():
    duration_ms = 260
    n = round(SAMPLE_RATE * duration_ms / 1000)
    samples = [0.0] * n
    f_start, f_end = 1800.0, 260.0
    sweep_end = 0.16
    for i in range(n):
        t = i / SAMPLE_RATE
        if t < sweep_end:
            progress = t / sweep_end
            freq = f_start + (f_end - f_start) * progress
            env = math.sin(math.pi * progress) * 0.8
            samples[i] += math.sin(2 * math.pi * freq * t) * env
        else:
            tt = t - sweep_end
            env = math.exp(-tt * 20)
            samples[i] += (
                math.sin(2 * math.pi * 130 * tt) * 0.6 + math.sin(2 * math.pi * 195 * tt) * 0.3
            ) * env
    return to_pcm(samples)


# C -- playful "gotcha" sting: two quick bright descending notes, fun
# rather than harsh.
def gen_gotcha_sting():
    duration_ms = 240
    n = round(SAMPLE_RATE * duration_ms / 1000)
    samples = [0.0] * n
    notes = [(0.0, 880.0, 0.09), (0.10, 560.0, 0.13)]
    for start_t, freq, dur in notes:
        start_sample = round(start_t * SAMPLE_RATE)
        note_n = round(SAMPLE_RATE * dur)
        for j in range(note_n):
            idx = start_sample + j
            if idx >= n:
                break
            tt = j / SAMPLE_RATE
            env = math.exp(-tt * 18) * (1.0 if tt > 0.004 else tt / 0.004)
            tone = math.sin(2 * math.pi * freq * tt) * 0.7 + math.sin(2 * math.pi * freq * 2 * tt) * 0.2
            samples[idx] += tone * env
    return to_pcm(samples)


# D -- crash/shatter: bright noisy transient, more dramatic/aggressive.
def gen_crash_shatter():
    rand = random.Random(19)
    duration_ms = 200
    n = round(SAMPLE_RATE * duration_ms / 1000)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 20)
        noise = (rand.random() * 2 - 1) * env
        shimmer = sum(
            math.sin(2 * math.pi * f * t) * 0.15 for f in (2600, 3400, 4200)
        ) * env
        samples[i] = noise * 0.55 + shimmer
    return to_pcm(samples)


# E -- big bonk: an exaggerated, lower/longer version of the move "pop" --
# a solid knock-out hit.
def gen_big_bonk():
    duration_ms = 240
    n = round(SAMPLE_RATE * duration_ms / 1000)
    samples = [0.0] * n
    f_start, f_end = 500.0, 90.0
    for i in range(n):
        t = i / SAMPLE_RATE
        progress = i / n
        freq = f_start + (f_end - f_start) * progress
        env = math.exp(-t * 12) * (1.0 if t > 0.004 else t / 0.004)
        tone = (
            math.sin(2 * math.pi * freq * t) * 0.6
            + math.sin(2 * math.pi * freq * 2 * t) * 0.3
            + math.sin(2 * math.pi * freq * 3 * t) * 0.1
        )
        samples[i] = tone * env
    return to_pcm(samples)


if __name__ == "__main__":
    write_wav("capture_a_whack_thud.wav", gen_whack_thud())
    write_wav("capture_b_swoosh_downfall.wav", gen_swoosh_downfall())
    write_wav("capture_c_gotcha_sting.wav", gen_gotcha_sting())
    write_wav("capture_d_crash_shatter.wav", gen_crash_shatter())
    write_wav("capture_e_big_bonk.wav", gen_big_bonk())
