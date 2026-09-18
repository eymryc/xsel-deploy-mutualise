#!/usr/bin/env bash
# =============================================================================
# xsel-deploy-mutualise — deploy-laravel.sh
#
# Exécuté SUR LE SERVEUR (via ssh), une fois que le workflow a déjà rsync
# le code source de la release dans releases/<TIMESTAMP>/ (sans vendor/,
# sans .env, sans storage/ — voir ADR-0002).
#
# Variables d'environnement requises :
#   DEPLOY_PATH        racine de l'app (contient releases/, shared/, current)
#   TIMESTAMP           identifiant de la release à activer
#   PHP_BIN              (défaut: php)
#   COMPOSER_BIN          (défaut: composer)
#   KEEP_RELEASES          (défaut: 5)
#   HEALTH_CHECK_URL         (optionnel — si vide, pas de vérification post-deploy)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

PHP_BIN="${PHP_BIN:-php}"
COMPOSER_BIN="${COMPOSER_BIN:-composer}"
HEALTH_CHECK_URL="${HEALTH_CHECK_URL:-}"

[ -d "$RELEASE_DIR" ] || die "Release introuvable : $RELEASE_DIR (le rsync a-t-il échoué ?)"
[ -f "${DEPLOY_PATH}/shared/.env" ] || die "shared/.env manquant — créez-le une fois manuellement avant le premier déploiement."

require_dirs
mkdir -p "${DEPLOY_PATH}/shared/storage"/{app,framework,logs}
mkdir -p "${DEPLOY_PATH}/shared/storage/framework"/{cache,sessions,views}

log "Symlinks partagés (.env, storage)"
ln -sfn "${DEPLOY_PATH}/shared/.env" "${RELEASE_DIR}/.env"
rm -rf "${RELEASE_DIR}/storage"
ln -sfn "${DEPLOY_PATH}/shared/storage" "${RELEASE_DIR}/storage"

cd "$RELEASE_DIR"

log "composer install --no-dev"
"$COMPOSER_BIN" install --no-dev --optimize-autoloader --no-interaction --no-progress

log "artisan config:cache / route:cache / view:cache"
"$PHP_BIN" artisan config:cache
"$PHP_BIN" artisan route:cache
"$PHP_BIN" artisan view:cache

log "artisan migrate --force"
"$PHP_BIN" artisan migrate --force

log "artisan storage:link (idempotent — le lien pointe déjà vers shared/storage)"
"$PHP_BIN" artisan storage:link --force || true

swap_current "$TIMESTAMP"

if [ -n "$HEALTH_CHECK_URL" ]; then
  if ! health_check "$HEALTH_CHECK_URL"; then
    rollback_from "$TIMESTAMP"
    die "Déploiement annulé (healthcheck KO) — rollback effectué vers la release précédente."
  fi
fi

cleanup_releases
ok "Déploiement Laravel terminé : releases/${TIMESTAMP}"
