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


# A -- current sound (baseline, unchanged), for comparison.
def gen_current():
    duration_ms = 150
    body_freq = 320.0
    click_freq = 1500.0
    n = round(SAMPLE_RATE * duration_ms / 1000)
    attack = max(1, round(n * 0.04))
    sustain = round(n * 0.35)

    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        if i < attack:
            env = i / attack
        elif i < attack + sustain:
            env = 1.0
        else:
            env = 1.0 - (i - attack - sustain) / (n - attack - sustain)
        body = math.sin(2 * math.pi * body_freq * t) * 0.6
        click = math.sin(2 * math.pi * click_freq * t) * 0.4
        samples.append((body + click) * env)
    return to_pcm(samples)


# B -- soft wood tap: lower thock + a touch of broadband noise for the
# "knock against a wooden board" texture.
def gen_wood_tap():
    rand = random.Random(3)
    duration_ms = 130
    n = round(SAMPLE_RATE * duration_ms / 1000)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 28)
        tone = math.sin(2 * math.pi * 190 * t) * 0.6 + math.sin(2 * math.pi * 380 * t) * 0.2
        noise = (rand.random() * 2 - 1) * 0.25 * math.exp(-t * 70)
        samples[i] = (tone + noise) * env
    return to_pcm(samples)


# C -- crisp tick: very short, higher-pitched, minimal body -- a light
# plastic/hard-token tap.
def gen_crisp_tick():
    duration_ms = 55
    n = round(SAMPLE_RATE * duration_ms / 1000)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 150)
        tone = math.sin(2 * math.pi * 3400 * t) * 0.5 + math.sin(2 * math.pi * 1700 * t) * 0.5
        samples[i] = tone * env
    return to_pcm(samples)


# D -- bouncy pop: a quick downward pitch sweep, like a token hopping to
# the next cell.
def gen_bouncy_pop():
    duration_ms = 100
    n = round(SAMPLE_RATE * duration_ms / 1000)
    samples = [0.0] * n
    f_start, f_end = 900.0, 220.0
    for i in range(n):
        t = i / SAMPLE_RATE
        progress = i / n
        freq = f_start + (f_end - f_start) * progress
        env = math.exp(-t * 22) * (1.0 if t > 0.003 else t / 0.003)
        samples[i] = math.sin(2 * math.pi * freq * t) * env
    return to_pcm(samples)


# E -- glass/ceramic clink: bright, harmonic-rich, short ring -- matches
# the glossy dome token look.
def gen_glass_clink():
    duration_ms = 220
    n = round(SAMPLE_RATE * duration_ms / 1000)
    samples = [0.0] * n
    fundamental = 1900.0
    harmonics = [(1.0, 0.5), (2.01, 0.28), (3.03, 0.14), (4.1, 0.08)]
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 16)
        tone = sum(math.sin(2 * math.pi * fundamental * ratio * t) * amp for ratio, amp in harmonics)
        samples[i] = tone * env
    return to_pcm(samples)


if __name__ == "__main__":
    write_wav("move_a_current.wav", gen_current())
    write_wav("move_b_wood_tap.wav", gen_wood_tap())
    write_wav("move_c_crisp_tick.wav", gen_crisp_tick())
    write_wav("move_d_bouncy_pop.wav", gen_bouncy_pop())
    write_wav("move_e_glass_clink.wav", gen_glass_clink())
