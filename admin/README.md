# Aricie Backoffice

Interface web React 19 + TypeScript construite avec Vite. Le frontend statique lit les données métier depuis les routes réelles de l'Edge Function Supabase `admin-api` ; aucun jeu de données de démonstration n'est inclus. La clé `service_role` ne doit jamais être ajoutée au frontend ni aux variables de build.

## Prérequis

- Bun (le lockfile du projet est `bun.lock`)
- Accès au projet Supabase utilisé par `admin-api`

## Développement local

```bash
bun install --frozen-lockfile
cp .env.example .env.local
# Renseigner VITE_SUPABASE_URL et VITE_SUPABASE_ANON_KEY dans .env.local
bun run dev
```

`VITE_SUPABASE_ANON_KEY` est une clé publique destinée au navigateur. Ne jamais utiliser la clé `service_role` ici. Les routes de données exigent une session Supabase authentifiée ; l'accès et le niveau RBAC sont vérifiés côté `admin-api` via `GET /v1/me`. Le backoffice utilise `signInWithPassword`, restaure la session Supabase au chargement et fournit une déconnexion. Déployer l'Edge Function et appliquer les migrations nécessaires avant la mise en production. Les pages affichent les retours API et des états vides explicites ; elles ne substituent aucune donnée locale fictive.

Les notes internes utilisent les routes existantes `/v1/admin/notes`. Il n'existe pas de ressource ni de route ticket dans `admin-api` : la vue Support indique cette limite et ne prétend pas créer des tickets. Les paramètres de devise sont locaux à l'interface ; ils ne modifient pas la devise ou les paiements stockés.

## Vérifications

```bash
bun run lint
bun run test
bun run build
```

Vite produit les fichiers statiques dans `dist/`. Les variables `VITE_*` sont intégrées au bundle au moment du build ; fournir les valeurs du bon environnement avant `bun run build`.
