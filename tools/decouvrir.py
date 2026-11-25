#!/usr/bin/env python3
"""Découverte automatique : ajoute au catalogue les dépôts publics de starbudweiser portant le topic
`desktop-mac-toolkit` et au moins une release avec un .zip. Retire les entrées automatiques qui ne qualifient plus.
Les entrées rédigées à la main (gen_catalogue.py) ne sont jamais touchées. Topics facultatifs `mhub-<catégorie>` (plusieurs possibles)
(system, files, creative, video, games, comms, ai, virt) ; sinon « system ». Nécessite `gh` (connecté, ou GH_TOKEN)."""
import json, os, plistlib, subprocess, sys, base64, time
OWNER, TOPIC = "starbudweiser", "desktop-mac-toolkit"
PATH = os.path.join(os.path.dirname(__file__), "..", "Resources", "catalogue.json")
CATS = {"system", "files", "creative", "video", "games", "comms", "ai", "virt"}

TRAD = json.load(open(os.path.join(os.path.dirname(__file__), "descriptions_auto.json")))  # traductions rédigées à la main

def gh(*a):
    r = subprocess.run(["gh", "api", *a], capture_output=True, text=True)
    return json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else None

def candidats():
    res = gh(f"search/repositories?q=user:{OWNER}+topic:{TOPIC}&per_page=100") or {"items": []}
    for r in res["items"]:
        if r["private"] or r["archived"] or r["fork"] or r["name"] == "mHUB": continue
        rel = gh(f"repos/{OWNER}/{r['name']}/releases/latest")
        if not rel or not any(a["name"].endswith(".zip") for a in rel.get("assets", [])): continue
        yield r

def bundle_id(repo):
    for p in ("Resources/Info.plist", "Info.plist"):
        c = gh(f"repos/{OWNER}/{repo}/contents/{p}")
        if c and c.get("content"):
            try:
                b = plistlib.loads(base64.b64decode(c["content"])).get("CFBundleIdentifier", "")
            except Exception: continue
            if b and "$(" not in b and "__" not in b: return b
    # Info.plist modèle (__ID__) : l'identifiant est dans build_app.sh (ID="…", hors édition .dev).
    c = gh(f"repos/{OWNER}/{repo}/contents/build_app.sh")
    if c and c.get("content"):
        import re
        for b in re.findall(r'\bID="([A-Za-z0-9.\-]+)"', base64.b64decode(c["content"]).decode("utf8", "ignore")):
            if not b.endswith((".dev", ".test")): return b
    return None

def main():
    cat = json.load(open(PATH)); orig = json.loads(json.dumps(cat["apps"]))
    manuels = {a["id"].lower() for a in cat["apps"] if not a.get("auto")}
    avant = [a for a in cat["apps"] if a.get("auto")]
    gardees = [a for a in cat["apps"] if not a.get("auto")]
    existants = {a["id"]: a for a in avant}
    nouveaux = []
    for r in candidats():
        n = r["name"]
        if n.lower() in manuels: continue
        e = existants.get(n)
        if not e or "__" in e["bundleId"]:
            b = bundle_id(n)
            if not b: print(f"  ignoré {n} : identifiant de paquet introuvable", file=sys.stderr); continue
            d = (r.get("description") or "Application du Desktop Mac Toolkit.").strip()
            e = {"id": n, "name": n, "bundleId": b, "desc": dict.fromkeys(("fr", "en", "es", "it"), d), "repo": n, "auto": True}
        if n in TRAD: e["desc"] = TRAD[n]
        cs = [t[5:] for t in r.get("topics", []) if t.startswith("mhub-") and t[5:] in CATS]
        e["cats"] = cs or ["system"]
        e["category"] = next((c for c in cs if c in ("system", "files", "creative", "comms", "ai", "virt")), "creative" if cs else "system")
        nouveaux.append(e)
    apres = gardees + sorted(nouveaux, key=lambda a: a["id"].lower())
    if apres == orig:
        print("Découverte : rien de nouveau."); return
    cat["apps"] = apres; cat["version"] = max(int(time.time()), cat["version"] + 1)
    json.dump(cat, open(PATH, "w"), ensure_ascii=False, indent=1)
    print("Découverte :", ", ".join(a["id"] for a in nouveaux) or "aucune appli automatique")
main()
