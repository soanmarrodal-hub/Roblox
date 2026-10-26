"""Vues 3D en perspective du jeu, hors de Roblox : terrain exporté (tools/preview/terrain_dump.luau), pièces
réellement construites par le serveur (WORLD_DUMP du banc d'essai) et personnages voxel (héros, ennemis).

Rendu logiciel : rastériseur en C (compilé à la volée) avec tampon de profondeur, carte d'ombres du soleil
(ombres douces 3×3), lumière ambiante d'hémisphère, néons émissifs, eau transparente, brume et ciel en dégradé,
suréchantillonnage ×2.

    python3 tools/voxel/scene_render.py <pièces.json> <dossier des terrains> <dossier de sortie> [vue…]
"""
from __future__ import annotations

import ctypes
import json
import math
import os
import struct
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

# ------------------------------------------------------------------ rastériseur C

C_SRC = r"""
#include <math.h>
static inline float edge(float ax, float ay, float bx, float by, float px, float py) {
    return (bx - ax) * (py - ay) - (by - ay) * (px - ax);
}
/* ---- bruits pour les textures procédurales des matériaux ---- */
static inline unsigned int ih(int x, int y, int z) {
    unsigned int h = (unsigned int)x * 374761393u + (unsigned int)y * 668265263u + (unsigned int)z * 2246822519u;
    h = (h ^ (h >> 13)) * 1274126177u;
    return h ^ (h >> 16);
}
static inline float h01(int x, int y, int z) { return (float)(ih(x, y, z) & 0xffffff) / 16777216.0f; }
static inline float sm(float t) { return t * t * (3.0f - 2.0f * t); }
static inline float clampf(float v, float a, float b) { return v < a ? a : (v > b ? b : v); }
static float vn(float x, float y, int s) {
    int ix = (int)floorf(x), iy = (int)floorf(y);
    float fx = sm(x - ix), fy = sm(y - iy);
    float a = h01(ix, iy, s), b = h01(ix + 1, iy, s), c = h01(ix, iy + 1, s), d = h01(ix + 1, iy + 1, s);
    return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy;
}
static float fbm(float x, float y, int s) {
    return vn(x, y, s) * 0.5f + vn(x * 2.03f, y * 2.03f, s + 1) * 0.3f + vn(x * 4.1f, y * 4.1f, s + 2) * 0.2f;
}
/* Voronoi : distances au germe le plus proche et au second, identifiant de la cellule */
static void vor(float x, float y, int s, float *f1, float *f2, unsigned int *id) {
    int ix = (int)floorf(x), iy = (int)floorf(y);
    float d1 = 9.0f, d2 = 9.0f;
    unsigned int best = 0;
    for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
        int cx = ix + i, cy = iy + j;
        unsigned int h = ih(cx, cy, s);
        float px = cx + 0.1f + 0.8f * (float)(h & 1023) / 1023.0f;
        float py = cy + 0.1f + 0.8f * (float)((h >> 10) & 1023) / 1023.0f;
        float d = (px - x) * (px - x) + (py - y) * (py - y);
        if (d < d1) { d2 = d1; d1 = d; best = h; } else if (d < d2) d2 = d;
    }
    *f1 = sqrtf(d1); *f2 = sqrtf(d2); *id = best;
}
static inline float idf(unsigned int id) { return (float)((id >> 20) & 1023) / 1023.0f; }

/* Modulation de couleur d'un matériau (texture procédurale) au point p, normale n ; fade atténue au loin.
   Identifiants : 1 herbe, 2 herbe feuillue, 3 terre, 4 boue, 5 roche, 6 grès, 7 calcaire, 8 ardoise, 9 basalte,
   10 sable, 11 pavés, 12 neige, 13 dallage, 14 sel, 20 brique, 21 bois, 22 planches, 23 tissu, 24 métal,
   25 gravier, 26 béton. */
static void texmod(int t, float px, float py, float pz, float nx, float ny, float nz, float fade, float *o) {
    o[0] = o[1] = o[2] = 1.0f;
    if (t <= 0) return;
    float ax = fabsf(nx), ay = fabsf(ny), az = fabsf(nz);
    float u, v;
    int vert;
    if (ay >= ax && ay >= az) { u = px; v = pz; vert = 0; }
    else if (ax >= az) { u = pz; v = py; vert = 1; }
    else { u = px; v = py; vert = 1; }
    float m = 1.0f, tr = 1.0f, tb = 1.0f, f1, f2;
    unsigned int id;
    switch (t) {
    case 1: case 2: {
        float n1 = fbm(u * 0.16f, v * 0.16f, 3);
        float n2 = vn(u * 2.7f, v * 2.7f, 4);
        float n3 = h01((int)floorf(u * 5.0f), (int)floorf(v * 5.0f), 5);
        m = 0.80f + 0.30f * n1 + 0.16f * (n2 - 0.5f) + 0.12f * (n3 - 0.5f);
        tr = 1.0f + (n1 - 0.5f) * 0.16f; tb = 1.0f - (n1 - 0.5f) * 0.12f;
        if (t == 2) { vor(u * 0.8f, v * 0.8f, 6, &f1, &f2, &id); if (f1 < 0.28f) { m *= 1.08f + 0.1f * idf(id); tr *= 1.05f; } }
        break; }
    case 3: case 4: {
        m = 0.82f + 0.26f * fbm(u * 0.22f, v * 0.22f, 7) + 0.1f * (h01((int)floorf(u * 6.0f), (int)floorf(v * 6.0f), 8) - 0.5f);
        if (t == 3) {
            vor(u * 1.5f, v * 1.5f, 9, &f1, &f2, &id);
            if (f1 < 0.2f) m *= 1.1f + 0.15f * idf(id); else if (f1 < 0.26f) m *= 0.86f;
        } else m = 0.9f + (m - 0.9f) * 0.5f;
        break; }
    case 5: case 6: case 7: case 9: {
        float sx = vert ? 0.14f : 0.3f, sy = vert ? 0.45f : 0.3f;
        m = 0.80f + 0.26f * fbm(u * sx, v * sy, 10);
        if (t == 6) m *= 0.92f + 0.1f * sinf(v * 1.9f + fbm(u * 0.2f, v * 0.2f, 11) * 4.0f);
        vor(u * (t == 9 ? 0.5f : 0.32f), v * (t == 9 ? 0.5f : 0.32f), 12, &f1, &f2, &id);
        if (f2 - f1 < 0.05f) m *= 0.68f; else m *= 0.92f + 0.14f * idf(id);
        break; }
    case 8: {
        vor(u * (vert ? 0.4f : 0.55f), v * (vert ? 0.9f : 0.55f), 13, &f1, &f2, &id);
        m = 0.84f + 0.24f * idf(id) + 0.08f * (vn(u * 1.5f, v * 1.5f, 14) - 0.5f);
        if (f2 - f1 < 0.06f) m *= 0.7f;
        break; }
    case 10: case 14:
        m = 0.95f + 0.06f * sinf(u * 1.3f + fbm(u * 0.15f, v * 0.15f, 15) * 5.0f) + 0.08f * (h01((int)floorf(u * 9.0f), (int)floorf(v * 9.0f), 16) - 0.5f);
        break;
    case 11: {
        vor(u * 0.8f, v * 0.8f, 17, &f1, &f2, &id);
        float e = f2 - f1;
        m = (0.80f + 0.30f * idf(id)) * (0.82f + 0.18f * clampf(e / 0.3f, 0.0f, 1.0f));
        if (e < 0.07f) m = 0.52f;
        m *= 0.94f + 0.12f * vn(u * 2.0f, v * 2.0f, 18);
        break; }
    case 12:
        m = 0.95f + 0.07f * fbm(u * 0.2f, v * 0.2f, 19);
        tb = 1.03f;
        break;
    case 13: {
        float a = u / 2.0f - floorf(u / 2.0f), b = v / 2.0f - floorf(v / 2.0f);
        m = 0.88f + 0.14f * h01((int)floorf(u / 2.0f), (int)floorf(v / 2.0f), 20);
        if (a < 0.04f || b < 0.04f) m = 0.62f;
        break; }
    case 20: {
        float row = floorf(v / 0.6f);
        float bu = u / 1.3f + (((int)row) & 1) * 0.5f;
        float a = bu - floorf(bu), b = v / 0.6f - row;
        m = 0.82f + 0.24f * h01((int)floorf(bu), (int)row, 21) + 0.06f * (vn(u * 3.0f, v * 3.0f, 22) - 0.5f);
        if (a < 0.06f || b < 0.1f) { m = 1.25f; tr = 0.92f; tb = 1.0f; }
        break; }
    case 21: case 22: {
        float g = vert ? u : v, w = vert ? v : u;
        if (t == 22) {
            float bi = floorf(g / 1.0f), fr = g - bi;
            m = 0.84f + 0.2f * h01((int)bi, 0, 23);
            if (fr < 0.07f) m = 0.55f;
            m *= 0.9f + 0.18f * fbm(w * 0.35f, g * 7.0f, 24);
        } else {
            m = 0.86f + 0.1f * sinf(g * 9.0f + fbm(w * 0.4f, g * 3.0f, 25) * 6.0f) + 0.06f * (vn(w * 0.3f, g * 8.0f, 26) - 0.5f);
        }
        break; }
    case 23:
        m = 0.93f + 0.07f * (float)((((int)floorf(u * 7.0f)) + ((int)floorf(v * 7.0f))) & 1) + 0.05f * (vn(u, v, 27) - 0.5f);
        break;
    case 24:
        m = 0.92f + 0.12f * vn(u * 0.4f, v * 4.0f, 28);
        break;
    case 25: {
        vor(u * 2.6f, v * 2.6f, 29, &f1, &f2, &id);
        m = 0.72f + 0.42f * idf(id);
        if (f2 - f1 < 0.08f) m = 0.5f;
        break; }
    case 26:
        m = 0.94f + 0.08f * (h01((int)floorf(u * 8.0f), (int)floorf(v * 8.0f), 30) - 0.5f) + 0.06f * fbm(u * 0.3f, v * 0.3f, 31);
        break;
    case 27: /* enduit : grain fin et légères taches */
        m = 0.95f + 0.07f * fbm(u * 0.45f, v * 0.45f, 32) + 0.05f * (h01((int)floorf(u * 10.0f), (int)floorf(v * 10.0f), 33) - 0.5f);
        break;
    case 28: { /* tuiles canal : rangées, tuiles arrondies */
        float row = floorf(v / 0.9f), fr = v / 0.9f - row;
        float tu = u / 0.75f + (((int)row) & 1) * 0.5f;
        float c = fabsf(sinf((tu - floorf(tu)) * 3.14159f));
        m = (0.74f + 0.3f * c) * (0.9f + 0.16f * h01((int)floorf(tu), (int)row, 34));
        if (fr < 0.08f) m *= 0.7f;
        break; }
    case 29: { /* bardeaux : rangées décalées */
        float row = floorf(v / 0.8f), fr = v / 0.8f - row;
        float tu = u / 1.1f + (((int)row) & 1) * 0.5f;
        m = 0.82f + 0.24f * h01((int)floorf(tu), (int)row, 35) + 0.06f * (vn(u * 3.0f, v * 0.5f, 36) - 0.5f);
        if (fr < 0.09f || tu - floorf(tu) < 0.05f) m *= 0.66f;
        break; }
    }
    o[0] = 1.0f + (m * tr - 1.0f) * fade;
    o[1] = 1.0f + (m - 1.0f) * fade;
    o[2] = 1.0f + (m * tb - 1.0f) * fade;
}

/* tri : n × 3 sommets × (x écran, y écran, 1/profondeur) ; lsp : n × 3 × (lx, ly, lz) en pixels de la carte
   d'ombres ; ca / cd : couleur ambiante / directe ; al : opacité ; mode 0 = opaque, 1 = mélange.
   wp : positions monde des sommets ; fn : normale de face ; mt : matériau (0 aucun, 255 = terrain : matériau et
   couleur lus dans la grille gtex / gcol de gn × gn cellules à partir de gx0, gz0, pas gres). */
void raster(int W, int H, int n, const float *tri, const float *lsp, const float *ca, const float *cd,
            const float *al, const float *smap, int SN, float sbias, float *zb, float *img, int mode,
            const float *wp, const float *fn, const int *mt,
            int gn, float gx0, float gz0, float gres, const unsigned char *gtex, const float *gcol,
            const unsigned char *gcliff, int nstrata, const int *stex, const float *scol) {
    for (int t = 0; t < n; t++) {
        const float *v = tri + t * 9;
        float x0 = v[0], y0 = v[1], w0 = v[2], x1 = v[3], y1 = v[4], w1 = v[5], x2 = v[6], y2 = v[7], w2 = v[8];
        float area = edge(x0, y0, x1, y1, x2, y2);
        if (fabsf(area) < 1e-9f) continue;
        int minx = (int)floorf(fminf(x0, fminf(x1, x2))), maxx = (int)ceilf(fmaxf(x0, fmaxf(x1, x2)));
        int miny = (int)floorf(fminf(y0, fminf(y1, y2))), maxy = (int)ceilf(fmaxf(y0, fmaxf(y1, y2)));
        if (minx < 0) minx = 0; if (miny < 0) miny = 0; if (maxx > W - 1) maxx = W - 1; if (maxy > H - 1) maxy = H - 1;
        if (minx > maxx || miny > maxy) continue;
        float inv = 1.0f / area;
        const float *L = lsp + t * 9;
        const float *A = ca + t * 9, *D = cd + t * 9;
        const float *P = wp + t * 9, *N = fn + t * 3;
        int tid0 = mt[t];
        float a = al[t];
        for (int y = miny; y <= maxy; y++) {
            float py = y + 0.5f;
            for (int x = minx; x <= maxx; x++) {
                float px = x + 0.5f;
                float b0 = edge(x1, y1, x2, y2, px, py) * inv;
                float b1 = edge(x2, y2, x0, y0, px, py) * inv;
                float b2 = 1.0f - b0 - b1;
                if (b0 < -1e-5f || b1 < -1e-5f || b2 < -1e-5f) continue;
                float iw = b0 * w0 + b1 * w1 + b2 * w2;
                int idx = y * W + x;
                if (iw <= zb[idx]) continue;
                float lit = 1.0f;
                float q0 = b0 * w0 / iw, q1 = b1 * w1 / iw, q2 = b2 * w2 / iw;
                if (SN > 0 && (D[0] + D[1] + D[2] + D[3] + D[4] + D[5] + D[6] + D[7] + D[8]) > 0.0f) {
                    float lx = q0 * L[0] + q1 * L[3] + q2 * L[6];
                    float ly = q0 * L[1] + q1 * L[4] + q2 * L[7];
                    float lz = q0 * L[2] + q1 * L[5] + q2 * L[8];
                    int sx = (int)lx, sy = (int)ly, hit = 0, cnt = 0;
                    for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
                        int ux = sx + dx, uy = sy + dy;
                        if (ux < 0 || uy < 0 || ux >= SN || uy >= SN) continue;
                        cnt++;
                        if (lz - sbias <= smap[uy * SN + ux]) hit++;
                    }
                    if (cnt > 0) lit = (float)hit / (float)cnt;
                }
                float r = q0 * (A[0] + D[0] * lit) + q1 * (A[3] + D[3] * lit) + q2 * (A[6] + D[6] * lit);
                float g = q0 * (A[1] + D[1] * lit) + q1 * (A[4] + D[4] * lit) + q2 * (A[7] + D[7] * lit);
                float b = q0 * (A[2] + D[2] * lit) + q1 * (A[5] + D[5] * lit) + q2 * (A[8] + D[8] * lit);
                if (tid0 > 0) {
                    float wx = q0 * P[0] + q1 * P[3] + q2 * P[6];
                    float wy = q0 * P[1] + q1 * P[4] + q2 * P[7];
                    float wz = q0 * P[2] + q1 * P[5] + q2 * P[8];
                    float dist = 1.0f / iw;
                    float fade = clampf(1.3f - dist / 260.0f, 0.3f, 1.0f);
                    int tid = tid0;
                    if (tid0 == 255) {
                        /* terrain : matériau de la cellule, frontière irrégulière (recherche décalée par un bruit) */
                        tid = 0;
                        if (gn > 0) {
                            float jx = wx + (vn(wx * 0.3f, wz * 0.3f, 41) - 0.5f) * 3.4f;
                            float jz = wz + (vn(wx * 0.3f + 9.1f, wz * 0.3f - 3.7f, 42) - 0.5f) * 3.4f;
                            int gx = (int)floorf((jx - gx0) / gres), gz = (int)floorf((jz - gz0) / gres);
                            if (gx < 0) gx = 0; if (gz < 0) gz = 0; if (gx > gn - 1) gx = gn - 1; if (gz > gn - 1) gz = gn - 1;
                            int cell = gz * gn + gx;
                            float var = 0.96f + 0.08f * h01(gx, gz, 43);
                            const float *cc = gcol + cell * 3;
                            tid = gtex[cell];
                            if (nstrata > 0 && gcliff[cell] && fabsf(N[1]) < 0.8f) {
                                /* paroi de falaise : couche selon l'altitude (bandes de 5 studs ondulées) */
                                float yy = wy + 2.5f * sinf(wy * 0.37f) + (vn(wx * 0.025f, wz * 0.025f, 51) - 0.5f) * 8.0f;
                                int band = (int)floorf(yy / 5.0f) % nstrata;
                                if (band < 0) band += nstrata;
                                tid = stex[band];
                                cc = scol + band * 3;
                            }
                            r *= cc[0] * var; g *= cc[1] * var; b *= cc[2] * var;
                        }
                    }
                    float mo[3];
                    texmod(tid, wx, wy, wz, N[0], N[1], N[2], fade, mo);
                    r *= mo[0]; g *= mo[1]; b *= mo[2];
                }
                float *o = img + idx * 3;
                if (mode == 0) {
                    zb[idx] = iw; o[0] = r; o[1] = g; o[2] = b;
                } else {
                    o[0] = o[0] * (1 - a) + r * a; o[1] = o[1] * (1 - a) + g * a; o[2] = o[2] * (1 - a) + b * a;
                }
            }
        }
    }
}
/* carte de profondeur orthographique : tri n × 3 × (x, y, z) ; garde le plus proche (z minimal) */
void depthmap(int N, int n, const float *tri, float *zb) {
    for (int t = 0; t < n; t++) {
        const float *v = tri + t * 9;
        float x0 = v[0], y0 = v[1], z0 = v[2], x1 = v[3], y1 = v[4], z1 = v[5], x2 = v[6], y2 = v[7], z2 = v[8];
        float area = edge(x0, y0, x1, y1, x2, y2);
        if (fabsf(area) < 1e-9f) continue;
        int minx = (int)floorf(fminf(x0, fminf(x1, x2))), maxx = (int)ceilf(fmaxf(x0, fmaxf(x1, x2)));
        int miny = (int)floorf(fminf(y0, fminf(y1, y2))), maxy = (int)ceilf(fmaxf(y0, fmaxf(y1, y2)));
        if (minx < 0) minx = 0; if (miny < 0) miny = 0; if (maxx > N - 1) maxx = N - 1; if (maxy > N - 1) maxy = N - 1;
        if (minx > maxx || miny > maxy) continue;
        float inv = 1.0f / area;
        for (int y = miny; y <= maxy; y++) for (int x = minx; x <= maxx; x++) {
            float px = x + 0.5f, py = y + 0.5f;
            float b0 = edge(x1, y1, x2, y2, px, py) * inv, b1 = edge(x2, y2, x0, y0, px, py) * inv, b2 = 1 - b0 - b1;
            if (b0 < -1e-5f || b1 < -1e-5f || b2 < -1e-5f) continue;
            float z = b0 * z0 + b1 * z1 + b2 * z2;
            if (z < zb[y * N + x]) zb[y * N + x] = z;
        }
    }
}
"""

_lib = None


def lib():
    global _lib
    if _lib is None:
        d = tempfile.mkdtemp(prefix='raster_')
        src, so = os.path.join(d, 'r.c'), os.path.join(d, 'r.so')
        open(src, 'w').write(C_SRC)
        subprocess.check_call(['gcc', '-O3', '-ffast-math', '-shared', '-fPIC', '-o', so, src])
        _lib = ctypes.CDLL(so)
        f = ctypes.POINTER(ctypes.c_float)
        i = ctypes.POINTER(ctypes.c_int)
        u8 = ctypes.POINTER(ctypes.c_ubyte)
        _lib.raster.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, f, f, f, f, f, f, ctypes.c_int, ctypes.c_float, f, f, ctypes.c_int,
                                f, f, i, ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_float, u8, f,
                                u8, ctypes.c_int, i, f]
        _lib.depthmap.argtypes = [ctypes.c_int, ctypes.c_int, f, f]
    return _lib


def fp(a):
    return a.ctypes.data_as(ctypes.POINTER(ctypes.c_float))


# ------------------------------------------------------------------ géométrie : triangles (n, 3, 3), normales (n, 3), couleurs (n, 3)

# Textures procédurales (identifiants du rastériseur) par nom de matériau Roblox ; 255 = terrain (grille).
TEX = {
    'Grass': 1, 'LeafyGrass': 2, 'Ground': 3, 'Mud': 4, 'Rock': 5, 'Sandstone': 6, 'Limestone': 7, 'Slate': 8,
    'Basalt': 9, 'Sand': 10, 'Cobblestone': 11, 'Snow': 12, 'Pavement': 13, 'Salt': 14, 'Brick': 20, 'Wood': 21,
    'WoodPlanks': 22, 'Fabric': 23, 'Metal': 24, 'DiamondPlate': 24, 'CorrodedMetal': 24, 'Pebble': 25, 'Concrete': 26,
    'Granite': 8, 'Marble': 26, 'Plaster': 27, 'ClayRoofTiles': 28, 'RoofShingles': 29,
}
TERRAIN_TEX = 255


class Mesh:
    def __init__(self):
        self.tris, self.nrm, self.col, self.alpha, self.emit, self.mat, self.cast = [], [], [], [], [], [], []
        self.terrain = None

    def add(self, tris, nrm, col, alpha=1.0, emit=0.0, mat=0, cast=True):
        """nrm / col : par triangle (n, 3) ou par sommet (n, 3, 3) pour un ombrage lissé ; mat : texture
        (par triangle ou commune) ; cast : porte une ombre."""
        n = len(tris)
        if n == 0:
            return
        self.tris.append(np.asarray(tris, dtype=np.float32).reshape(n, 3, 3))
        nv = np.asarray(nrm, dtype=np.float32)
        nv = nv.reshape(n, 3, 3) if nv.size == n * 9 else np.repeat(nv.reshape(n, 1, 3), 3, 1)
        self.nrm.append(nv)
        cv = np.asarray(col, dtype=np.float32)
        if cv.size == n * 9:
            cv = cv.reshape(n, 3, 3)
        else:
            cv = np.repeat(np.broadcast_to(cv, (n, 3)).reshape(n, 1, 3), 3, 1)
        self.col.append(np.ascontiguousarray(cv))
        self.alpha.append(np.broadcast_to(np.asarray(alpha, dtype=np.float32), (n,)).copy())
        self.emit.append(np.broadcast_to(np.asarray(emit, dtype=np.float32), (n,)).copy())
        self.mat.append(np.broadcast_to(np.asarray(mat, dtype=np.int32), (n,)).copy())
        self.cast.append(np.broadcast_to(np.asarray(cast, dtype=bool), (n,)).copy())

    def arrays(self):
        if not self.tris:
            z = np.zeros((0, 3, 3), np.float32)
            return z, z, z, np.zeros(0, np.float32), np.zeros(0, np.float32), np.zeros(0, np.int32), np.zeros(0, bool)
        return (np.concatenate(self.tris), np.concatenate(self.nrm), np.concatenate(self.col),
                np.concatenate(self.alpha), np.concatenate(self.emit), np.concatenate(self.mat), np.concatenate(self.cast))


CUBE = np.array([[x, y, z] for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)], dtype=np.float32)
# faces : (indices des coins, normale locale)
CUBE_FACES = [
    ((4, 6, 7, 5), (1, 0, 0)), ((0, 1, 3, 2), (-1, 0, 0)),
    ((2, 3, 7, 6), (0, 1, 0)), ((0, 4, 5, 1), (0, -1, 0)),
    ((1, 5, 7, 3), (0, 0, 1)), ((0, 2, 6, 4), (0, 0, -1)),
]


def quads_to_tris(q):
    """q : (..., 4, 3) -> (..., 2, 3, 3)"""
    a = q[..., [0, 1, 2], :]
    b = q[..., [0, 2, 3], :]
    return np.stack([a, b], axis=-3)


def _tex(T, n):
    return np.zeros(n, np.int32) if T is None else np.asarray(T, np.int32)


def add_blocks(mesh, P, S, R, C, A, E, T=None, cast=True):
    if len(P) == 0:
        return
    T = _tex(T, len(P))
    corners = P[:, None, :] + np.einsum('nij,nkj->nki', R, CUBE[None] * S[:, None, :])
    for idx, nl in CUBE_FACES:
        q = corners[:, list(idx), :]
        t = quads_to_tris(q).reshape(-1, 3, 3)
        n = np.einsum('nij,j->ni', R, np.array(nl, np.float32))
        mesh.add(t, np.repeat(n, 2, 0), np.repeat(C, 2, 0), np.repeat(A, 2), np.repeat(E, 2), np.repeat(T, 2), cast)


def add_wedges(mesh, P, S, R, C, A, E, T=None, cast=True):
    if len(P) == 0:
        return
    T = _tex(T, len(P))
    # coin bas avant gauche… : pente qui monte de l'avant (-Z) vers le haut de l'arrière (+Z)
    V = np.array([[-.5, -.5, -.5], [.5, -.5, -.5], [-.5, -.5, .5], [.5, -.5, .5], [-.5, .5, .5], [.5, .5, .5]], np.float32)
    W = P[:, None, :] + np.einsum('nij,nkj->nki', R, V[None] * S[:, None, :])
    faces = [((0, 2, 3, 1), (0, -1, 0)), ((2, 4, 5, 3), (0, 0, 1)), ((0, 1, 5, 4), (0, 0.7071, -0.7071))]
    for idx, nl in faces:
        t = quads_to_tris(W[:, list(idx), :]).reshape(-1, 3, 3)
        nn = np.array(nl, np.float32)
        if nl[1] > 0:
            # normale réelle de la pente selon les proportions
            d = np.stack([np.zeros(len(P)), S[:, 2], -S[:, 1]], 1)
            d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
            n = np.einsum('nij,nj->ni', R, d.astype(np.float32))
        else:
            n = np.einsum('nij,j->ni', R, nn)
        mesh.add(t, np.repeat(n, 2, 0), np.repeat(C, 2, 0), np.repeat(A, 2), np.repeat(E, 2), np.repeat(T, 2), cast)
    for idx, sx in (((0, 4, 2), -1), ((1, 3, 5), 1)):
        t = W[:, list(idx), :]
        n = np.einsum('nij,j->ni', R, np.array((sx, 0, 0), np.float32))
        mesh.add(t, n, C, A, E, T, cast)


def add_cylinders(mesh, P, S, R, C, A, E, seg=12, T=None):
    if len(P) == 0:
        return
    T = _tex(T, len(P))
    ang = np.linspace(0, 2 * math.pi, seg + 1)[:-1]
    cs, sn = np.cos(ang).astype(np.float32), np.sin(ang).astype(np.float32)
    rad = np.minimum(S[:, 1], S[:, 2]) / 2
    hl = S[:, 0] / 2
    for i in range(seg):
        j = (i + 1) % seg
        loc = np.zeros((len(P), 4, 3), np.float32)
        for k, (cc, ss, xs) in enumerate(((cs[i], sn[i], -1), (cs[i], sn[i], 1), (cs[j], sn[j], 1), (cs[j], sn[j], -1))):
            loc[:, k, 0] = xs * hl
            loc[:, k, 1] = cc * rad
            loc[:, k, 2] = ss * rad
        q = P[:, None, :] + np.einsum('nij,nkj->nki', R, loc)
        nl = np.zeros((len(P), 3), np.float32)
        cm, sm = (cs[i] + cs[j]) / 2, (sn[i] + sn[j]) / 2
        nl[:, 1], nl[:, 2] = cm, sm
        n = np.einsum('nij,nj->ni', R, nl)
        mesh.add(quads_to_tris(q).reshape(-1, 3, 3), np.repeat(n, 2, 0), np.repeat(C, 2, 0), np.repeat(A, 2), np.repeat(E, 2), np.repeat(T, 2))
        for xs in (-1, 1):
            loc = np.zeros((len(P), 3, 3), np.float32)
            loc[:, 0, 0] = xs * hl
            loc[:, 1, 0], loc[:, 1, 1], loc[:, 1, 2] = xs * hl, cs[i] * rad, sn[i] * rad
            loc[:, 2, 0], loc[:, 2, 1], loc[:, 2, 2] = xs * hl, cs[j] * rad, sn[j] * rad
            t = P[:, None, :] + np.einsum('nij,nkj->nki', R, loc)
            n = np.einsum('nij,j->ni', R, np.array((xs, 0, 0), np.float32))
            mesh.add(t, n, C, A, E, T)


def add_balls(mesh, P, S, C, A, E, rings=7, seg=12):
    if len(P) == 0:
        return
    rad = S.min(1) / 2
    th = np.linspace(0, math.pi, rings + 1)
    ph = np.linspace(0, 2 * math.pi, seg + 1)
    for i in range(rings):
        for j in range(seg):
            pts = []
            for (a, b) in ((th[i], ph[j]), (th[i + 1], ph[j]), (th[i + 1], ph[j + 1]), (th[i], ph[j + 1])):
                pts.append((math.sin(a) * math.cos(b), math.cos(a), math.sin(a) * math.sin(b)))
            loc = np.array(pts, np.float32)
            q = P[:, None, :] + loc[None] * rad[:, None, None]
            nm = loc.mean(0)
            nm /= np.linalg.norm(nm) + 1e-9
            mesh.add(quads_to_tris(q).reshape(-1, 3, 3), np.repeat(np.broadcast_to(nm, (len(P), 3)), 2, 0), np.repeat(C, 2, 0),
                     np.repeat(A, 2), np.repeat(E, 2))


# ------------------------------------------------------------------ pièces exportées

class Parts:
    def __init__(self, path):
        raw = json.load(open(path))
        n = len(raw)
        self.P = np.array([p['p'] for p in raw], np.float32)
        self.S = np.array([p['s'] for p in raw], np.float32)
        self.R = np.array([p['r'] for p in raw], np.float32).reshape(n, 3, 3)
        self.C = np.array([[int(p['c'][i:i + 2], 16) / 255 for i in (0, 2, 4)] for p in raw], np.float32)
        self.T = np.array([p['t'] for p in raw], np.float32)
        self.K = np.array([p['k'] for p in raw])
        self.M = np.array([p['m'] for p in raw])
        self.TX = np.array([TEX.get(m, 0) for m in self.M], np.int32)

    def add_to(self, mesh, center, radius, ymin=-1e9, ymax=1e9, skip=None):
        d = np.sqrt((self.P[:, 0] - center[0]) ** 2 + (self.P[:, 2] - center[2]) ** 2)
        sel = (d < radius + np.abs(self.S).max(1)) & (self.P[:, 1] > ymin) & (self.P[:, 1] < ymax) & (self.T < 0.97)
        if skip is not None:
            sel &= ~skip(self)
        idx = np.nonzero(sel)[0]
        P, S, R, C, T, K, M = self.P[idx], self.S[idx], self.R[idx], self.C[idx], self.T[idx], self.K[idx], self.M[idx]
        TX = self.TX[idx]
        A = 1 - T
        E = np.where(M == 'Neon', 1.0, 0.0).astype(np.float32)
        A = np.where(M == 'ForceField', np.minimum(A, 0.35), A).astype(np.float32)
        A = np.where(M == 'Glass', np.minimum(A, 0.5), A).astype(np.float32)
        for kind, fn in (('Block', add_blocks), ('Wedge', add_wedges), ('Cylinder', add_cylinders)):
            m = K == kind
            fn(mesh, P[m], S[m], R[m], C[m], A[m], E[m], T=TX[m])
        m = K == 'Ball'
        add_balls(mesh, P[m], S[m], C[m], A[m], E[m])
        # autres formes (coins, etc.) : boîtes
        m = ~np.isin(K, ['Block', 'Wedge', 'Cylinder', 'Ball'])
        add_blocks(mesh, P[m], S[m], R[m], C[m], A[m], E[m], T=TX[m])
        return len(idx)

    def cover(self, center, radius, cell=0.5):
        """Grille vue de dessus (pas `cell`) de la hauteur du haut des pièces qui couvrent le sol autour de
        `center` : le client ne pose pas de détails là où son rayon vertical touche une pièce."""
        n = int(2 * radius / cell) + 1
        top = np.full((n, n), -1e9, np.float32)
        x0, z0 = center[0] - radius, center[2] - radius
        d = np.sqrt((self.P[:, 0] - center[0]) ** 2 + (self.P[:, 2] - center[2]) ** 2)
        sel = (d < radius + np.abs(self.S).max(1)) & (self.T < 0.5)
        for i in np.nonzero(sel)[0]:
            P, S, R = self.P[i], self.S[i], self.R[i]
            ext = np.abs(R) @ (S / 2)
            ia, ib = int((P[0] - ext[0] - x0) / cell), int((P[0] + ext[0] - x0) / cell) + 1
            ja, jb = int((P[2] - ext[2] - z0) / cell), int((P[2] + ext[2] - z0) / cell) + 1
            ia, ja, ib, jb = max(ia, 0), max(ja, 0), min(ib, n), min(jb, n)
            if ia >= ib or ja >= jb:
                continue
            gx = x0 + (np.arange(ia, ib) + 0.5) * cell
            gz = z0 + (np.arange(ja, jb) + 0.5) * cell
            X, Z = np.meshgrid(gx, gz)
            # point à la hauteur du centre de la pièce, ramené dans son repère
            D = np.stack([X - P[0], np.zeros_like(X), Z - P[2]], -1) @ R
            inside = (np.abs(D[..., 0]) <= S[0] / 2) & (np.abs(D[..., 2]) <= S[2] / 2)
            if self.K[i] == 'Ball':
                inside = (X - P[0]) ** 2 + (Z - P[2]) ** 2 <= (S.min() / 2) ** 2
            if inside.any():
                sub = top[ja:jb, ia:ib]
                np.maximum(sub, np.where(inside, P[1] + ext[1], -1e9), out=sub)
        return top, x0, z0, cell


# ------------------------------------------------------------------ terrain

class Terrain:
    def __init__(self, path):
        raw = open(path, 'rb').read()
        n, res, x0, z0 = struct.unpack('<iiff', raw[:16])
        (ln,) = struct.unpack('<i', raw[16:20])
        names = raw[20:20 + ln].decode().split(',')
        o = 20 + ln
        (ls,) = struct.unpack('<i', raw[o:o + 4])
        strata = raw[o + 4:o + 4 + ls].decode().split(',') if ls else []
        o += 4 + ls
        rec = np.frombuffer(raw[o:], dtype=np.dtype([('h', '<f4'), ('w', '<f4'), ('c', 'u1', 4)]))
        rec = rec.reshape(n, n)  # [iz][ix]
        self.n, self.res, self.x0, self.z0 = n, res, x0, z0
        self.h = rec['h'].astype(np.float32)
        self.w = rec['w'].astype(np.float32)
        self.c = rec['c'][..., :3].astype(np.float32) / 255
        # texture de chaque cellule (identifiant du rastériseur)
        lut = np.zeros(256, np.uint8)
        for i, name in enumerate(names):
            lut[i + 1] = TEX.get(name, 0)
        mid = rec['c'][..., 3] & 127
        self.tex = np.ascontiguousarray(lut[mid])
        self.col = np.ascontiguousarray(self.c.reshape(-1, 3))
        # parois de falaise et couches (texture, couleur moyenne des cellules de ce matériau)
        self.cliff = np.ascontiguousarray(((rec['c'][..., 3] >> 7) & 1).astype(np.uint8))
        stex, scol = [], []
        for name in strata:
            k = names.index(name) + 1 if name in names else -1
            cells = self.c[mid == k]
            stex.append(TEX.get(name, 0))
            scol.append(cells.mean(0) if len(cells) else np.array([0.5, 0.5, 0.5]))
        self.stex = np.ascontiguousarray(np.array(stex, np.int32))
        self.scol = np.ascontiguousarray(np.array(scol, np.float32).reshape(-1))

    def xs(self, ix):
        return self.x0 + (ix + 0.5) * self.res

    def zs(self, iz):
        return self.z0 + (iz + 0.5) * self.res

    def height(self, x, z):
        fx = (x - self.x0) / self.res - 0.5
        fz = (z - self.z0) / self.res - 0.5
        ix, iz = int(math.floor(fx)), int(math.floor(fz))
        if ix < 0 or iz < 0 or ix >= self.n - 1 or iz >= self.n - 1:
            return None
        tx, tz = fx - ix, fz - iz
        h = self.h
        a = h[iz, ix] + (h[iz, ix + 1] - h[iz, ix]) * tx
        b = h[iz + 1, ix] + (h[iz + 1, ix + 1] - h[iz + 1, ix]) * tx
        return float(a + (b - a) * tz)

    def add_to(self, mesh, center, radius, step=1, seed=3):
        cx, cz = center[0], center[2]
        i0 = max(0, int((cx - radius - self.x0) / self.res))
        i1 = min(self.n - 1, int((cx + radius - self.x0) / self.res) + 1)
        j0 = max(0, int((cz - radius - self.z0) / self.res))
        j1 = min(self.n - 1, int((cz + radius - self.z0) / self.res) + 1)
        ix = np.arange(i0, i1, step)
        iz = np.arange(j0, j1, step)
        if len(ix) < 2 or len(iz) < 2:
            return
        X = self.xs(ix)[None, :].repeat(len(iz), 0)
        Z = self.zs(iz)[:, None].repeat(len(ix), 1)
        H = self.h[np.ix_(iz, ix)]
        Wl = self.w[np.ix_(iz, ix)]
        # couleur et texture lues par pixel dans la grille (frontières de matériaux nettes et irrégulières)
        Cc = np.ones(H.shape + (3,), np.float32)
        mesh.terrain = self
        V = np.stack([X, H, Z], -1)
        # normales lissées aux sommets (gradient du champ de hauteur)
        gz, gx = np.gradient(H, self.res * step)
        Nv = np.stack([-gx, np.ones_like(H), -gz], -1)
        Nv /= np.linalg.norm(Nv, axis=-1, keepdims=True)

        def corners(A):
            return np.stack([A[:-1, :-1], A[:-1, 1:], A[1:, 1:], A[1:, :-1]], -2).reshape(-1, 4, A.shape[-1])
        q, qn, qc = corners(V), corners(Nv), corners(Cc)
        for order in ([0, 3, 2], [0, 2, 1]):
            mesh.add(q[:, order, :], qn[:, order, :], qc[:, order, :], mat=TERRAIN_TEX)
        # eau : surfaces au niveau de l'eau là où le fond est plus bas
        wq = np.stack([Wl[:-1, :-1], Wl[:-1, 1:], Wl[1:, 1:], Wl[1:, :-1]], -1).reshape(-1, 4)
        hq = np.stack([H[:-1, :-1], H[:-1, 1:], H[1:, 1:], H[1:, :-1]], -1).reshape(-1, 4)
        lvl = wq.max(1)
        wet = (lvl > -9000) & (hq.min(1) < lvl)
        if wet.any():
            qw = corners(V)[wet].copy()
            qw[:, :, 1] = lvl[wet][:, None] - 0.3
            depth = np.clip((lvl[wet] - hq[wet].mean(1)) / 14, 0, 1)
            shallow = np.array([0.36, 0.66, 0.70], np.float32)
            deep = np.array([0.12, 0.34, 0.50], np.float32)
            wc = shallow[None] * (1 - depth[:, None]) + deep[None] * depth[:, None]
            for t in (qw[:, [0, 3, 2], :], qw[:, [0, 2, 1], :]):
                mesh.add(t, np.tile([0, 1, 0], (len(t), 1)), wc, 0.78)


# ------------------------------------------------------------------ détails au sol

class Details:
    """Détails au sol exportés par tools/preview/detail_dump.luau (module du jeu Shared/Logic/GroundDetail)."""

    def __init__(self, path):
        raw = open(path, 'rb').read()
        ni, npc = struct.unpack('<ii', raw[:8])
        (ln,) = struct.unpack('<i', raw[8:12])
        names = raw[12:12 + ln].decode().split(',') if ln else []
        o = 12 + ln
        self.items = np.frombuffer(raw[o:o + ni * 12], '<f4').reshape(ni, 3).astype(np.float32)
        o += ni * 12
        rec = np.frombuffer(raw[o:], dtype=np.dtype([('item', '<u4'), ('shape', 'u1'), ('mat', 'u1'), ('c', 'u1', 3),
                                                     ('s', '<f4', 3), ('cf', '<f4', 12)]), count=npc)
        self.item = rec['item'].astype(np.int64)
        self.shape = rec['shape']
        lut = np.zeros(256, np.int32)
        for i, name in enumerate(names):
            lut[i + 1] = TEX.get(name, 0)
        self.tex = lut[rec['mat']]
        self.C = rec['c'].astype(np.float32) / 255
        self.S = rec['s'].astype(np.float32)
        self.P = rec['cf'][:, :3].astype(np.float32)
        self.R = rec['cf'][:, 3:].reshape(-1, 3, 3).astype(np.float32)

    def add_to(self, mesh, parts, center, radius, eye=None):
        """Pose les détails à moins de `radius` de `center`, sauf là où une pièce couvre le sol (et tout près de
        la caméra, où le terrain coupé par le plan proche les laisserait flotter)."""
        it = self.items
        near = np.sqrt((it[:, 0] - center[0]) ** 2 + (it[:, 2] - center[2]) ** 2) < radius
        if eye is not None:
            near &= np.sqrt(((it - np.asarray(eye, np.float32)) ** 2).sum(1)) > 30
        if parts is not None and near.any():
            top, x0, z0, cell = parts.cover(center, radius)
            n = top.shape[0]
            ix = np.clip(((it[:, 0] - x0) / cell).astype(int), 0, n - 1)
            iz = np.clip(((it[:, 2] - z0) / cell).astype(int), 0, n - 1)
            near &= ~(top[iz, ix] > it[:, 1] - 0.3)
        keep = near[self.item]
        A = np.ones(keep.sum(), np.float32)
        E = np.zeros(keep.sum(), np.float32)
        P, S, R, C, T, K = self.P[keep], self.S[keep], self.R[keep], self.C[keep], self.tex[keep], self.shape[keep]
        add_blocks(mesh, P[K == 0], S[K == 0], R[K == 0], C[K == 0], A[K == 0], E[K == 0], T[K == 0], cast=False)
        add_wedges(mesh, P[K == 1], S[K == 1], R[K == 1], C[K == 1], A[K == 1], E[K == 1], T[K == 1], cast=False)
        return int(near.sum())


# ------------------------------------------------------------------ personnages voxel

_models = {}


def model_quads(name, tint=None):
    key = (name, tint)
    if key in _models:
        return _models[key]
    from voxelize import build
    from render import collect_faces
    from models import heroes_w1, heroes_w2, enemies
    fns = {}
    for group in (heroes_w1.MODELS, heroes_w2.MODELS, enemies.MODELS):
        for fn in group:
            fns[getattr(fn, '__name__', '')] = fn
    found = None
    for fn in heroes_w1.MODELS + heroes_w2.MODELS + enemies.MODELS:
        m = fn()
        if m.name == name:
            found = m
            break
    if found is None:
        raise KeyError(name)
    res = build(found)
    quads = collect_faces(res, tint=tint)
    Q = np.array([q for q, _, _ in quads], np.float32)
    N = np.array([n for _, n, _ in quads], np.float32)
    C = np.array([c for _, _, c in quads], np.float32) / 255.0
    _models[key] = (Q, N, C)
    return _models[key]


def add_actor(mesh, name, pos, yaw_deg, scale=1.0, tint=None, lift=0.0):
    Q, N, C = model_quads(name, tint)
    a = math.radians(yaw_deg)
    R = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]], np.float32)
    q = (Q * scale) @ R.T + np.array([pos[0], pos[1] + lift, pos[2]], np.float32)
    n = N @ R.T
    mesh.add(quads_to_tris(q).reshape(-1, 3, 3), np.repeat(n, 2, 0), np.repeat(C, 2, 0))


# ------------------------------------------------------------------ rendu

def normalize(v):
    v = np.asarray(v, np.float64)
    return v / (np.linalg.norm(v) + 1e-12)


def render(mesh, eye, target, size=(1600, 900), fov=50, sun=(-0.45, 0.75, -0.35), sun_col=(1.0, 0.93, 0.8),
           sky_top=(0.42, 0.62, 0.86), sky_bot=(0.86, 0.84, 0.78), amb=(0.42, 0.45, 0.52), ground_amb=(0.30, 0.27, 0.22),
           fog=(0.80, 0.82, 0.84), fog_start=180, fog_end=1400, fog_max=0.75, ss=2, shadow_extent=420, exposure=1.0):
    tris, nrm, col, alpha, emit, mat, cast = mesh.arrays()
    W, H = size[0] * ss, size[1] * ss
    eye = np.array(eye, np.float64)
    f = normalize(np.array(target) - eye)
    r = normalize(np.cross(f, [0, 1, 0]))
    u = np.cross(r, f)
    fpx = (W / 2) / math.tan(math.radians(fov) / 2)
    # éclairage par triangle
    s = normalize(sun).astype(np.float32)
    ndl = np.clip(nrm @ s, 0, 1)[..., None]
    hemi = np.clip(nrm[..., 1] * 0.5 + 0.5, 0, 1)[..., None]
    ambc = np.array(amb, np.float32) * hemi + np.array(ground_amb, np.float32) * (1 - hemi)
    ca = col * ambc
    cd = col * np.array(sun_col, np.float32) * ndl * 1.05
    em = (emit > 0.5)[:, None, None]
    ca = np.where(em, np.clip(col * 1.35 + 0.08, 0, 1.6), ca)
    cd = np.where(em, 0, cd)
    fnrm = nrm.mean(1)
    # projection
    d = tris.astype(np.float64) - eye
    xc = d @ r
    yc = d @ u
    zc = d @ f
    near = 0.6
    keep = (zc > near).all(1)
    # faces arrière (sauf transparents et eau, vus des deux côtés)
    cen = tris.mean(1) - eye
    front = (fnrm * -cen).sum(1) > 0
    keep &= front | (alpha < 0.99)
    # hors champ
    sx = W / 2 + xc / np.maximum(zc, near) * fpx
    sy = H / 2 - yc / np.maximum(zc, near) * fpx
    inside = ~(((sx < -50).all(1)) | ((sx > W + 50).all(1)) | ((sy < -50).all(1)) | ((sy > H + 50).all(1)))
    keep &= inside
    idx = np.nonzero(keep)[0]
    scr = np.stack([sx[idx], sy[idx], 1.0 / zc[idx]], -1).astype(np.float32)
    # carte d'ombres (orthographique, centrée sur la cible)
    SN = 4096
    lf = -s.astype(np.float64)
    lr = normalize(np.cross(lf, [0, 0, 1]))
    lu = np.cross(lr, lf)
    c0 = np.array(target, np.float64)
    E = shadow_extent
    dl = tris.astype(np.float64) - c0
    lx = (dl @ lr + E) / (2 * E) * SN
    ly = (dl @ lu + E) / (2 * E) * SN
    lz = dl @ lf
    opaque = (alpha >= 0.99) & cast
    sm = np.full(SN * SN, 1e9, np.float32)
    L = lib()
    stri = np.ascontiguousarray(np.stack([lx[opaque], ly[opaque], lz[opaque]], -1).astype(np.float32))
    L.depthmap(SN, len(stri), fp(stri), fp(sm))
    lsp = np.ascontiguousarray(np.stack([lx[idx], ly[idx], lz[idx]], -1).astype(np.float32))
    zb = np.zeros(W * H, np.float32)
    img = np.zeros(W * H * 3, np.float32)
    ca_k, cd_k, al_k = (np.ascontiguousarray(a[idx].astype(np.float32)) for a in (ca, cd, alpha))
    wp_k = np.ascontiguousarray(tris[idx].astype(np.float32))
    fn_k = np.ascontiguousarray(fnrm[idx].astype(np.float32))
    mt_k = np.ascontiguousarray(np.where(emit[idx] > 0.5, 0, mat[idx]).astype(np.int32))
    ter = mesh.terrain
    if ter is not None:
        gn, gx0, gz0, gres = ter.n, ter.x0, ter.z0, ter.res
        gtex, gcol, gcliff, stex, scol = ter.tex, ter.col, ter.cliff, ter.stex, ter.scol
    else:
        gn, gx0, gz0, gres = 0, 0.0, 0.0, 1.0
        gtex, gcol = np.zeros(1, np.uint8), np.zeros(3, np.float32)
        gcliff, stex, scol = np.zeros(1, np.uint8), np.zeros(1, np.int32), np.zeros(3, np.float32)
    u8p = gtex.ctypes.data_as(ctypes.POINTER(ctypes.c_ubyte))
    cliffp = gcliff.ctypes.data_as(ctypes.POINTER(ctypes.c_ubyte))
    nstrata = len(stex) if ter is not None else 0
    op = al_k >= 0.99
    bias = 1.2 * SN / (2 * E)
    for mode, m in ((0, op), (1, ~op)):
        ii = np.nonzero(m)[0]
        if mode == 1:
            # transparents : du plus loin au plus proche
            ii = ii[np.argsort(scr[ii, :, 2].mean(1))]
        if len(ii) == 0:
            continue
        mt_i = np.ascontiguousarray(mt_k[ii])
        L.raster(W, H, len(ii), fp(np.ascontiguousarray(scr[ii])), fp(np.ascontiguousarray(lsp[ii])),
                 fp(np.ascontiguousarray(ca_k[ii])), fp(np.ascontiguousarray(cd_k[ii])), fp(np.ascontiguousarray(al_k[ii])),
                 fp(sm), SN, ctypes.c_float(bias), fp(zb), fp(img), mode,
                 fp(np.ascontiguousarray(wp_k[ii])), fp(np.ascontiguousarray(fn_k[ii])), mt_i.ctypes.data_as(ctypes.POINTER(ctypes.c_int)),
                 gn, ctypes.c_float(gx0), ctypes.c_float(gz0), ctypes.c_float(gres), u8p, fp(gcol),
                 cliffp, nstrata, stex.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), fp(scol))
    img = img.reshape(H, W, 3)
    zb = zb.reshape(H, W)
    # ciel
    yy = np.linspace(0, 1, H)[:, None, None]
    sky = np.array(sky_top)[None, None] * (1 - yy) + np.array(sky_bot)[None, None] * yy
    sky = np.broadcast_to(sky, (H, W, 3))
    empty = zb <= 0
    # brume
    dist = np.where(empty, 1e9, 1.0 / np.maximum(zb, 1e-9))
    fogf = np.clip((dist - fog_start) / (fog_end - fog_start), 0, 1) ** 1.3 * fog_max
    out = np.where(empty[..., None], sky, img * (1 - fogf[..., None]) + np.array(fog)[None, None] * fogf[..., None])
    out = np.clip(out * exposure, 0, 1) ** (1 / 1.08)
    im = Image.fromarray((out * 255).astype(np.uint8))
    # léger éclat autour des néons
    glow = Image.fromarray((np.clip((img.reshape(H, W, 3) - 1.0), 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6 * ss))
    im = Image.fromarray(np.clip(np.asarray(im, np.float32) + np.asarray(glow, np.float32) * 0.9, 0, 255).astype(np.uint8))
    if ss > 1:
        im = im.resize(size, Image.LANCZOS)
    return im, len(idx)


def look(target, yaw, pitch, dist):
    """Position de caméra autour d'une cible (lacet / tangage en degrés)."""
    a, p = math.radians(yaw), math.radians(pitch)
    return (target[0] + math.sin(a) * math.cos(p) * dist, target[1] + math.sin(p) * dist, target[2] + math.cos(a) * math.cos(p) * dist)
