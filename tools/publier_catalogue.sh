#!/bin/zsh
# Publie le catalogue des applis (descriptifs, catégories, applis ajoutées ou retirées) sans nouvelle version de mHUB.
# Usage : tools/publier_catalogue.sh [message de commit]
# Régénère Resources/catalogue.json, le commite, le pousse sur main et vérifie que GitHub le sert.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/gen_catalogue.py
if git diff --quiet -- Resources/catalogue.json tools/gen_catalogue.py; then
  echo "Catalogue inchangé : rien à publier."; exit 0
fi
MSG="${1:-Catalogue : mise à jour des applis et des descriptifs}"
git add Resources/catalogue.json tools/gen_catalogue.py
git commit -q -m "$MSG

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
git push -q origin main
V=$(python3 -c 'import json;print(json.load(open("Resources/catalogue.json"))["version"])')
echo "Poussé (catalogue version $V). Vérification côté GitHub…"
for i in {1..12}; do
  R=$(gh api repos/starbudweiser/mHUB/contents/Resources/catalogue.json --jq .content | base64 -d | python3 -c 'import json,sys;print(json.load(sys.stdin)["version"])')
  [[ "$R" == "$V" ]] && { echo "OK : GitHub sert la version $V. Les mHUB la reprennent à leur prochaine vérification (≤ 30 min, plus le cache de GitHub)."; exit 0; }
  sleep 5
done
echo "Poussé, mais GitHub ne sert pas encore la version $V (cache) : réessayer dans quelques minutes." >&2
