import math
import random
import struct
import wave

SAMPLE_RATE = 44100
DURATION_MS = 600


def generate_roll_wav(path):
    sample_count = round(SAMPLE_RATE * DURATION_MS / 1000)
    samples = [0.0] * sample_count
    rand = random.Random(7)

    # A pure 40-60Hz sine is basically inaudible on a phone/laptop speaker
    # no matter how loud it's mixed -- that's why boosting amplitude alone
    # didn't read as "more bass". Real thickness on small speakers comes
    # from harmonic-rich low-*mid* impacts (roughly 80-250Hz fundamentals
    # with 2nd/3rd harmonics), not deep sub-bass. So: several punchy
    # multi-harmonic "thuds" -- dice thumping the bowl -- instead of a
    # sustained sub-bass hum.
    def add_thud(start_t, amp, freq=95.0, decay_rate=9.0, dur=0.28):
        n = round(SAMPLE_RATE * dur)
        start_sample = round(start_t * SAMPLE_RATE)
        for j in range(n):
            idx = start_sample + j
            if idx >= sample_count or idx < 0:
                continue
            tt = j / SAMPLE_RATE
            env = math.exp(-tt * decay_rate)
            tone = (
                math.sin(2 * math.pi * freq * tt) * 0.55
                + math.sin(2 * math.pi * freq * 2 * tt) * 0.30
                + math.sin(2 * math.pi * freq * 3 * tt) * 0.15
            )
            samples[idx] += tone * env * amp

    thud_times = [0.0, 0.10, 0.22, 0.36, 0.52]
    for i, t0 in enumerate(thud_times):
        add_thud(t0, amp=0.95 * (1.0 - i * 0.1), freq=90.0 + i * 4)

    # Continuous low-mid rumble bed underneath the thuds and clinks, moved
    # up out of true sub-bass into a register small speakers can actually
    # push, so it reads as a felt "weight" through the whole roll.
    for i in range(sample_count):
        t = i / SAMPLE_RATE
        envelope = 1.0 if t < 0.42 else max(0.0, min(1.0, 1.0 - (t - 0.42) / 0.15))
        wobble = 0.55 + 0.45 * math.sin(2 * math.pi * 13 * t)
        rumble = math.sin(2 * math.pi * 100 * t) * 0.5 + math.sin(2 * math.pi * 150 * t + 1.3) * 0.3
        samples[i] += rumble * wobble * 0.22 * envelope

    # Layer 2: cluster of short metallic "clink" transients, dense early,
    # thinning out as the dice settle -- pulled back a bit so the bass
    # leads instead of competing with it.
    t = 0.015
    while t < DURATION_MS / 1000 - 0.03:
        progress = t / (DURATION_MS / 1000)

        freq = 2200.0 + rand.random() * 2400
        clink_duration_ms = 16 + rand.randrange(14)
        start_sample = round(t * SAMPLE_RATE)
        clink_samples = round(SAMPLE_RATE * clink_duration_ms / 1000)
        amp = (0.20 + rand.random() * 0.18) * (1.0 - progress * 0.35)

        for j in range(clink_samples):
            idx = start_sample + j
            if idx >= sample_count:
                break
            tt = j / SAMPLE_RATE
            decay = math.exp(-tt * 95)
            tone = math.sin(2 * math.pi * freq * tt) * 0.7 + math.sin(2 * math.pi * freq * 1.8 * tt) * 0.3
            samples[idx] += tone * decay * amp

        gap = 0.018 + progress * 0.055 + rand.random() * 0.03
        t += gap

    peak = max(abs(s) for s in samples) or 1.0
    scale = 0.92 / peak

    pcm = [max(-32000, min(32000, round(s * scale * 32000))) for s in samples]

    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(struct.pack('<%dh' % len(pcm), *pcm))

    print(f"Wrote {path}")


def generate_click_wav(path):
    duration_ms = 150
    body_freq = 320.0
    click_freq = 1500.0
    sample_count = round(SAMPLE_RATE * duration_ms / 1000)

    attack_samples = max(1, min(sample_count, round(sample_count * 0.04)))
    sustain_samples = round(sample_count * 0.35)

    pcm = []
    for i in range(sample_count):
        t = i / SAMPLE_RATE
        if i < attack_samples:
            envelope = i / attack_samples
        elif i < attack_samples + sustain_samples:
            envelope = 1.0
        else:
            decay_index = i - attack_samples - sustain_samples
            decay_length = sample_count - attack_samples - sustain_samples
            envelope = 1.0 - (decay_index / decay_length)

        body = math.sin(2 * math.pi * body_freq * t) * 0.6
        click = math.sin(2 * math.pi * click_freq * t) * 0.4
        mixed = (body + click) * envelope
        pcm.append(max(-32000, min(32000, round(mixed * 32000))))

    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(struct.pack('<%dh' % len(pcm), *pcm))

    print(f"Wrote {path}")


if __name__ == "__main__":
    generate_roll_wav("dice_roll.wav")
    generate_click_wav("piece_click.wav")
