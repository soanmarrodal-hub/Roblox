"""Effets sonores 8 bits de l'interface (style console rétro, assorti au pixel art), synthétisés en Python.

Chaque son est une petite partition : notes en ondes carrées / triangles / dents de scie / bruit, avec
enveloppe (attaque, chute), glissando, vibrato et écho. Aucun échantillon externe : tout est généré.

    python3 tools/audio/sfx.py            → assets/sfx/<Nom>.ogg (à téléverser sur Roblox, voir
                                            UI/SoundAssets.luau) et assets/sfx/apercu.mp3 (tous les sons à la suite)
    python3 tools/audio/sfx.py Coin Gem   → seulement ces sons
Nécessite numpy et ffmpeg (conversion en .ogg / .mp3).
"""
from __future__ import annotations

import math
import os
import subprocess
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'sfx')
RATE = 44100

# --------------------------------------------------------------------------- synthèse

NOTES = {'C': -9, 'C#': -8, 'D': -7, 'D#': -6, 'E': -5, 'F': -4, 'F#': -3, 'G': -2, 'G#': -1, 'A': 0, 'A#': 1, 'B': 2}


def hz(note):
    """'A4' → 440 ; 'C#6' → … ; un nombre est renvoyé tel quel."""
    if isinstance(note, (int, float)):
        return float(note)
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((NOTES[name] + 12 * (octave - 4)) / 12)


_rng = np.random.default_rng(7)


def tone(f0, dur, wave_='square', f1=None, vol=1.0, attack=0.004, decay=None, duty=0.5, vib=0.0, vib_rate=7.0,
         curve='exp'):
    """Une note : fréquence f0 (glissando vers f1), enveloppe attaque + chute (exponentielle ou linéaire)."""
    n = max(1, int(dur * RATE))
    t = np.arange(n) / RATE
    a, b = hz(f0), hz(f1 if f1 is not None else f0)
    if curve == 'exp' and a > 0 and b > 0:
        freq = a * (b / a) ** (t / dur)
    else:
        freq = a + (b - a) * (t / dur)
    if vib:
        freq = freq * (1 + vib * np.sin(2 * math.pi * vib_rate * t))
    phase = np.cumsum(freq) / RATE
    frac = phase % 1.0
    if wave_ == 'square':
        y = np.where(frac < duty, 1.0, -1.0)
    elif wave_ == 'triangle':
        y = 4 * np.abs(frac - 0.5) - 1
    elif wave_ == 'saw':
        y = 2 * frac - 1
    elif wave_ == 'sine':
        y = np.sin(2 * math.pi * phase)
    elif wave_ == 'noise':
        # bruit « 8 bits » : valeur aléatoire maintenue pendant une période de la fréquence
        steps = np.floor(phase * 2).astype(np.int64)
        vals = _rng.uniform(-1, 1, steps.max() + 2)
        y = vals[steps]
    else:
        raise ValueError(wave_)
    env = np.ones(n)
    na = int(attack * RATE)
    if na > 0:
        env[:na] = np.linspace(0, 1, na)
    d = decay if decay is not None else dur
    env *= np.exp(-t / max(d, 1e-3) * 3.0) if d < dur * 4 else 1.0
    nr = min(n, int(0.006 * RATE))  # petite rampe de fin : pas de clic
    env[-nr:] *= np.linspace(1, 0, nr)
    return y * env * vol


def silence(dur):
    return np.zeros(int(dur * RATE))


def seq(*parts):
    return np.concatenate(parts)


def mix(*parts, offsets=None):
    offsets = offsets or [0.0] * len(parts)
    n = max(int(o * RATE) + len(p) for p, o in zip(parts, offsets))
    out = np.zeros(n)
    for p, o in zip(parts, offsets):
        s = int(o * RATE)
        out[s:s + len(p)] += p
    return out


def arp(notes, step, wave_='square', vol=0.8, decay=None, duty=0.5, last=None):
    """Arpège : notes jouées l'une après l'autre ; la dernière peut durer plus longtemps."""
    parts = []
    for i, nt in enumerate(notes):
        d = last if (last and i == len(notes) - 1) else step
        parts.append(tone(nt, d, wave_, vol=vol, decay=decay or d * 0.9, duty=duty))
    return seq(*parts)


def echo(y, delay=0.07, fb=0.35, n=3):
    out = np.concatenate([y, np.zeros(int(delay * RATE * n))])
    for k in range(1, n + 1):
        s = int(delay * RATE * k)
        out[s:s + len(y)] += y * (fb ** k)
    return out


def lowpass(y, k=0.2):
    """Filtre passe-bas d'ordre 1 (adoucit le bruit et les carrés)."""
    out = np.empty_like(y)
    acc = 0.0
    for i, v in enumerate(y):
        acc += k * (v - acc)
        out[i] = acc
    return out


# --------------------------------------------------------------------------- les sons

def s_click():
    return tone('A6', 0.035, 'square', vol=0.6, decay=0.02, duty=0.25)


def s_hover():
    return tone('E7', 0.025, 'triangle', vol=0.35, decay=0.012)


def s_open():
    return mix(arp(['C5', 'G5'], 0.05, 'square', vol=0.45, duty=0.25, last=0.09),
               lowpass(tone(300, 0.12, 'noise', f1=1800, vol=0.25, decay=0.08), 0.25))


def s_close():
    return arp(['G5', 'C5'], 0.045, 'square', vol=0.4, duty=0.25, last=0.08)


def s_tab():
    return seq(tone('C7', 0.02, 'triangle', vol=0.5, decay=0.015), silence(0.015), tone('G7', 0.025, 'triangle', vol=0.45, decay=0.02))


def s_error():
    return seq(tone(196, 0.09, 'square', vol=0.5, duty=0.5, decay=0.2), silence(0.02),
               tone(147, 0.16, 'square', vol=0.5, duty=0.5, decay=0.2, vib=0.03))


def s_notify():
    return echo(seq(tone('E6', 0.07, 'triangle', vol=0.6, decay=0.08), tone('B6', 0.14, 'triangle', vol=0.6, decay=0.12)), 0.08, 0.3, 2)


def s_success():
    return echo(arp(['C6', 'E6', 'G6'], 0.05, 'square', vol=0.4, duty=0.25, last=0.14), 0.07, 0.3, 2)


def s_pop():
    return tone(380, 0.07, 'sine', f1=1300, vol=0.8, decay=0.05)


def s_coin():
    return seq(tone('B5', 0.06, 'square', vol=0.45, duty=0.5, decay=0.2), tone('E6', 0.26, 'square', vol=0.45, duty=0.5, decay=0.12))


def s_gem():
    return echo(arp(['C7', 'E7', 'G7', 'C8'], 0.035, 'triangle', vol=0.55, last=0.12), 0.06, 0.4, 3)


def s_rune():
    return mix(tone('A5', 0.35, 'triangle', vol=0.4, decay=0.25, vib=0.02, vib_rate=9),
               tone('E6', 0.35, 'triangle', vol=0.3, decay=0.25, vib=0.02, vib_rate=9), offsets=[0, 0.04])


def s_reward():
    return echo(arp(['C5', 'E5', 'G5', 'C6', 'E6'], 0.055, 'square', vol=0.4, duty=0.25, last=0.22), 0.09, 0.3, 2)


def s_fanfare():
    lead = seq(tone('G5', 0.09, 'square', vol=0.6, duty=0.25, decay=0.3), silence(0.02),
               tone('G5', 0.09, 'square', vol=0.6, duty=0.25, decay=0.3), silence(0.02),
               tone('G5', 0.09, 'square', vol=0.6, duty=0.25, decay=0.3), silence(0.02),
               tone('C6', 0.45, 'square', vol=0.45, duty=0.25, decay=0.5, vib=0.01))
    bass = seq(silence(0.33), tone('C4', 0.45, 'triangle', vol=0.35, decay=0.5))
    harm = seq(silence(0.33), tone('E5', 0.45, 'square', vol=0.15, duty=0.125, decay=0.5))
    return mix(lead, bass, harm)


def s_levelup():
    up = arp(['C5', 'D5', 'E5', 'F5', 'G5', 'A5', 'B5', 'C6'], 0.035, 'square', vol=0.6, duty=0.25, decay=0.08)
    chord = mix(tone('C6', 0.5, 'square', vol=0.25, duty=0.25, decay=0.45), tone('E6', 0.5, 'square', vol=0.2, duty=0.125, decay=0.45),
                tone('G6', 0.5, 'triangle', vol=0.3, decay=0.45), tone('C4', 0.5, 'triangle', vol=0.35, decay=0.45))
    return echo(seq(up, chord), 0.1, 0.25, 2)


def s_purchase():
    ching = lowpass(tone(6000, 0.18, 'noise', vol=0.35, decay=0.08), 0.6)
    return mix(s_coin(), ching, tone('E7', 0.2, 'triangle', vol=0.3, decay=0.12), offsets=[0, 0.05, 0.07])


def s_unlock():
    return seq(tone(200, 0.12, 'square', f1=900, vol=0.35, duty=0.25, decay=0.3),
               tone('C7', 0.03, 'square', vol=0.5, duty=0.25, decay=0.02), silence(0.02),
               tone('G6', 0.12, 'triangle', vol=0.5, decay=0.1))


def s_summon():
    sweep = tone(220, 0.7, 'square', f1=1100, vol=0.3, duty=0.25, decay=1.5, vib=0.04, vib_rate=11)
    shimmer = lowpass(tone(2000, 0.7, 'noise', f1=8000, vol=0.18, decay=1.0), 0.35)
    return mix(sweep, shimmer)


def s_reveal():
    whoosh = lowpass(tone(3000, 0.18, 'noise', f1=500, vol=0.35, decay=0.12), 0.3)
    return mix(whoosh, tone(500, 0.08, 'sine', f1=1400, vol=0.6, decay=0.06), offsets=[0, 0.12])


def s_reveal_rare():
    return mix(s_reveal(), echo(arp(['E6', 'G#6', 'B6', 'E7'], 0.04, 'triangle', vol=0.5, last=0.2), 0.07, 0.35, 3), offsets=[0, 0.12])


def s_equip():
    return seq(lowpass(tone(4000, 0.03, 'noise', vol=0.5, decay=0.02), 0.5), silence(0.025),
               tone('D6', 0.06, 'square', vol=0.35, duty=0.125, decay=0.04))


def s_trash():
    return mix(arp(['E5', 'C5', 'A4'], 0.06, 'square', vol=0.35, duty=0.25, last=0.1),
               lowpass(tone(1500, 0.2, 'noise', f1=300, vol=0.2, decay=0.12), 0.2))


def s_whoosh():
    return lowpass(tone(600, 0.22, 'noise', f1=4000, vol=0.4, decay=0.15), 0.18)


def s_toggle():
    return seq(tone('G6', 0.025, 'square', vol=0.35, duty=0.25, decay=0.02), silence(0.02), tone('C7', 0.03, 'square', vol=0.35, duty=0.25, decay=0.02))


SOUNDS = {
    'Click': s_click, 'Hover': s_hover, 'Open': s_open, 'Close': s_close, 'Tab': s_tab, 'Error': s_error,
    'Notify': s_notify, 'Success': s_success, 'Pop': s_pop, 'Coin': s_coin, 'Gem': s_gem, 'Rune': s_rune,
    'Reward': s_reward, 'Fanfare': s_fanfare, 'LevelUp': s_levelup, 'Purchase': s_purchase, 'Unlock': s_unlock,
    'Summon': s_summon, 'Reveal': s_reveal, 'RevealRare': s_reveal_rare, 'Equip': s_equip, 'Trash': s_trash,
    'Whoosh': s_whoosh, 'Toggle': s_toggle,
}


# --------------------------------------------------------------------------- export

def normalize(y, peak=0.7):
    m = float(np.max(np.abs(y))) if len(y) else 0.0
    return y * (peak / m) if m > 0 else y


def write_wav(path, y):
    data = (np.clip(y, -1, 1) * 32767).astype('<i2').tobytes()
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def convert(src, dst, args):
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', src] + args + [dst], check=True)


def main(only=None):
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, '_tmp.wav')
    preview = []
    for name, fn in SOUNDS.items():
        if only and name not in only:
            continue
        y = normalize(fn())
        write_wav(tmp, y)
        convert(tmp, os.path.join(OUT, name + '.ogg'), ['-c:a', 'libvorbis', '-q:a', '5'])
        preview += [y, silence(0.35)]
        print('%-11s %.2f s' % (name, len(y) / RATE))
    if not only:
        write_wav(tmp, np.concatenate(preview))
        convert(tmp, os.path.join(OUT, 'apercu.mp3'), ['-c:a', 'libmp3lame', '-q:a', '4'])
    os.remove(tmp)


if __name__ == '__main__':
    main(set(sys.argv[1:]) or None)
