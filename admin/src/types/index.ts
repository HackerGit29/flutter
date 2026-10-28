/**
 * Types d'interface du backoffice.
 *
 * Les contrats de données (utilisateurs, boîtiers, géo, KPI…) vivent dans
 * `./admin`. Ce fichier ne contient que ce qui relève de l'UI : langue,
 * devise, période d'analyse.
 */

export type Language = 'fr' | 'en';

export type Currency = 'XAF' | 'EUR' | 'USD';

/** Période d'analyse partagée par les écrans de pilotage. */
export type AnalysisPeriod = 'day' | 'week' | 'month' | 'quarter';

/** Options de période, avec leur libellé français. */
export const ANALYSIS_PERIODS: { value: AnalysisPeriod; label: string }[] = [
  { value: 'day', label: "Aujourd'hui" },
  { value: 'week', label: '7 derniers jours' },
  { value: 'month', label: '30 derniers jours' },
  { value: 'quarter', label: 'Trimestre en cours' },
];

export * from './admin';
