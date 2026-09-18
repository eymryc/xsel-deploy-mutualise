# ADR-0002 — Releases horodatées + symlink `current` (zéro downtime)

## Statut
Accepté (2026-09-18)

## Contexte
Un déploiement qui écrase les fichiers en place (`git pull` / rsync direct
dans le dossier servi) expose une fenêtre où le site sert un mélange
d'ancien et de nouveau code, et ne permet aucun retour arrière rapide en
cas de problème détecté après coup.

## Décision
Chaque déploiement suit le schéma (Deployer / Capistrano) :

```
<deploy_path>/
├── releases/
│   ├── 20260918114500/
│   └── 20260918120000/   ← nouvelle release
├── shared/                ← persiste entre releases
│   ├── .env
│   └── storage/  (Laravel) ou .env.production (Next.js)
└── current -> releases/20260918120000   ← symlink, bascule atomique
```

1. La nouvelle release est construite entièrement dans
   `releases/<timestamp>/` (code, dépendances installées, symlinks vers
   `shared/`) **avant** toute bascule.
2. Le symlink `current` n'est repointé qu'une fois la release prête et
   validée (dépendances installées, migrations passées).
3. La bascule est atomique : `ln -sfn releases/<ts> current_tmp && mv -T
   current_tmp current`.
4. Le document root du (sous-)domaine cPanel pointe sur
   `current/public` (Laravel) ou l'app Node cPanel pointe sur `current`
   (Next.js) — jamais directement sur un dossier `releases/<ts>/`.
5. Rollback = repointer `current` sur la release précédente (`rollback.sh`),
   en quelques secondes, sans rebuild.
6. `keep_releases` (défaut : 5) anciennes releases sont conservées sur le
   serveur puis purgées, pour permettre un rollback même après plusieurs
   déploiements et limiter l'usage disque (souvent contraint en mutualisé).

## Conséquences
- Chaque déploiement consomme un peu plus d'espace disque le temps de la
  bascule (deux releases coexistent brièvement) — acceptable vu le faible
  nombre de releases conservées.
- Tout ce qui doit survivre aux déploiements (fichiers uploadés, `.env`,
  logs Laravel) doit vivre dans `shared/` et être symlinké dans la release,
  jamais écrit directement dans `releases/<ts>/`.
