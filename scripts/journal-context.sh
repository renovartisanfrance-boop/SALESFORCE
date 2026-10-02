#!/usr/bin/env bash
# Affiche au démarrage de chaque session Claude Code :
#   - l'état Git (branche, retard sur GitHub, branches des autres développeurs)
#   - les dernières entrées du journal de bord et le travail encore "en cours"
# La sortie est lue par Claude pour reprendre le contexte. Ne modifie aucun fichier.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}" || exit 0

NB=${JOURNAL_NB:-5}

field() { awk -v k="$2" 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} index($0,k":")==1{sub(k":[ ]*","");print;exit}' "$1"; }

echo "=== CONTEXTE DU PROJET (journal de bord) ==="

if git rev-parse --git-dir >/dev/null 2>&1; then
  timeout 20 git fetch -q --prune origin 2>/dev/null || true
  br=$(git branch --show-current 2>/dev/null)
  echo "Branche actuelle : ${br:-?}"
  if [ -n "$br" ] && git rev-parse -q --verify "origin/$br" >/dev/null; then
    behind=$(git rev-list --count "HEAD..origin/$br" 2>/dev/null || echo 0)
    ahead=$(git rev-list --count "origin/$br..HEAD" 2>/dev/null || echo 0)
    [ "$behind" -gt 0 ] && echo "ATTENTION : $behind commit(s) sur GitHub pas encore récupérés -> faire 'git pull --rebase' avant de travailler."
    [ "$ahead" -gt 0 ] && echo "$ahead commit(s) locaux pas encore poussés."
  fi
  others=$(git for-each-ref --sort=-committerdate --format='%(refname:short) | %(committerdate:relative) | %(authorname) | %(contents:subject)' refs/remotes/origin \
    | grep -v -E '^origin(/HEAD)? ' | grep -v "^origin/${br:-__none__} " | head -8)
  if [ -n "$others" ]; then
    echo; echo "Autres branches actives sur GitHub :"; echo "$others" | sed 's/^/  - /'
  fi
fi

files=$(find journal -type f -name '20*.md' 2>/dev/null | sort -r)
if [ -z "$files" ]; then
  echo; echo "Journal vide pour l'instant."; exit 0
fi

echo; echo "Travaux marqués « en cours » :"
found=0
for f in $files; do
  if [ "$(field "$f" statut)" = "en cours" ]; then
    echo "  - $(field "$f" date) | $(field "$f" auteur) | $(field "$f" sujet) | branche $(field "$f" branche) | $f"; found=1
  fi
done
[ $found -eq 0 ] && echo "  (aucun)"

echo; echo "Dernières entrées ($NB) :"
for f in $(echo "$files" | head -n "$NB"); do
  echo; echo "--- $(field "$f" date) | $(field "$f" auteur) | $(field "$f" statut) | $(field "$f" sujet)"
  echo "    ($f)"
  awk '/^## Prochaines étapes/{p=1;next} /^## /{p=0} p&&NF' "$f" | head -6 | sed 's/^/    /'
done

echo
echo "Règle : créer sa propre entrée dans journal/AAAA/MM/ pour cette session (voir journal/README.md)."
exit 0
