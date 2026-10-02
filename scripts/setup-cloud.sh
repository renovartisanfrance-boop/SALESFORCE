#!/usr/bin/env bash
# Installe automatiquement les outils au démarrage d'une session Claude Code dans le cloud
# (claude.ai/code). Ne fait rien sur un ordinateur local.
set -uo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}" || exit 0

log() { echo "[setup] $*"; }

# 1. Dépendances du projet (ESLint, Prettier pour Apex/XML, Jest pour LWC)
if [ ! -d node_modules ]; then
  log "npm install"
  npm install --no-audit --no-fund --loglevel=error || log "npm install a échoué"
fi

# 2. Salesforce CLI (sf)
if ! command -v sf >/dev/null 2>&1; then
  log "Installation de Salesforce CLI"
  npm install -g @salesforce/cli --no-audit --no-fund --loglevel=error || log "Installation de sf a échoué"
fi

# 3. Méthode BMAD (agents analyste, PM, architecte, dev, QA) — seulement si absente
if [ ! -d _bmad ]; then
  log "Installation de BMAD"
  npx -y bmad-method install --directory . --modules bmm --tools claude-code --yes \
    --user-name "Micke" --communication-language French --document-output-language French \
    || log "Installation de BMAD a échoué"
fi

# 4. Connexion à l'org Salesforce si une URL d'authentification est fournie
#    (variable SF_AUTH_URL définie dans les variables d'environnement du cloud, jamais dans le dépôt)
if [ -n "${SF_AUTH_URL:-}" ] && command -v sf >/dev/null 2>&1; then
  if ! sf org display --target-org renov >/dev/null 2>&1; then
    log "Connexion à l'org Salesforce"
    tmp="$(mktemp)"; printf '%s' "$SF_AUTH_URL" > "$tmp"
    sf org login sfdx-url --sfdx-url-file "$tmp" --alias renov --set-default \
      >/dev/null 2>&1 || log "Connexion Salesforce a échoué"
    rm -f "$tmp"
  fi
fi

exit 0
