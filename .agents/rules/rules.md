## 📋 TABLE DES MATIÈRES

1. [INIT — Audit global obligatoire](#1-init--audit-global-obligatoire)
2. [SÉCURITÉ — Secrets & Exposition](#2-sécurité--secrets--exposition)
3. [GIT — Configuration & Hygiène](#3-git--configuration--hygiène)
4. [DÉPENDANCES — Audit & Vulnérabilités](#4-dépendances--audit--vulnérabilités)
5. [ARCHITECTURE — Clean & Multiservices](#5-architecture--clean--multiservices)
6. [QUALITÉ CODE — Lint, Types & Tests](#6-qualité-code--lint-types--tests)
7. [PERFORMANCE — Assets, Streaming, CDN](#7-performance--assets-streaming-cdn)
8. [BASE DE DONNÉES — Optimisation & Sécurité](#8-base-de-données--optimisation--sécurité)
9. [SÉCURITÉ APPLICATIVE — Auth, API, Formulaires](#9-sécurité-applicative--auth-api-formulaires)
10. [FRONTEND REACT — Async, State, Composants](#10-frontend-react--async-state-composants)
11. [ANTIPATTERNS — À éviter absolument](#11-antipatterns--à-éviter-absolument)
12. [WORKFLOW — Avant / Pendant / Après le code](#12-workflow--avant--pendant--après-le-code)
13. [DOCUMENTATION — Traçabilité des tâches](#13-documentation--traçabilité-des-tâches)
14. [SKILLS — Routes obligatoires vers les agents](#14-skills--routes-obligatoires-vers-les-agents)

---

## 1. INIT — Audit global obligatoire

> À exécuter **immédiatement** au chargement de ce fichier ou lors de l'initialisation d'une session.

### 1.1 Détection du contexte technologique

```bash
# Identifier le runtime principal
node --version 2>/dev/null && echo "→ Node détecté"
python3 --version 2>/dev/null && echo "→ Python détecté"
go version 2>/dev/null && echo "→ Go détecté"
ruby --version 2>/dev/null && echo "→ Ruby détecté"
php --version 2>/dev/null && echo "→ PHP détecté"

# Identifier le framework
cat package.json 2>/dev/null | grep -E '"next"|"nuxt"|"remix"|"vite"|"react"|"vue"|"svelte"'
cat requirements.txt 2>/dev/null | head -20
cat go.mod 2>/dev/null | head -10
```

### 1.2 Audit de l'architecture globale

Au démarrage, **lire et cartographier** :

```
✅ Structure des dossiers (src/, app/, lib/, services/, components/, hooks/, utils/)
✅ Points d'entrée (index.ts, main.ts, server.ts, app.ts)
✅ Configuration (next.config.*, vite.config.*, tsconfig.json, .env.*)
✅ Fichiers de routes (routes/, pages/, app/ selon le framework)
✅ Middlewares et intercepteurs
✅ Services externes connectés (Stripe, Supabase, Firebase, Prisma, etc.)
✅ Schémas de base de données (schema.prisma, migrations/, models/)
✅ Fichiers d'authentification (auth.ts, middleware.ts, guards/)
✅ Points d'API exposés (api/, endpoints/, controllers/)
✅ Formulaires existants (forms/, components/Form*)
✅ Configuration CI/CD (.github/workflows/, .gitlab-ci.yml, Dockerfile)
```

### 1.3 Checklist INIT obligatoire

```
□ package.json lu et analysé
□ tsconfig.json vérifié (strict: true ?)
□ .env.example vs .env comparés
□ .gitignore vérifié et complété si nécessaire
□ Dépendances auditées (npm audit / yarn audit)
□ Version Node/runtime conforme aux specs
□ Architecture globale cartographiée
□ Routes et pages existantes listées
□ Code existant à chaque ajout de code revoir les fonctions, types, etc qui dépendent d'autres fichiers que tu changes et créer des problèmes de types, parametres ou autres
□ Composants et hooks réutilisables identifiés
□ Services d'authentification identifiés
□ Endpoints API inventoriés
□ Formulaires existants inspectés
```

---

## 2. SÉCURITÉ — Secrets & Exposition

### 2.1 Règles absolues sur les secrets

```
🚫 JAMAIS hardcoder une clé API, token, mot de passe, DSN dans le code source
🚫 JAMAIS committer un fichier .env, .env.local, .env.production
🚫 JAMAIS logger une variable d'environnement sensible (console.log(process.env))
🚫 JAMAIS exposer des secrets dans les logs applicatifs
🚫 JAMAIS stocker des credentials en clair dans la base de données
🚫 JAMAIS inclure des secrets dans les réponses API
```

### 2.2 Pattern obligatoire — Variables d'environnement

```typescript
// ✅ Validation obligatoire au démarrage (Zod ou équivalent)
import { z } from 'zod';

const EnvSchema = z.object({
  DATABASE_URL: z.string().url(),
  NEXTAUTH_SECRET: z.string().min(32),
  NEXTAUTH_URL: z.string().url(),
  API_KEY: z.string().min(10),
  NODE_ENV: z.enum(['development', 'staging', 'production']),
});

export const env = EnvSchema.parse(process.env);
// → L'app plante au démarrage si un secret est manquant, jamais en production silencieusement
```

### 2.3 Séparation dev / prod

```
✅ .env               → valeurs par défaut non sensibles
✅ .env.local          → secrets locaux développeur (jamais commité)
✅ .env.production     → JAMAIS dans le repo, injecté par CI/CD
✅ Variables d'infra   → gestionnaire de secrets (Vault, Doppler, AWS SSM, Vercel Env)
```

### 2.4 Rotation et durée de vie des tokens

```
✅ JWT : expiration courte (15min access, 7j refresh)
✅ Sessions : durée limitée avec renouvellement automatique
✅ API Keys : rotation planifiée, révocation immédiate si compromis
✅ Webhooks : toujours vérifier la signature (HMAC-SHA256)
```

---

## 3. GIT — Configuration & Hygiène

### 3.1 .gitignore obligatoire (à vérifier et compléter)

```gitignore
# === SECRETS & ENV ===
.env
.env.*
!.env.example
*.pem
*.key
*.p12
*.pfx
secrets/
credentials/

# === DÉPENDANCES ===
node_modules/
.pnp
.pnp.js
vendor/
__pycache__/
*.pyc
.venv/
venv/

# === BUILD & OUTPUT ===
dist/
build/
.next/
.nuxt/
out/
.output/
.vercel/
.netlify/
*.tsbuildinfo

# === CACHE ===
.cache/
.parcel-cache/
.turbo/
.eslintcache
.stylelintcache
*.swc/

# === IDE & OS ===
.DS_Store
Thumbs.db
.idea/
.vscode/settings.json
*.suo
*.user
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# === TEST & COVERAGE ===
coverage/
.nyc_output/
playwright-report/
test-results/

# === DONNÉES LOCALES ===
*.sqlite
*.db
dump.sql
*.bak

# === MEDIA & UPLOADS LOCAUX ===
uploads/
public/uploads/
storage/

# === DOCKER ===
.docker/data/
postgres-data/
redis-data/
```

### 3.2 Avant chaque commit

```bash
# 1. Vérifier ce qui va être commité
git diff --staged

# 2. Scanner les secrets accidentels
git secrets --scan 2>/dev/null || gitleaks detect --staged 2>/dev/null

# 3. Lancer le lint
npm run lint --if-present || yarn lint --if-present

# 4. Vérifier les types
npm run typecheck --if-present || npx tsc --noEmit

# 5. Vérifier les tests
npm run test --if-present -- --passWithNoTests
```

### 3.3 Convention de commits (obligatoire)

```
feat(scope): description courte
fix(scope): correction du bug X
chore(scope): mise à jour dépendances
docs(scope): documentation de X
refactor(scope): refactoring sans changement de comportement
test(scope): ajout/modification de tests
perf(scope): optimisation de performance
security(scope): correction de faille de sécurité
```

---

## 4. DÉPENDANCES — Audit & Vulnérabilités

### 4.1 Audit systématique

```bash
# NPM / Node
npm audit --audit-level=moderate
npm outdated

# Yarn
yarn audit --level moderate

# PNPM
pnpm audit --audit-level moderate

# Python
pip-audit 2>/dev/null || safety check

# Ruby
bundle audit check --update
```

### 4.2 Classification des vulnérabilités critiques

| Niveau | Action |
|--------|--------|
| **CRITICAL** | ⛔ Bloquer immédiatement. Patcher ou remplacer avant toute PR |
| **HIGH** | 🔴 Traiter dans les 24h. Ouvrir une issue de sécurité |
| **MODERATE** | 🟠 Planifier le patch dans le sprint en cours |
| **LOW** | 🟡 À traiter dans les 2 semaines |

### 4.3 Dépendances à surveiller particulièrement (Node/JS)

```
⚠️  lodash < 4.17.21        → Prototype Pollution
⚠️  axios < 1.6.0           → SSRF, credential leaks
⚠️  jsonwebtoken < 9.0.0    → Algorithm confusion attacks
⚠️  bcrypt (versions old)   → Timing attacks
⚠️  multer (sans validation) → Path traversal
⚠️  express < 4.19.2        → Open Redirect
⚠️  next < 14.1.1           → SSRF, Path traversal
⚠️  serialize-javascript    → XSS
⚠️  node-fetch < 3.x        → Request Smuggling
⚠️  sharp (versions old)    → Memory corruption
```

### 4.4 Vérification de la version Node

```bash
# Lire .nvmrc ou .node-version ou engines dans package.json
cat .nvmrc 2>/dev/null
cat .node-version 2>/dev/null
node -e "const p=require('./package.json'); console.log('Required:', p.engines?.node || 'non défini', '| Actuel:', process.version)"

# Versions LTS recommandées (2024-2025)
# Node 20 LTS (Maintenance) → fin avril 2026
# Node 22 LTS (Active) → recommandé
# Node 18 → EOL — MIGRER IMMÉDIATEMENT
```

### 4.5 Règles de gestion des dépendances

```
✅ Toujours épingler les versions majeures (^1.2.3 acceptable, * interdit)
✅ Séparer dependencies / devDependencies strictement
✅ Préférer des packages maintenus activement (dernière release < 6 mois)
✅ Vérifier le nombre de mainteneurs et les downloads hebdomadaires
✅ Éviter les packages avec 0 tests ou 0 documentation
✅ Auditer les packages avec accès au filesystem ou réseau
🚫 Ne jamais installer un package non vérifié directement en production
🚫 Éviter les packages avec des dépendances transitives non auditées
```

---

## 5. ARCHITECTURE — Clean & Multiservices

### 5.1 Séparation obligatoire des couches

```
📁 Présentation     → components/, pages/, views/, screens/
                      (Uniquement UI, zéro logique métier)

📁 Logique métier   → services/, use-cases/, domain/, lib/
                      (Indépendant du framework et de l'UI)

📁 Accès données    → repositories/, data/, prisma/, models/
                      (Toutes les interactions DB/API externes ici)

📁 Infrastructure   → config/, providers/, adapters/
                      (Configuration, injection de dépendances)
```

### 5.2 Règles Clean Architecture

```
✅ Les composants UI ne font JAMAIS d'appels DB directs
✅ Les services ne connaissent pas les détails d'implémentation DB
✅ Les repositories sont interchangeables (testables avec des mocks)
✅ Les use-cases contiennent la logique, pas les controllers
✅ Dépendances uniquement vers l'intérieur (UI → Services → Domain)
🚫 Pas d'imports circulaires
🚫 Pas de logique métier dans les composants React
🚫 Pas de SQL brut dans les routes API
```

### 5.3 Audit des intégrations externes

```
□ Chaque service externe a-t-il un timeout configuré ?
□ Les retry policies sont-elles définies (exponentiel backoff) ?
□ Les circuit breakers sont-ils en place pour les services critiques ?
□ Les webhooks sont-ils sécurisés par signature ?
□ Les SDK externes sont-ils initialisés une seule fois (singleton) ?
□ Les erreurs des services externes sont-elles loggées et tracées ?
```

### 5.4 Tolérance aux pannes

```typescript
// ✅ Pattern obligatoire pour les appels réseau
async function fetchWithRetry<T>(
  fn: () => Promise<T>,
  retries = 3,
  delay = 1000
): Promise<T> {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === retries) throw error;
      await new Promise(r => setTimeout(r, delay * Math.pow(2, attempt - 1)));
    }
  }
  throw new Error('Max retries reached');
}

// ✅ Timeout obligatoire sur tous les appels réseau
const controller = new AbortController();
const timeoutId = setTimeout(() => controller.abort(), 5000);
try {
  const res = await fetch(url, { signal: controller.signal });
} finally {
  clearTimeout(timeoutId);
}
```

---

## 6. QUALITÉ CODE — Lint, Types & Tests

### 6.1 Séquence obligatoire avant tout ajout de code

```bash
# ÉTAPE 1 — Identifier ce qui existe déjà
find src/ -name "*.tsx" -o -name "*.ts" | grep -E "(route|page|hook|component|service)" | sort

# ÉTAPE 2 — Vérifier les routes existantes
cat src/app/router.tsx 2>/dev/null || \
cat src/routes/index.ts 2>/dev/null || \
find . -name "routes*" -not -path "*/node_modules/*"

# ÉTAPE 3 — Lister les hooks existants
find src/ -name "use*.ts" -o -name "use*.tsx" | grep -v node_modules

# ÉTAPE 4 — Lister les composants existants
find src/ -name "*.tsx" -not -path "*/node_modules/*" | head -50

# ÉTAPE 5 — TypeCheck AVANT d'ajouter du code
npx tsc --noEmit 2>&1 | head -50

# ÉTAPE 6 — Lint AVANT d'ajouter du code
npm run lint 2>&1 | head -50
```

### 6.2 TypeScript — Configuration stricte obligatoire

```json
// tsconfig.json — Paramètres minimum requis
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "exactOptionalPropertyTypes": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": false
  }
}
```

### 6.3 Séquence obligatoire après ajout de code

```bash
# 1. TypeCheck
npx tsc --noEmit

# 2. Lint avec autofix
npm run lint -- --fix

# 3. Format
npx prettier --write "src/**/*.{ts,tsx,js,jsx}"

# 4. Tests unitaires
npm run test -- --passWithNoTests

# 5. Git diff pour valider le travail effectué
git diff --stat
git diff
```

### 6.4 Règles de typage fort

```typescript
// 🚫 INTERDIT
const data: any = response.json();
function process(input: any) { ... }

// ✅ OBLIGATOIRE
interface ApiResponse<T> {
  data: T;
  error: string | null;
  status: number;
}

// ✅ Zod pour la validation runtime des données externes
import { z } from 'zod';
const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  role: z.enum(['admin', 'user', 'guest']),
});
type User = z.infer<typeof UserSchema>;

// ✅ Validation obligatoire des inputs de formulaires et API
const validatedData = UserSchema.parse(rawInput); // throw si invalide
```

---

## 7. PERFORMANCE — Assets, Streaming, CDN

### 7.1 Optimisation des assets

```
✅ Images : utiliser next/image ou équivalent (lazy loading, WebP auto)
✅ Fonts : précharger (preload) les fonts critiques, font-display: swap
✅ CSS : Critical CSS inliné, reste en async
✅ JS : Code splitting par route, dynamic imports pour les bundles lourds
✅ SVG : Inline pour les icônes critiques, sprite pour les sets d'icônes
✅ Videos : lazy load, poster image, preload="none" par défaut
✅ Compression : Brotli > gzip sur le serveur
✅ Headers Cache-Control : immutable pour assets versionnés, no-store pour données sensibles
```

### 7.2 Streaming & Hydratation progressive

```tsx
// ✅ Next.js App Router — Streaming obligatoire
import { Suspense } from 'react';

export default function Page() {
  return (
    <>
      {/* Contenu critique immédiat */}
      <HeroSection />

      {/* Contenu secondaire en streaming */}
      <Suspense fallback={<ProductListSkeleton />}>
        <ProductList />
      </Suspense>

      <Suspense fallback={<RecommendationsSkeleton />}>
        <Recommendations />
      </Suspense>
    </>
  );
}

// ✅ Skeleton obligatoire pour tout contenu asynchrone
function ProductListSkeleton() {
  return (
    <div className="animate-pulse grid grid-cols-3 gap-4">
      {Array.from({ length: 6 }).map((_, i) => (
        <div key={i} className="bg-gray-200 h-48 rounded-lg" />
      ))}
    </div>
  );
}
```

### 7.3 CDN & SLO

```
✅ Utiliser un CDN (Cloudflare, CloudFront, Fastly) pour les assets statiques
✅ Définir les SLO : P95 < 200ms pour les pages critiques
✅ Configurer un slow log DB : requêtes > 100ms → alerter
✅ Mettre en place des métriques (Core Web Vitals) : LCP, CLS, INP
✅ Bundle size budget : JS initial < 200KB gzip
✅ Time to First Byte (TTFB) < 200ms
```

### 7.4 Lazy Loading React

```tsx
// ✅ Toujours lazy loader les pages et composants lourds
const HeavyChart = lazy(() => import('./components/HeavyChart'));
const AdminPanel = lazy(() => import('./pages/AdminPanel'));

// ✅ Avec Suspense boundary
<Suspense fallback={<ChartSkeleton />}>
  <HeavyChart data={data} />
</Suspense>
```

---

## 8. BASE DE DONNÉES — Optimisation & Sécurité

### 8.1 Index obligatoires

```sql
-- ✅ Index sur toutes les colonnes utilisées en WHERE, JOIN, ORDER BY
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);

-- ✅ Covering index pour éviter les lookups de table
CREATE INDEX idx_orders_covering
  ON orders(user_id, status)
  INCLUDE (total_amount, created_at);

-- ✅ Index partiel pour les requêtes fréquentes sur sous-ensembles
CREATE INDEX idx_active_users ON users(email)
  WHERE deleted_at IS NULL AND is_active = true;

-- ✅ Index composite (ordre des colonnes = ordre des filtres les plus sélectifs)
CREATE INDEX idx_audit_logs ON audit_logs(tenant_id, user_id, created_at DESC);
```

### 8.2 Connection Pooling obligatoire

```typescript
// ✅ Prisma avec pool
const prisma = new PrismaClient({
  datasources: {
    db: {
      url: `${process.env.DATABASE_URL}?connection_limit=10&pool_timeout=20`,
    },
  },
});

// ✅ PgBouncer en mode transaction (recommandé pour Serverless)
// DATABASE_URL=postgres://user:pass@pgbouncer:5432/db?pgbouncer=true

// ✅ Singleton pattern — UNE seule instance Prisma
declare global {
  var prisma: PrismaClient | undefined;
}
export const db = globalThis.prisma ?? new PrismaClient();
if (process.env.NODE_ENV !== 'production') globalThis.prisma = db;
```

### 8.3 Tuning PostgreSQL (PGTune)

```sql
-- Configuration recommandée (à adapter selon RAM disponible)
-- Serveur 8GB RAM, SSD, 2 CPU

shared_buffers = 2GB            -- 25% de la RAM
effective_cache_size = 6GB      -- 75% de la RAM
work_mem = 64MB                 -- RAM / (max_connections * 2)
maintenance_work_mem = 512MB    -- 6.25% de la RAM
wal_buffers = 64MB
max_connections = 100
checkpoint_completion_target = 0.9
random_page_cost = 1.1          -- SSD → valeur proche de 1
effective_io_concurrency = 200  -- SSD

-- Slow query log (requêtes > 100ms)
log_min_duration_statement = 100  -- en millisecondes
log_statement = 'none'
log_destination = 'csvlog'
```

### 8.4 Requêtes optimisées

```typescript
// 🚫 INTERDIT — N+1 query
const users = await db.user.findMany();
for (const user of users) {
  const orders = await db.order.findMany({ where: { userId: user.id } });
}

// ✅ OBLIGATOIRE — Include / JOIN
const usersWithOrders = await db.user.findMany({
  include: {
    orders: {
      select: { id: true, total: true, createdAt: true },
      where: { status: 'completed' },
      take: 10,
      orderBy: { createdAt: 'desc' },
    },
  },
  where: { isActive: true },
  take: 50,
});

// ✅ Pagination par curseur (performante pour grandes tables)
const page = await db.order.findMany({
  take: 20,
  cursor: lastOrderId ? { id: lastOrderId } : undefined,
  skip: lastOrderId ? 1 : 0,
  orderBy: { createdAt: 'desc' },
});
```

---

## 9. SÉCURITÉ APPLICATIVE — Auth, API, Formulaires

### 9.1 Authentification & Sessions

```
✅ Sessions côté SERVEUR uniquement (jamais en cookie base64 modifiable)
✅ HttpOnly + Secure + SameSite=Lax sur tous les cookies de session
✅ CSRF protection sur tous les endpoints mutants (POST/PUT/DELETE/PATCH)
✅ Rate limiting sur les endpoints d'auth (login, register, reset-password)
✅ Lockout après N tentatives échouées (ex: 5 tentatives → 15min de blocage)
✅ MFA disponible pour les comptes admin/sensibles
✅ Refresh token rotation (invalider l'ancien à chaque refresh)
✅ Logout = invalidation serveur du token/session (pas juste suppression cookie)

🚫 JAMAIS stocker l'état de session dans un cookie base64 non signé
🚫 JAMAIS faire confiance aux données côté client pour les autorisations
🚫 JAMAIS JWT sans vérification de la signature côté serveur
```

### 9.2 Protection des endpoints API

```typescript
// ✅ Pattern middleware de sécurité obligatoire
export async function middleware(req: NextRequest) {
  // 1. Auth check
  const session = await getSession(req);
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  // 2. RBAC check
  if (!hasPermission(session.user.role, req.nextUrl.pathname)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  // 3. Rate limiting
  const rateLimit = await checkRateLimit(session.user.id);
  if (!rateLimit.success) {
    return NextResponse.json(
      { error: 'Too Many Requests' },
      { status: 429, headers: { 'Retry-After': String(rateLimit.reset) } }
    );
  }

  return NextResponse.next();
}
```

### 9.3 Validation et Sanitization

```typescript
// ✅ Validation OBLIGATOIRE de toutes les entrées utilisateur
import { z } from 'zod';
import DOMPurify from 'isomorphic-dompurify';

const ContactFormSchema = z.object({
  name: z.string().min(2).max(100).trim(),
  email: z.string().email().toLowerCase().trim(),
  message: z.string().min(10).max(5000).trim(),
});

// ✅ Sanitization du HTML si on accepte du rich text
const cleanHtml = DOMPurify.sanitize(userInput, {
  ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p'],
  ALLOWED_ATTR: ['href'],
});

// ✅ Protection SQL Injection — TOUJOURS utiliser un ORM ou paramètres préparés
// 🚫 db.query(`SELECT * FROM users WHERE email = '${email}'`)  // INTERDIT
// ✅ db.user.findUnique({ where: { email } })                  // Prisma paramétré
```

### 9.4 Headers de sécurité obligatoires

```typescript
// next.config.ts
const securityHeaders = [
  { key: 'X-DNS-Prefetch-Control', value: 'on' },
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      "script-src 'self' 'nonce-{nonce}'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https:",
      "font-src 'self'",
      "connect-src 'self' https://api.yourdomain.com",
    ].join('; '),
  },
];
```

### 9.5 Chiffrement des données sensibles

```typescript
// ✅ Chiffrement AES-256-GCM pour les données PII en base de données
import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const KEY = Buffer.from(process.env.ENCRYPTION_KEY!, 'hex'); // 32 bytes

function encrypt(text: string): { encrypted: string; iv: string; tag: string } {
  const iv = randomBytes(16);
  const cipher = createCipheriv(ALGORITHM, KEY, iv);
  const encrypted = Buffer.concat([cipher.update(text, 'utf8'), cipher.final()]);
  return {
    encrypted: encrypted.toString('hex'),
    iv: iv.toString('hex'),
    tag: cipher.getAuthTag().toString('hex'),
  };
}
```

---

## 10. FRONTEND REACT — Async, State, Composants

### 10.1 Priorité à l'asynchrone

```tsx
// ✅ React Query / TanStack Query — gestion état serveur
const { data, isLoading, error } = useQuery({
  queryKey: ['users', filters],
  queryFn: () => fetchUsers(filters),
  staleTime: 5 * 60 * 1000, // 5 minutes
  retry: 2,
  onError: (error) => toast.error('Erreur lors du chargement'),
});

// ✅ Suspense + Error Boundary obligatoires autour des données asynchrones
<ErrorBoundary fallback={<ErrorFallback />}>
  <Suspense fallback={<Skeleton />}>
    <AsyncComponent />
  </Suspense>
</ErrorBoundary>
```

### 10.2 State Management

```tsx
// ✅ Zustand pour l'état global UI
// ✅ React Query / SWR pour l'état serveur
// ✅ useState local pour l'état de composant
// ✅ useReducer pour la logique d'état complexe
// ✅ Context uniquement pour les données peu fréquemment mises à jour (theme, auth)

// 🚫 Ne PAS mettre l'état serveur dans Zustand/Redux
// 🚫 Ne PAS prop-drill à plus de 2 niveaux → utiliser Context ou state manager
// 🚫 Ne PAS synchroniser manuellement l'état serveur et client

// ✅ Zustand pattern recommandé
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface UIStore {
  sidebarOpen: boolean;
  toggleSidebar: () => void;
}

export const useUIStore = create<UIStore>()(
  persist(
    (set) => ({
      sidebarOpen: true,
      toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
    }),
    { name: 'ui-preferences' }
  )
);
```

### 10.3 Réutilisabilité et séparation des responsabilités

```
✅ Composants < 200 lignes (sinon diviser)
✅ Un composant = une responsabilité
✅ Props typées avec TypeScript (jamais any)
✅ Hooks custom pour toute logique partageable
✅ Barrel exports (index.ts) par domaine fonctionnel
✅ Storybook ou équivalent pour documenter les composants

🚫 Ne pas dupliquer la logique → extraire dans un hook
🚫 Ne pas mélanger UI et logique métier dans un même composant
🚫 Ne pas créer de composants génériques trop tôt (YAGNI)
```

### 10.4 Prévention des memory leaks

```tsx
// ✅ Cleanup dans useEffect
useEffect(() => {
  const subscription = eventEmitter.subscribe(handler);
  const interval = setInterval(tick, 1000);

  return () => {
    subscription.unsubscribe();   // cleanup subscription
    clearInterval(interval);       // cleanup interval
  };
}, []);

// ✅ AbortController pour les fetch dans useEffect
useEffect(() => {
  const controller = new AbortController();

  fetch('/api/data', { signal: controller.signal })
    .then(res => res.json())
    .then(setData)
    .catch(err => {
      if (err.name !== 'AbortError') setError(err);
    });

  return () => controller.abort();
}, [id]);

// ✅ isMounted pattern pour les setStates async
useEffect(() => {
  let isMounted = true;
  asyncOperation().then(data => {
    if (isMounted) setState(data);
  });
  return () => { isMounted = false; };
}, []);
```

---

## 11. ANTIPATTERNS — À éviter absolument

### 11.1 Sécurité

```
🚫 eval() ou Function() avec données utilisateur
🚫 innerHTML avec données non sanitisées (→ XSS)
🚫 dangerouslySetInnerHTML sans DOMPurify
🚫 Requêtes SQL concaténées (→ SQLi)
🚫 path.join() avec input utilisateur non validé (→ Path Traversal)
🚫 deserialize() de données non fiables (→ RCE)
🚫 process.env affiché dans les logs
🚫 Cookies sans HttpOnly et Secure
🚫 CORS wildcard (*) en production
🚫 JWT Algorithm "none"
🚫 Stockage de mots de passe en MD5/SHA1 (→ utiliser bcrypt/argon2)
```

### 11.2 Performance

```
🚫 Imports * (→ tree-shaking impossible)
🚫 useEffect sans dépendances sur des données asynchrones
🚫 Render conditionnel avec && sur des nombres (→ {count > 0 && ...})
🚫 Re-renders inutiles (oublier React.memo, useMemo, useCallback)
🚫 Chargement de librairies entières (→ import { pick } from 'lodash/pick')
🚫 setTimeout/setInterval sans clearTimeout/clearInterval
🚫 Requêtes DB dans des boucles (→ N+1 problem)
🚫 SELECT * (→ toujours spécifier les colonnes)
🚫 Absence d'index sur les colonnes de jointure et filtre
```

### 11.3 Code Quality

```
🚫 Magic numbers (→ extraire en constante nommée)
🚫 Fonctions > 50 lignes (→ décomposer)
🚫 Commentaires "quoi" (→ commenter le "pourquoi")
🚫 Dead code non supprimé
🚫 Console.log en production
🚫 TODO/FIXME sans ticket associé
🚫 Mutation directe de props ou state
🚫 Catch vide (→ toujours logger ou gérer l'erreur)
🚫 Promises non gérées (→ toujours .catch() ou try/catch)
🚫 Conditional chaining sans fallback sur des données critiques
```

### 11.4 Dettes techniques connues (CopyFail & autres)

```
🚫 Versionning d'API absent (→ /api/v1/, /api/v2/)
🚫 Pas de monitoring en production (→ Sentry, Datadog, OpenTelemetry)
🚫 Migrations DB irréversibles sans backup préalable
🚫 Déploiement sans tests de smoke automatiques
🚫 Absence de documentation des ADR (Architecture Decision Records)
🚫 Features flags absents pour les fonctionnalités risquées
🚫 Pas de health check endpoint (/api/health)
🚫 Logs non structurés (→ utiliser JSON logs avec niveaux)
🚫 Absence de graceful shutdown sur le serveur Node
```

---

## 12. WORKFLOW — Avant / Pendant / Après le code

### 12.1 AVANT de coder une nouvelle feature

```bash
# 1. Lire et analyser les specs
# 2. Vérifier ce qui existe déjà
grep -r "NomFeature" src/ --include="*.ts" --include="*.tsx"

# 3. Inventorier les composants, hooks, services réutilisables
# 4. Identifier les impacts sur l'architecture existante
# 5. TypeCheck initial (zéro erreur avant de commencer)
npx tsc --noEmit

# 6. Lint initial
npm run lint

# 7. Vérifier qu'on est sur la bonne branche
git branch --show-current
git status
```

### 12.2 PENDANT le codage

```bash
# ✅ TypeCheck continu (à chaque nouveau fichier/composant)
npx tsc --noEmit

# ✅ Lint continu
npm run lint

# ✅ Tests au fur et à mesure
npm run test -- --watch

# ✅ Vérifier les imports et dépendances circulaires
npx madge --circular src/

# ✅ Valider les schemas de données au plus tôt
```

### 12.3 APRÈS avoir codé

```bash
# 1. TypeCheck final
npx tsc --noEmit

# 2. Lint + Fix
npm run lint -- --fix

# 3. Tests complets
npm run test

# 4. Build de vérification
npm run build

# 5. Audit sécurité
npm audit --audit-level=moderate

# 6. Git diff pour valider le travail
git diff --stat
git diff

# 7. Documenter dans /docs/
# 8. Commit conventionnel
git add .
git commit -m "feat(scope): description de ce qui a été fait"
```

---

## 13. DOCUMENTATION — Traçabilité des tâches

### 13.1 Structure obligatoire du dossier /docs

```
/docs
├── ARCHITECTURE.md          ← Schéma global, décisions techniques (ADR)
├── API.md                   ← Endpoints, paramètres, exemples
├── SETUP.md                 ← Installation, variables d'env, prérequis
├── CHANGELOG.md             ← Historique des changements
├── SECURITY.md              ← Politique de sécurité, contacts
├── tasks/
│   ├── YYYY-MM-DD-task-name.md  ← Une fiche par tâche complétée
│   └── ...
└── adr/
    ├── 001-choix-orm.md         ← Architecture Decision Records
    └── ...
```

### 13.2 Template de fiche de tâche (/docs/tasks/)

```markdown
# Tâche : [NOM DE LA TÂCHE]
**Date** : YYYY-MM-DD
**Auteur** : Agent / Développeur
**Branche** : feature/nom-feature
**Status** : ✅ Complété

## Objectif
Description courte de ce qui devait être fait.

## Ce qui a été fait
- [ ] Élément 1 → ✅ Fichier créé : src/components/X.tsx
- [ ] Élément 2 → ✅ Hook ajouté : src/hooks/useX.ts
- [ ] Élément 3 → ✅ Tests ajoutés : src/tests/X.test.ts

## Fichiers modifiés
- src/components/X.tsx (créé)
- src/hooks/useX.ts (créé)
- src/app/api/route.ts (modifié)

## Tests
- TypeCheck : ✅ npx tsc --noEmit → 0 erreur
- Lint : ✅ npm run lint → 0 warning
- Tests : ✅ npm run test → X/X passed
- Build : ✅ npm run build → success

## Notes et décisions
Pourquoi telle ou telle approche a été choisie.

## Prochaines étapes suggérées
Ce qui reste à faire ou améliorer.
```

### 13.3 Validation par git diff

```bash
# Après chaque tâche — prouver ce qui a été fait
git diff --stat HEAD~1 HEAD
git diff HEAD~1 HEAD -- src/

# Format de sortie attendu dans la fiche de tâche :
# M src/components/Dashboard.tsx     (+45 -12)
# A src/hooks/useDashboard.ts        (+87)
# M src/app/api/dashboard/route.ts   (+23 -5)
```

---

## 14. SKILLS — Routes obligatoires vers les agents

> Ces skills doivent être appelés dans les situations décrites. Les routes sont à configurer dans CLAUDE.md / GEMINI.md / AGENTS.md.

### 14.1 Démarrage de session

```
🔧 Au démarrage de CHAQUE session → Appeler : /gstack
   Objectif : Détecter le stack technologique complet du projet
```

### 14.2 Planification

```
🧠 Avant de coder une nouvelle feature ou résoudre un problème complexe
   → Appeler : brainstorming (superpowers)
   Objectif : Explorer les approches, peser les trade-offs, choisir la meilleure voie
```

### 14.3 Audit de code

```
🔍 Après avoir écrit ou modifié du code significatif
   → Appeler : code reviewer
   Objectif : Détecter les failles, antipatterns, optimisations manquées
```

### 14.4 Configuration dans CLAUDE.md / AGENTS.md

```markdown
## Skills disponibles

| Situation | Skill à appeler | Déclencheur |
|-----------|----------------|-------------|
| Init session | `/gstack` | Toujours au démarrage |
| Planification feature | `brainstorming` | Avant d'écrire du code |
| Review code | `code reviewer` | Après chaque tâche |
| Architecture | `brainstorming` | Avant toute décision d'architecture |
| Debug complexe | `code reviewer` | Sur bugs non triviaux |

## Routes des skills
- gstack        → [PATH_TO_GSTACK_SKILL]
- brainstorming → [PATH_TO_BRAINSTORMING_SKILL]
- code-reviewer → [PATH_TO_CODE_REVIEWER_SKILL]
```

---


Voici **le fichier `rules.md`** contenant **uniquement la partie que nous avons travaillée dans cette session**, c’est‑à‑dire **l’intégration obligatoire de SonarQube, SonarScanner, Quality Gates et l’analyse de sécurité à chaque build**.

Je me base sur ton document existant et j’ajoute une nouvelle section **14.5 — SonarQube & Quality Gates** dans le même style, en respectant la structure et le ton du fichier d’origine.

---

# 📘 **rules.md — Ajout de la section SonarQube & Quality Gates**

```markdown
# 14.5 — SonarQube & Quality Gates (OBLIGATOIRE À CHAQUE BUILD)

> Cette section complète les règles existantes et définit les obligations de sécurité, qualité et analyse statique via SonarQube.  
> Elle doit être appliquée **à chaque build**, **à chaque commit**, **à chaque pipeline CI/CD**, sans exception.

---

## 🎯 Objectifs

- Garantir une **qualité logicielle parfaite** en continu  
- Empêcher tout build si la qualité ne respecte pas les standards  
- Détecter automatiquement :  
  - 🔐 Vulnérabilités  
  - 🛡️ Security Hotspots  
  - 🐛 Bugs  
  - 🧹 Code Smells  
  - 📉 Baisse de couverture  
  - 🔁 Duplications  
- Générer des rapports systématiques pour l’agent et les développeurs

---

## 🚀 1. Démarrage obligatoire de SonarQube

Avant toute analyse :

- Vérifier que SonarQube répond sur :  
  `http://localhost:9000/api/system/status`
- Si le statut ≠ `UP`, démarrer via :

```
C:\payara\bin\windows-x86-64\StartSonar.bat
```

- Attendre que l’instance soit opérationnelle avant de lancer le scanner.

---

## 📁 2. Fichier `sonar-project.properties` obligatoire

Le projet doit contenir :

```
sonar.projectKey=MonProjet
sonar.projectName=MonProjet
sonar.sources=src
sonar.tests=tests
sonar.java.binaries=target/classes
sonar.host.url=http://localhost:9000
sonar.login=admin
sonar.password=admin
```

Sans ce fichier → **build bloqué**.

---

## 🚦 3. Quality Gates — Règles strictes

Le Quality Gate par défaut doit imposer :

| Critère | Niveau requis |
|--------|----------------|
| Security Rating | A |
| Reliability Rating | A |
| Maintainability Rating | A |
| Coverage | ≥ 80% |
| Duplications | ≤ 3% |
| Vulnérabilités | 0 |
| Bugs critiques | 0 |

Si le Quality Gate **FAIL** → **le build échoue automatiquement**.

---

## 🧪 4. Analyse obligatoire à chaque build

### Maven

```
mvn clean verify sonar:sonar \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=admin
```

### Scanner CLI

```
sonar-scanner -Dproject.settings=sonar-project.properties
```

Aucune PR ne peut être mergée sans analyse SonarQube valide.

---

## 📊 5. Récupération automatique des rapports

L’agent doit systématiquement consulter :

- Issues :  
  `http://localhost:9000/api/issues/search?projectKeys=MonProjet`

- Quality Gate :  
  `http://localhost:9000/api/qualitygates/project_status?projectKey=MonProjet`

Les rapports doivent être intégrés dans le workflow de validation.

---

## 🤖 6. Workflow obligatoire pour l’agent

À **chaque build**, l’agent doit exécuter :

1. Vérifier que SonarQube est UP  
2. Démarrer Sonar si nécessaire  
3. Vérifier la présence du fichier `sonar-project.properties`  
4. Lancer le scanner  
5. Récupérer les rapports  
6. Vérifier le Quality Gate  
7. Bloquer le build si FAIL  
8. Autoriser le pipeline si PASS  

Ce workflow est **non négociable**.

---

## 🔐 7. Analyse de sécurité obligatoire

L’agent doit vérifier :

- Security  
- Security Review  
- OWASP Top 10  
- Vulnerabilities  
- Hotspots  
- Leaks  
- Duplications  
- Coverage  
- Maintainability  
- Reliability  

Aucune faille ne doit être ignorée.

---

## 🛑 8. Conditions de blocage immédiat

Le build est bloqué si :

- Une vulnérabilité est détectée  
- Un Security Hotspot critique apparaît  
- Le coverage baisse sous le seuil  
- Le Quality Gate échoue  
- Le scanner n’a pas été exécuté  
- SonarQube n’a pas répondu  

---

## 📌 9. Intégration CI/CD obligatoire

Chaque pipeline doit inclure :

- Lancement de SonarQube (si local)  
- Exécution du scanner  
- Vérification du Quality Gate  
- Blocage automatique en cas d’échec  

Aucune exception.

---

## ✅ CHECKLIST FINALE — À valider avant toute PR / merge

```
SÉCURITÉ
□ Aucun secret hardcodé ou commité
□ .gitignore à jour
□ Variables d'env validées au démarrage
□ Toutes les entrées utilisateur validées et sanitisées
□ Authentification et autorisation vérifiées sur tous les nouveaux endpoints
□ Sessions stockées côté serveur
□ Headers de sécurité configurés

QUALITÉ CODE
□ npx tsc --noEmit → 0 erreur
□ npm run lint → 0 erreur
□ Pas de console.log en production
□ Pas de any TypeScript
□ Gestion d'erreurs sur tous les appels réseau
□ Cleanup dans tous les useEffect
□ La qualité logicielle doit être parfaite
□ L’agent doit vérifier en temps réel, à chaque build, que le code respecte les standards SonarQube


PERFORMANCE
□ Lazy loading sur les pages et composants lourds
□ Skeleton UI sur les contenus asynchrones
□ Pas de N+1 query
□ Index DB sur les nouvelles colonnes de filtre/jointure

DOCUMENTATION
□ Fiche de tâche créée dans /docs/tasks/
□ git diff validant le travail effectué
□ Commit conventionnel réalisé
□ CHANGELOG.md mis à jour si changement notable

SKILLS
□ /gstack appelé en début de session
□ brainstorming appelé si feature complexe
□ code reviewer appelé après le code
```

---

> **Ce fichier est vivant.** Mets-le à jour dès qu'une nouvelle faille, antipattern ou bonne pratique est identifiée dans le projet.
> **Version** : 1.0.0 | **Dernière mise à jour** : 2026
