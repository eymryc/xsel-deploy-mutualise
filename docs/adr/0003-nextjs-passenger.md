# ADR-0003 — Next.js sur mutualisé via cPanel "Setup Node.js App" (Passenger)

## Statut
Accepté (2026-09-18)

## Contexte
Sur un vrai hébergement mutualisé, il n'y a pas d'accès root : pas de
`systemd`, pas de PM2 en tant que démon (aucun droit de créer un service
persistant hors du contrôle du panel). Le mécanisme fourni pour faire
tourner une app Node est l'interface cPanel **"Setup Node.js App"**, adossée
à **Phusion Passenger**, qui gère le cycle de vie du process pour le compte
de l'hébergeur.

## Décision
- Le build Next.js utilise `output: "standalone"` (à ajouter dans
  `next.config.ts` de chaque projet consommateur). Le build standalone
  embarque déjà le sous-ensemble minimal de `node_modules` nécessaire :
  **pas d'installation npm côté serveur**, ce qui évite un `npm install`
  lent/fragile sur un mutualisé.
- Le fichier de démarrage déclaré dans l'interface cPanel Node.js App est
  directement `current/server.js` (le serveur généré par le build
  standalone), qui lit déjà `process.env.PORT` — exactement ce que Passenger
  fournit. Pas de fichier `app.js` custom nécessaire.
- Le paquet livré sur le serveur contient : `.next/standalone/` (à la racine
  de la release), `.next/static/` copié dans
  `<release>/.next/static/`, et `public/` copié dans `<release>/public/`.
- Redémarrage après bascule du symlink `current` : `mkdir -p
  current/tmp && touch current/tmp/restart.txt` (convention Passenger).
- Les variables d'environnement runtime (secrets serveur, hors
  `NEXT_PUBLIC_*` figés au build) sont saisies **une fois** dans l'onglet
  "Environment Variables" de l'interface cPanel Node.js App — ce n'est pas
  un fichier du dépôt ni un secret GitHub, car cPanel les injecte lui-même
  au démarrage du process.

## Conséquences
- Onboarding d'un nouveau projet Next.js : créer l'app dans cPanel "Setup
  Node.js App" une fois (choix du dossier `current`, version Node, fichier
  de démarrage `server.js`), avant le premier déploiement automatisé.
- Toute variable `NEXT_PUBLIC_*` doit être connue **au moment du build**
  (donc présente dans les secrets GitHub Actions injectés pendant le job
  CI), pas seulement côté cPanel.
