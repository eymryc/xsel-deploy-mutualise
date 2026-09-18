#!/usr/bin/env bash
# =============================================================================
# xsel-deploy-mutualise — common.sh
#
# Fonctions partagées par les scripts de déploiement server-side. Ce fichier
# est synchronisé vers le serveur à chaque déploiement (voir ADR-0004) : ne
# jamais le dupliquer dans un projet consommateur, toujours l'éditer ici.
#
# Attend les variables d'environnement suivantes (exportées par le script
# appelant, lui-même invoqué avec des arguments depuis le workflow) :
#   DEPLOY_PATH     racine de l'app sur le serveur (contient releases/, shared/, current)
#   TIMESTAMP       identifiant de la release en cours (ex. 20260918120000)
#   KEEP_RELEASES   nombre de releases à conserver (défaut 5)
# =============================================================================
set -euo pipefail

KEEP_RELEASES="${KEEP_RELEASES:-5}"
RELEASE_DIR="${DEPLOY_PATH}/releases/${TIMESTAMP}"

log()  { echo "▶ $*"; }
ok()   { echo "✅ $*"; }
die()  { echo "❌ $*" >&2; exit 1; }

require_dirs() {
  mkdir -p "${DEPLOY_PATH}/releases" "${DEPLOY_PATH}/shared"
}

# Bascule atomique du symlink `current` vers la release donnée.
swap_current() {
  local target="$1"
  ln -sfn "releases/${target}" "${DEPLOY_PATH}/current_tmp"
  mv -T "${DEPLOY_PATH}/current_tmp" "${DEPLOY_PATH}/current"
  ok "current -> releases/${target}"
}

# Repointe `current` sur la release précédente (celle juste avant $1).
rollback_from() {
  local failed="$1"
  local previous
  previous="$(list_releases | grep -v "^${failed}\$" | tail -1 || true)"
  [ -n "$previous" ] || die "Aucune release précédente disponible pour rollback."
  log "Rollback : current -> releases/${previous}"
  swap_current "$previous"
}

list_releases() {
  find "${DEPLOY_PATH}/releases" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

cleanup_releases() {
  local total
  total="$(list_releases | wc -l | tr -d ' ')"
  local to_remove=$(( total - KEEP_RELEASES ))
  [ "$to_remove" -gt 0 ] || { log "Rien à nettoyer (${total}/${KEEP_RELEASES} releases)."; return 0; }

  list_releases | head -n "$to_remove" | while read -r old; do
    log "Suppression de l'ancienne release ${old}"
    rm -rf "${DEPLOY_PATH}/releases/${old:?}"
  done
  ok "Nettoyage terminé (${KEEP_RELEASES} releases conservées)."
}

# curl un healthcheck ; renvoie 1 si échec (pour déclencher un rollback côté appelant)
health_check() {
  local url="$1"
  [ -n "$url" ] || return 0
  log "Healthcheck : ${url}"
  for _ in 1 2 3 4 5; do
    if curl -fsS -o /dev/null --max-time 10 "$url"; then
      ok "Healthcheck OK"
      return 0
    fi
    sleep 3
  done
  echo "❌ Healthcheck KO après 5 tentatives" >&2
  return 1
}
