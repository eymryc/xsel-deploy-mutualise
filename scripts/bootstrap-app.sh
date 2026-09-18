#!/usr/bin/env bash
# =============================================================================
# xsel-deploy-mutualise — bootstrap-app.sh
#
# Prépare UNE FOIS la structure serveur d'une app avant son premier
# déploiement automatisé (voir README, section Onboarding, étape 3).
#
# Usage (sur le serveur, via SSH) :
#   DEPLOY_PATH=/home/user/api.peci.org STACK=laravel bash bootstrap-app.sh
#   DEPLOY_PATH=/home/user/peci.org     STACK=nextjs-passenger bash bootstrap-app.sh
# =============================================================================
set -euo pipefail

[ -n "${DEPLOY_PATH:-}" ] || { echo "❌ DEPLOY_PATH requis" >&2; exit 1; }
STACK="${STACK:-}"

mkdir -p "${DEPLOY_PATH}/releases" "${DEPLOY_PATH}/shared"
echo "✅ ${DEPLOY_PATH}/releases et /shared créés"

if [ "$STACK" = "laravel" ]; then
  mkdir -p "${DEPLOY_PATH}/shared/storage"/{app,framework,logs}
  mkdir -p "${DEPLOY_PATH}/shared/storage/framework"/{cache,sessions,views}
  echo "✅ ${DEPLOY_PATH}/shared/storage créé"

  if [ ! -f "${DEPLOY_PATH}/shared/.env" ]; then
    touch "${DEPLOY_PATH}/shared/.env"
    chmod 600 "${DEPLOY_PATH}/shared/.env"
    echo "⚠️  ${DEPLOY_PATH}/shared/.env créé VIDE — à remplir manuellement avant le premier déploiement (le script de déploiement refusera de continuer sinon)."
  else
    echo "ℹ️  ${DEPLOY_PATH}/shared/.env existe déjà, inchangé."
  fi
fi

echo "✅ Bootstrap terminé pour ${DEPLOY_PATH}"
