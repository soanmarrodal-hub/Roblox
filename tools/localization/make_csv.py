"""Génère src/LocalizationService/Interface.csv (LocalizationTable Roblox, source française).

Rojo convertit ce fichier en LocalizationTable : Roblox traduit alors automatiquement les textes
d'interface (AutoLocalize) pour les joueurs anglophones, hispanophones et lusophones.
Usage : python3 tools/localization/make_csv.py
"""
import csv
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from strings import S  # noqa: E402

out = os.path.join(os.path.dirname(__file__), "..", "..", "src", "LocalizationService", "Interface.csv")
os.makedirs(os.path.dirname(out), exist_ok=True)
# entrées du module Locale (fr/en/es/pt déjà traduites) : mêmes textes, traduits aussi quand ils
# s'affichent en français (titres de menus construits avant l'arrivée du profil, etc.)
import re
locale_src = open(os.path.join(os.path.dirname(__file__), "..", "..", "src", "ReplicatedStorage", "Shared", "Locale.luau"), encoding="utf-8").read()
extra = []
for m in re.finditer(r'fr = "([^"]*)", en = "([^"]*)", es = "([^"]*)", pt = "([^"]*)"', locale_src):
    extra.append(m.groups())

seen = set()
with open(out, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["Key", "Source", "Context", "Example", "en", "es", "pt"])
    for fr, en, es, pt in list(S) + extra:
        if fr in seen:
            continue
        seen.add(fr)
        w.writerow(["", fr, "", "", en, es, pt])
print(f"{len(seen)} entrées -> {os.path.normpath(out)}")
