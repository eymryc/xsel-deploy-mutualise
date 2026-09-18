# xsel-deploy-mutualise

Source de vérité unique pour le déploiement CI/CD des projets XSEL vers un
hébergement mutualisé cPanel (SSH par clé + `Setup Node.js App` /
Passenger pour Node). Un projet consommateur n'a qu'à appeler le workflow
réutilisable de ce repo — la logique de déploiement (releases horodatées,
bascule atomique, rollback, redémarrage) vit ici et nulle part ailleurs.

Voir les décisions d'architecture dans [`docs/adr/`](docs/adr/) :

- [ADR-0001](docs/adr/0001-ssh-rsync-transport.md) — transport SSH + rsync/scp
- [ADR-0002](docs/adr/0002-releases-symlink-zero-downtime.md) — releases/ + symlink `current`
- [ADR-0003](docs/adr/0003-nextjs-passenger.md) — Next.js via cPanel Passenger
- [ADR-0004](docs/adr/0004-central-reusable-workflow.md) — repo central, workflow réutilisable
- [ADR-0005](docs/adr/0005-ci-cd-separation.md) — séparation CI / CD

## Stacks supportées

| `stack`            | Build (CI)                          | Serveur                                  |
|---------------------|---------------------------------------|---------------------------------------------|
| `laravel`             | `composer` (tests, via CI du projet), `npm run build` (Vite, optionnel) | `composer install --no-dev`, migrations, cache Laravel |
| `nextjs-passenger`      | `next build` (`output: "standalone"` requis) | Aucune install serveur — le build standalone embarque ses dépendances |

## Onboarding d'un nouveau projet

1. **Générer une clé SSH dédiée au déploiement** dans cPanel → *SSH Access*
   → *Manage SSH Keys* → *Generate a New Key* (pas de passphrase), puis
   *Authorize* sur cette clé.
2. Récupérer host / port / utilisateur SSH sur la page principale
   *SSH Access*.
3. Sur le serveur, créer la structure de base pour chaque app (avant le
   premier déploiement) :
   ```bash
   mkdir -p /home/<user>/<app>/{releases,shared}
   # Laravel uniquement : déposer le .env de prod
   nano /home/<user>/<app>/shared/.env
   ```
4. Côté cPanel → *Domains* : document root du (sous-)domaine sur
   `<deploy_path>/current/public` (Laravel), ou créer l'app dans
   *Setup Node.js App* pointant sur `<deploy_path>/current/server.js`
   (Next.js — voir [`templates/passenger-nextjs-notes.md`](templates/passenger-nextjs-notes.md)
   pour le détail).
5. Dans le projet consommateur, ajouter les secrets GitHub Actions :
   `DEPLOY_SSH_HOST`, `DEPLOY_SSH_PORT`, `DEPLOY_SSH_USER`,
   `DEPLOY_SSH_PRIVATE_KEY` (le contenu de la clé privée générée à l'étape 1).
6. Copier [`templates/caller-workflow.example.yml`](templates/caller-workflow.example.yml)
   dans `.github/workflows/` du projet, adapter `stack` / `app_path` /
   `deploy_path` / `health_check_url`.
7. Premier push sur `main` → déploiement automatique.

## Rollback manuel

```bash
ssh <user>@<host> -p <port>
DEPLOY_PATH=/home/<user>/<app> bash /home/<user>/<app>/.deploy-scripts/rollback.sh
# ou vers une release précise :
DEPLOY_PATH=/home/<user>/<app> bash /home/<user>/<app>/.deploy-scripts/rollback.sh 20260918113000
```

## Statut

Conçu et validé (ADR) avec PECI comme premier projet de référence — pas
encore éprouvé en déploiement réel. À faire évoluer au fil des premiers
déploiements avant de tagger une v1.
