# ADR-0005 — Séparation CI (tests) / CD (déploiement)

## Statut
Accepté (2026-09-18)

## Contexte
Le déploiement ne doit jamais expédier du code non vérifié, et ne doit
jamais partir d'une branche non fusionnée.

## Décision
- **CI** (tests, lint) tourne sur chaque push et chaque pull request, quelle
  que soit la branche. Ce n'est **pas** la responsabilité de
  `xsel-deploy-mutualise` : chaque projet garde sa propre CI (déjà en place
  pour beaucoup, ex. `dolci-reva-api/.github/workflows/ci.yml`), car les
  tests sont spécifiques au code métier du projet.
- **CD** (le workflow réutilisable de ce repo) ne se déclenche que sur push
  vers `main` (ou un tag de release), et seulement via un job qui dépend
  explicitement (`needs:`) du succès du job de CI dans le workflow appelant.
  Aucun déploiement automatique depuis une PR ou une branche de feature.
- En cas d'échec d'un déploiement à mi-chemin (ex. `composer install` échoue
  côté serveur), la release en cours n'est jamais basculée sur `current` :
  le site continu de servir l'ancienne release sans interruption (voir
  ADR-0002).

## Conséquences
- Un projet consommateur qui n'a pas encore de CI doit s'en doter avant
  d'activer le déploiement automatique via ce kit — sinon rien n'empêche du
  code cassé d'être déployé dès le merge.
