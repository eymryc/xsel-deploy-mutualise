#!/usr/bin/env bash
# =============================================================================
# xsel-deploy-mutualise — deploy-nextjs-passenger.sh
#
# Exécuté SUR LE SERVEUR (via ssh), une fois que le workflow a déjà rsync
# le build Next.js standalone dans releases/<TIMESTAMP>/ :
#   releases/<TIMESTAMP>/
#   ├── server.js          (.next/standalone/server.js)
#   ├── node_modules/       (minimal, tracé par Next — pas d'install serveur)
#   ├── .next/static/
#   └── public/
#
# Voir ADR-0003 : les variables d'environnement runtime sont configurées une
# fois pour toutes dans l'interface cPanel "Setup Node.js App", pas ici.
#
# Variables d'environnement requises :
#   DEPLOY_PATH        racine de l'app (contient releases/, shared/, current)
#   TIMESTAMP            identifiant de la release à activer
#   KEEP_RELEASES          (défaut: 5)
#   HEALTH_CHECK_URL         (optionnel)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

HEALTH_CHECK_URL="${HEALTH_CHECK_URL:-}"

[ -d "$RELEASE_DIR" ] || die "Release introuvable : $RELEASE_DIR (le rsync a-t-il échoué ?)"
[ -f "${RELEASE_DIR}/server.js" ] || die "server.js absent de la release — vérifiez next.config (output: 'standalone')."

require_dirs

swap_current "$TIMESTAMP"

log "Redémarrage Passenger (touch tmp/restart.txt)"
mkdir -p "${DEPLOY_PATH}/current/tmp"
touch "${DEPLOY_PATH}/current/tmp/restart.txt"

# Passenger ne relance le process qu'au prochain hit HTTP entrant ; le
# healthcheck ci-dessous (contre le domaine public) sert aussi de premier hit.
sleep 2

if [ -n "$HEALTH_CHECK_URL" ]; then
  if ! health_check "$HEALTH_CHECK_URL"; then
    rollback_from "$TIMESTAMP"
    mkdir -p "${DEPLOY_PATH}/current/tmp"
    touch "${DEPLOY_PATH}/current/tmp/restart.txt"
    die "Déploiement annulé (healthcheck KO) — rollback effectué vers la release précédente."
  fi
fi

cleanup_releases
ok "Déploiement Next.js terminé : releases/${TIMESTAMP}"
