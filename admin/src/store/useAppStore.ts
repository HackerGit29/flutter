import { create } from 'zustand';
import type { AdminLevel, AdminSession } from '../types/admin';
import type { AnalysisPeriod, Currency, Language } from '../types';

/**
 * État d'interface du backoffice.
 *
 * Ce store ne contient **que** de l'état d'UI et la session :
 *  - les données métier viennent de `admin-api` via TanStack Query ;
 *  - le mode clair/sombre est la propriété de MUI (`useColorScheme`), pour
 *    qu'il n'existe qu'une seule source de vérité.
 *
 * L'ancien store portait tout le jeu de données mock en mémoire, ce qui
 * masquait les appels réseau manquants. C'est ce qui est corrigé ici.
 */

export const XAF_PER_EUR = 655.957;
export const VIP_MONTHLY_PRICE_EUR = 29.9;

interface AppState {
  /* Langue ---------------------------------------------------------- */
  language: Language;
  setLanguage: (lang: Language) => void;
  toggleLanguage: () => void;

  /* Devise ---------------------------------------------------------- */
  currency: Currency;
  setCurrency: (currency: Currency) => void;
  /** Formate un montant exprimé en euros dans la devise courante. */
  formatCurrency: (amountInEur: number) => string;

  /* Période d'analyse ---------------------------------------------- */
  period: AnalysisPeriod;
  setPeriod: (period: AnalysisPeriod) => void;

  /* Navigation / recherche ----------------------------------------- */
  searchQuery: string;
  setSearchQuery: (query: string) => void;
  isMobileMenuOpen: boolean;
  setIsMobileMenuOpen: (open: boolean) => void;

  /* Entités sélectionnées (tiroirs de détail) ---------------------- */
  selectedBoxId: string | null;
  setSelectedBoxId: (id: string | null) => void;
  selectedUserId: string | null;
  setSelectedUserId: (id: string | null) => void;

  /* Session -------------------------------------------------------- */
  session: AdminSession | null;
  setSession: (session: AdminSession | null) => void;
  clearSession: () => void;
  /** Niveau du compte connecté, `null` si déconnecté. */
  adminLevel: () => AdminLevel | null;
}

const formatNumber = (value: number, fractionDigits: number) =>
  new Intl.NumberFormat('fr-FR', {
    minimumFractionDigits: fractionDigits,
    maximumFractionDigits: fractionDigits,
  }).format(value);

export const useAppStore = create<AppState>((set, get) => ({
  language: 'fr',
  setLanguage: (language) => set({ language }),
  toggleLanguage: () => set((state) => ({ language: state.language === 'fr' ? 'en' : 'fr' })),

  // Devise de l'application : le XAF. Les montants backend sont exprimés en
  // euros (VIP_MONTHLY_PRICE_EUR) mais l'UI affiche toujours le XAF par défaut,
  // converti à la parité fixe BEAC (1 EUR = 655,957 XAF).
  currency: 'XAF',
  setCurrency: (currency) => set({ currency }),
  formatCurrency: (amountInEur) => {
    const currency = get().currency;
    if (currency === 'XAF') {
      // Parité fixe BEAC : 1 EUR = 655,957 XAF.
      return `${formatNumber(Math.round(amountInEur * XAF_PER_EUR), 0)} XAF`;
    }
    if (currency === 'USD') {
      return `$${formatNumber(amountInEur, 2)}`;
    }
    return `${formatNumber(amountInEur, 2)} €`;
  },

  period: 'month',
  setPeriod: (period) => set({ period }),

  searchQuery: '',
  setSearchQuery: (searchQuery) => set({ searchQuery }),
  isMobileMenuOpen: false,
  setIsMobileMenuOpen: (isMobileMenuOpen) => set({ isMobileMenuOpen }),

  selectedBoxId: null,
  setSelectedBoxId: (selectedBoxId) => set({ selectedBoxId }),
  selectedUserId: null,
  setSelectedUserId: (selectedUserId) => set({ selectedUserId }),

  session: null,
  setSession: (session) => set({ session }),
  clearSession: () => set({ session: null }),
  adminLevel: () => get().session?.level ?? null,
}));

/**
 * Masquage d'email pour les viewers (RGPD, cf. cahier des charges §10.4).
 *
 * Reproduit le masquage dynamique côté présentation : `sophie.martin@example.fr`
 * → `s***n@ex***.fr`. Le backend renvoie l'email complet aux `operator` et
 * `super_admin` ; c'est `admin-api` qui décide, cette fonction ne fait que
 * refléter la règle pour les comptes à accès limité.
 */
export const maskEmail = (email: string, level: AdminLevel | null): string => {
  if (level && level !== 'viewer') return email;

  const parts = email.split('@');
  if (parts.length !== 2) return '***@***';

  const [name, domain] = parts;
  const domainParts = domain.split('.');
  const domainName = domainParts[0];
  const tld = domainParts.slice(1).join('.');

  const maskedName = name.length <= 2 ? `${name[0]}*` : `${name[0]}***${name[name.length - 1]}`;
  const maskedDomain = domainName.length <= 2 ? `${domainName[0]}*` : `${domainName.substring(0, 2)}***`;

  return `${maskedName}@${maskedDomain}.${tld}`;
};

/** Applique `maskEmail` uniquement si le niveau est `viewer`. */
export const useMaskedEmail = () => {
  const level = useAppStore((s) => s.session?.level ?? null);
  return (email: string | null | undefined) => (email ? maskEmail(email, level) : '—');
};
