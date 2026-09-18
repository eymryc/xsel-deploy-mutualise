#!/usr/bin/env bash
# =============================================================================
# xsel-deploy-mutualise — rollback.sh
#
# Rollback manuel, à lancer sur le serveur (ou via ssh depuis un poste local) :
#   DEPLOY_PATH=/home/user/api.peci.org bash rollback.sh            # -> release précédente
#   DEPLOY_PATH=/home/user/api.peci.org bash rollback.sh 20260918113000  # -> release précise
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

TARGET="${1:-}"

if [ -z "$TARGET" ]; then
  current_target="$(readlink "${DEPLOY_PATH}/current" | sed 's#releases/##')"
  TARGET="$(list_releases | grep -v "^${current_target}\$" | tail -1 || true)"
  [ -n "$TARGET" ] || die "Aucune release précédente trouvée pour rollback automatique."
else
  [ -d "${DEPLOY_PATH}/releases/${TARGET}" ] || die "Release ${TARGET} introuvable."
fi

log "Rollback vers releases/${TARGET}"
swap_current "$TARGET"

# Redémarrage adapté à la stack de la release ciblée.
if [ -f "${DEPLOY_PATH}/current/server.js" ]; then
  mkdir -p "${DEPLOY_PATH}/current/tmp"
  touch "${DEPLOY_PATH}/current/tmp/restart.txt"
  log "Passenger : restart.txt touché"
elif [ -f "${DEPLOY_PATH}/current/artisan" ]; then
  ( cd "${DEPLOY_PATH}/current" && "${PHP_BIN:-php}" artisan config:cache >/dev/null )
  log "Laravel : config recachée"
fi

ok "current -> releases/${TARGET}"
