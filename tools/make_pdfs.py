#!/usr/bin/env python3
"""Génère les deux PDF de présentation de mHUB (FR puis EN dans chaque PDF) : HTML → PDF par Brave en mode sans fenêtre."""
import os, subprocess, sys, html
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
D = os.path.join(R, "docs")
BRAVE = "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"

CSS = """
@page{size:297mm 210mm;margin:0}
*{box-sizing:border-box;margin:0;padding:0}
body{font:15px/1.5 -apple-system,"SF Pro Text",system-ui,sans-serif;color:#1c1c22;-webkit-font-smoothing:antialiased}
.page{width:297mm;height:210mm;padding:16mm 18mm;page-break-after:always;position:relative;overflow:hidden;background:#f1f1f5;display:flex;flex-direction:column}
.page.dark{background:#131316;color:#f5f5f7}
.lang{position:absolute;top:10mm;right:14mm;font-size:11px;font-weight:700;letter-spacing:.08em;color:#6b6b78;background:#e8e8ef;padding:3px 10px;border-radius:99px}
.dark .lang{background:#2c2c31;color:#98989f}
h1{font-size:54px;line-height:1.05;font-weight:800;letter-spacing:-.02em}
h2{font-size:30px;font-weight:750;letter-spacing:-.01em;margin-bottom:6mm}
.m{color:#f5b800}
.sub{font-size:20px;color:#6b6b78;margin-top:6mm;max-width:190mm}
.dark .sub{color:#98989f}
.foot{margin-top:auto;font-size:11px;color:#6b6b78;display:flex;justify-content:space-between}
.cover{justify-content:center;align-items:flex-start;gap:0}
.cover img{width:62mm;height:62mm;margin-bottom:10mm}
.cards{display:grid;grid-template-columns:repeat(2,1fr);gap:7mm}
.card{background:#fff;border-radius:20px;padding:6mm 7mm}
.dark .card{background:#232327}
.card b{display:block;font-size:17px;margin-bottom:2mm}
.card span{color:#6b6b78;font-size:14px}
.dark .card span{color:#98989f}
.steps{display:grid;grid-template-columns:repeat(4,1fr);gap:5mm}
.step{background:#fff;border-radius:20px;padding:6mm}
.step i{font-style:normal;display:inline-grid;place-items:center;width:9mm;height:9mm;border-radius:50%;background:#6a5af0;color:#fff;font-weight:700;margin-bottom:3mm}
.step b{display:block;font-size:16px;margin-bottom:2mm}
.step span{font-size:13px;color:#6b6b78}
.facts{display:grid;grid-template-columns:1fr 1fr;gap:7mm}
ul{list-style:none}li{padding:2.2mm 0;border-bottom:1px solid #00000014;font-size:14.5px}
.dark li{border-color:#ffffff1a}
li b{font-weight:650}
.shot{position:relative;border-radius:14px;overflow:hidden;box-shadow:0 14px 40px #0004;line-height:0}
.shot img{width:100%;display:block}
.pin{position:absolute;width:7mm;height:7mm;border-radius:50%;background:#f5b800;color:#1c1c22;font-weight:800;font-size:13px;display:grid;place-items:center;transform:translate(-50%,-50%);box-shadow:0 2px 8px #0006;line-height:1}
.row{display:flex;gap:9mm;align-items:flex-start;flex:1}
.legend{flex:1;font-size:14px}
.legend li{display:flex;gap:3mm;align-items:flex-start}
.legend em{flex:none;font-style:normal;width:6.5mm;height:6.5mm;border-radius:50%;background:#f5b800;color:#1c1c22;font-weight:800;font-size:12px;display:grid;place-items:center;margin-top:.5mm}
.chips{display:flex;flex-wrap:wrap;gap:3mm;margin-top:5mm}
.chip{font-size:12.5px;font-weight:600;padding:1.4mm 4mm;border-radius:99px;background:#e8e8ef;color:#1c1c22}
.chip.ok{background:#2fb36a33;color:#1f8a4e}.chip.warn{background:#e08a0033;color:#a8650a}
"""

def pins(items, w=1120, h=720):
    return "".join(f'<div class="pin" style="left:{x/w*100:.1f}%;top:{y/h*100:.1f}%">{i}</div>' for i, (x, y) in enumerate(items, 1))

def legend(lines):
    return "<ul class='legend'>" + "".join(f"<li><em>{i}</em><div>{t}</div></li>" for i, t in enumerate(lines, 1)) + "</ul>"

def page(lang, body, dark=False, n=0, total=0, name=""):
    return (f'<section class="page{" dark" if dark else ""}"><div class="lang">{lang.upper()}</div>{body}'
            f'<div class="foot"><span>mHUB · DESKTOP MAC TOOLKIT</span><span>{n}/{total}</span></div></section>')

BRAND = '<span class="m">m</span>HUB'

# ---------------------------------------------------------------- Présentation de l'application
APP = {
 "fr": dict(
  tag="Le hub du Mac Desktop Toolkit", sub="Une seule icône pour installer, mettre à jour et lancer toutes les applis du kit.",
  why="Pourquoi un hub ?",
  cards=[("Une seule porte d'entrée", "Une icône en couleur dans la barre des menus ouvre toutes les applis installées, chacune avec son sous-menu (Ouvrir, Réglages…). Les applis compatibles pourront masquer leur propre icône."),
         ("Tout le kit au même endroit", "31 applis présentées en une phrase, rangées par catégories, avec recherche. Installation en un clic, sans passer par GitHub."),
         ("Mises à jour centralisées", "Une vérification par jour, installation automatique en option. Jamais pendant qu'une appli est ouverte : elle attend votre feu vert."),
         ("Bien intégré au système", "Applis installées dans « Applications Personnelles », signature Developer ID vérifiée, ouverture à la session en option, 4 langues (FR, EN, ES, IT).")],
  how="Comment ça marche", steps=[
   ("Un catalogue", "31 applis du kit avec description, catégorie et dépôt, embarqué dans mHUB et mis à jour avec lui."),
   ("Installer", "Télécharge la dernière release GitHub publique, vérifie la signature (même équipe, bon identifiant), indique si elle est notarisée, installe."),
   ("Mettre à jour", "Compare les versions chaque jour. Si l'appli est ouverte : « Quitter et mettre à jour », puis relance discrète."),
   ("Lancer et régler", "Ouvrir, ouvrir les réglages quand l'appli le déclare, couper ou remettre son icône de barre des menus.")],
  brief="En bref", facts=[
   ("Version", "1.0.0 · licence MIT"), ("Système", "macOS 15 ou plus · Apple Silicon"), ("Langues", "français, anglais, espagnol, italien (automatique)"),
   ("Présence", "Barre des menus (défaut), Dock, ou les deux"), ("Design", "Flat Round, arrondis 20, clair et sombre")],
  limits="Ce que mHUB ne fait pas", lim=[
   "Il n'héberge pas les interfaces des applis : chacune reste une appli à part entière.",
   "Pas de panneau de réglages unifié : « Réglages » ouvre ceux de l'appli.",
   "10 applis ne sont pas encore publiques : elles s'affichent « Pas encore publique » (ou « Installée » si déjà présentes).",
   "Les « Réglages » et la bascule d'icône dépendent d'un contrat léger que chaque appli adopte à son rythme."]),
 "en": dict(
  tag="The hub of the Mac Desktop Toolkit", sub="One icon to install, update and launch every app in the toolkit.",
  why="Why a hub?",
  cards=[("One front door", "A coloured menu bar icon opens every installed app, each with its own submenu (Open, Settings…). Compatible apps will be able to hide their own icon."),
         ("The whole toolkit in one place", "31 apps, each described in one sentence, sorted by category, with search. One-click install, no trip to GitHub."),
         ("Centralised updates", "One check per day, optional automatic install. Never while an app is open: it waits for your go-ahead."),
         ("Well integrated with macOS", "Apps are installed in “Applications Personnelles”, Developer ID signature verified, optional open at login, 4 languages (FR, EN, ES, IT).")],
  how="How it works", steps=[
   ("A catalog", "31 toolkit apps with description, category and repository, bundled in mHUB and updated with it."),
   ("Install", "Downloads the latest public GitHub release, verifies the signature (same team, right identifier), reports whether it is notarized, installs."),
   ("Update", "Compares versions every day. If the app is open: “Quit and update”, then a quiet relaunch."),
   ("Launch and configure", "Open, open the app's settings when it declares them, switch its menu bar icon on or off.")],
  brief="At a glance", facts=[
   ("Version", "1.0.0 · MIT license"), ("System", "macOS 15 or later · Apple Silicon"), ("Languages", "French, English, Spanish, Italian (automatic)"),
   ("Presence", "Menu bar (default), Dock, or both"), ("Design", "Flat Round, 20 corner radius, light and dark")],
  limits="What mHUB does not do", lim=[
   "It does not host the apps' interfaces: each one stays a full app of its own.",
   "No unified settings panel: “Settings” opens the app's own.",
   "10 apps are not public yet: they show “Not public yet” (or “Installed” if already present).",
   "“Settings” and the icon switch rely on a light contract that each app adopts at its own pace."]),
}

def app_pages(lang):
    t = APP[lang]; out = []; total = 4
    out.append(page(lang, f'<div class="cover" style="display:flex;flex-direction:column;justify-content:center;flex:1"><img src="screens/icon.png"><h1>{BRAND}</h1><p class="sub">{t["tag"]}</p><p class="sub" style="margin-top:3mm;font-size:17px">{t["sub"]}</p></div>', n=1, total=total))
    cards = "".join(f'<div class="card"><b>{a}</b><span>{b}</span></div>' for a, b in t["cards"])
    out.append(page(lang, f'<h2>{t["why"]}</h2><div class="cards">{cards}</div>', n=2, total=total))
    steps = "".join(f'<div class="step"><i>{i}</i><b>{a}</b><span>{b}</span></div>' for i, (a, b) in enumerate(t["steps"], 1))
    out.append(page(lang, f'<h2>{t["how"]}</h2><div class="steps">{steps}</div>', n=3, total=total))
    facts = "".join(f"<li><b>{a}</b> — {b}</li>" for a, b in t["facts"])
    lim = "".join(f"<li>{x}</li>" for x in t["lim"])
    out.append(page(lang, f'<div class="facts"><div><h2>{t["brief"]}</h2><ul>{facts}</ul></div><div><h2>{t["limits"]}</h2><ul>{lim}</ul></div></div>', n=4, total=total))
    return out

# ---------------------------------------------------------------- Présentation de l'interface
UI = {
 "fr": dict(
  t1="La fenêtre du Hub", leg1=[
   "<b>Bibliothèque</b> — Toutes, Installées, Mises à jour, Non installées.",
   "<b>Recherche et tri</b> — par nom ou par état.",
   "<b>Cartes d'applis</b> — icône, état, description, et l'action utile (Installer, Mettre à jour, Ouvrir, Réglages).",
   "<b>Fiche</b> — description, version installée, dernière version, taille, dossier.",
   "<b>Mises à jour</b> — le bloc du bas liste les applis à mettre à jour et propose « Tout mettre à jour »."],
  t2="Clair ou sombre", p2="Le design Flat Round suit le thème du système : fond mat, grands arrondis (20), cartes blanches ou anthracite, accent bleu en sombre et violet en clair. Le « m » du nom prend la couleur du logo.",
  states="États d'une carte", chips=[("Non installée → Installer", ""), ("Mise à jour → Mettre à jour", "warn"), ("À jour → Ouvrir · Réglages", "ok"), ("Pas encore publique", "")],
  t3="Le menu de la barre des menus", leg3=[
   "<b>Une seule icône en couleur</b> ; une pastille rouge signale des mises à jour.",
   "<b>Une ligne par appli installée</b>, avec son icône ; au-delà de 10, le reste va dans « Autres applis ».",
   "<b>Sous-menu de chaque appli</b> — version et état, Ouvrir, Réglages… (si déclaré), icône de barre des menus, Mettre à jour, Quitter.",
   "<b>Tout mettre à jour</b>, catalogue, réglages de mHUB, à propos, quitter."],
  t4="Les réglages", leg4=[
   "<b>Présence</b> — Dock, barre des menus ou les deux.",
   "<b>Installation automatique</b> des mises à jour, jamais pendant qu'une appli est ouverte.",
   "<b>Fréquence</b> de vérification : quotidienne ou manuelle.",
   "<b>Dossier d'installation</b> et ouverture à la session.",
   "<b>Mise à jour de mHUB</b> lui-même et fenêtre « À propos »."]),
 "en": dict(
  t1="The Hub window", leg1=[
   "<b>Library</b> — All, Installed, Updates, Not installed.",
   "<b>Search and sort</b> — by name or by status.",
   "<b>App cards</b> — icon, status, description, and the useful action (Install, Update, Open, Settings).",
   "<b>Detail panel</b> — description, installed version, latest version, size, folder.",
   "<b>Updates</b> — the bottom block lists apps to update and offers “Update all”."],
  t2="Light or dark", p2="The Flat Round design follows the system theme: matte background, large corner radius (20), white or charcoal cards, blue accent in dark and violet in light. The “m” of the name takes the logo colour.",
  states="Card states", chips=[("Not installed → Install", ""), ("Update → Update", "warn"), ("Up to date → Open · Settings", "ok"), ("Not public yet", "")],
  t3="The menu bar menu", leg3=[
   "<b>One coloured icon</b>; a red dot flags available updates.",
   "<b>One line per installed app</b>, with its icon; beyond 10 the rest goes under “Other apps”.",
   "<b>Each app's submenu</b> — version and status, Open, Settings… (when declared), menu bar icon, Update, Quit.",
   "<b>Update all</b>, catalog, mHUB settings, about, quit."],
  t4="Settings", leg4=[
   "<b>Presence</b> — Dock, menu bar or both.",
   "<b>Automatic install</b> of updates, never while an app is open.",
   "<b>Check frequency</b>: daily or manual.",
   "<b>Install folder</b> and open at login.",
   "<b>mHUB's own update</b> and the About window."]),
}

def ui_pages(lang):
    t = UI[lang]; out = []; total = 4
    p1 = [(110, 300), (470, 100), (500, 300), (940, 300), (110, 650)]
    # pastilles : 1 bibliothèque, 2 recherche, 3 cartes, 4 fiche, 5 mises à jour
    p1 = [(14, 143), (240, 100), (506, 129), (784, 100), (14, 640)]
    out.append(page(lang, f'<h2>{t["t1"]}</h2><div class="row"><div class="shot" style="width:62%"><img src="screens/catalogue-dark.png">{pins(p1)}</div>{legend(t["leg1"])}</div>', n=1, total=total))
    chips = "".join(f'<span class="chip {c}">{x}</span>' for x, c in t["chips"])
    out.append(page(lang, f'<h2>{t["t2"]}</h2><div class="row"><div class="shot" style="width:62%"><img src="screens/catalogue-light.png"></div><div class="legend"><p style="font-size:14.5px">{t["p2"]}</p><h2 style="font-size:20px;margin:7mm 0 0">{t["states"]}</h2><div class="chips">{chips}</div></div></div>', n=2, total=total))
    out.append(page(lang, f'<h2>{t["t3"]}</h2><div class="row"><div class="shot" style="width:30%;background:#1e1e22"><img src="screens/menu.png"></div>{legend(t["leg3"])}</div>', n=3, total=total))
    out.append(page(lang, f'<h2>{t["t4"]}</h2><div class="row"><div class="shot" style="width:52%"><img src="screens/settings.png"></div>{legend(t["leg4"])}</div>', n=4, total=total))
    return out

def build(name, fn):
    body = "".join(fn("fr") + fn("en"))
    path = os.path.join(D, name + ".html")
    open(path, "w").write(f'<!doctype html><html><head><meta charset="utf-8"><title>{name}</title><style>{CSS}</style></head><body>{body}</body></html>')
    pdf = os.path.join(D, name + ".pdf")
    subprocess.run([BRAVE, "--headless=new", "--disable-gpu", "--no-pdf-header-footer", f"--print-to-pdf={pdf}", "file://" + path], check=True, capture_output=True)
    print(pdf)

build("mHUB-presentation-FR-EN", app_pages)
build("mHUB-interface-FR-EN", ui_pages)
