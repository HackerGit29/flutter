import React from 'react';
import { Chip } from '@mui/material';

/**
 * Statut affichable, tous domaines confondus.
 *
 * Une seule table de correspondance pour tout le backoffice évite que chaque
 * page invente ses propres couleurs de statut — l'incohérence la plus visible
 * dans un tableau de bord.
 */
export type StatusTone = 'success' | 'warning' | 'error' | 'info' | 'neutral' | 'accent';

/** Traduit un statut métier en tonalité de la palette. */
const TONE_BY_STATUS: Record<string, StatusTone> = {
  // Utilisateurs
  active: 'success',
  suspended: 'error',
  // Abonnements
  past_due: 'warning',
  canceled: 'neutral',
  // Boîtiers
  online: 'success',
  offline_alert: 'error',
  maintenance: 'warning',
  offline: 'neutral',
  blocked: 'error',
  inactive: 'neutral',
  // Commandes device
  pending: 'info',
  sent: 'info',
  delivered: 'info',
  acknowledged: 'success',
  failed: 'error',
  rejected: 'error',
  timeout: 'warning',
  // Tickets support
  open: 'info',
  in_progress: 'warning',
  resolved: 'success',
  // Audit / agent
  allowed: 'success',
  blocked_policy: 'error',
};

/** Libellés français affichés pour chaque statut connu. */
const LABEL_BY_STATUS: Record<string, string> = {
  active: 'Actif',
  suspended: 'Suspendu',
  past_due: 'Impayé',
  canceled: 'Résilié',
  online: 'En ligne',
  offline_alert: 'Hors ligne',
  maintenance: 'Maintenance',
  offline: 'Hors ligne',
  blocked: 'Bloqué',
  inactive: 'Inactif',
  pending: 'En attente',
  sent: 'Envoyée',
  delivered: 'Livrée',
  acknowledged: 'Acquittée',
  failed: 'Échouée',
  rejected: 'Rejetée',
  timeout: 'Expirée',
  open: 'Ouvert',
  in_progress: 'En cours',
  resolved: 'Résolu',
  allowed: 'Autorisé',
  blocked_policy: 'Bloqué (politique)',
};

/** Teinte de fond et de texte par tonalité. */
const TONE_STYLES: Record<StatusTone, { bg: string; color: string }> = {
  success: { bg: 'rgba(78, 154, 106, 0.14)', color: 'success.main' },
  warning: { bg: 'rgba(245, 200, 66, 0.16)', color: 'warning.dark' },
  error: { bg: 'rgba(232, 80, 106, 0.14)', color: 'error.main' },
  info: { bg: 'rgba(121, 207, 244, 0.18)', color: 'info.dark' },
  accent: { bg: 'rgba(200, 168, 216, 0.18)', color: 'secondary.dark' },
  neutral: { bg: 'action.hover', color: 'text.secondary' },
};

interface StatusChipProps {
  /** Statut brut venant de la base (`active`, `offline_alert`…). */
  status: string;
  /** Force une tonalité au lieu de la déduire du statut. */
  tone?: StatusTone;
  /** Remplace le libellé déduit. */
  label?: string;
  size?: 'small' | 'medium';
}

export const StatusChip: React.FC<StatusChipProps> = ({ status, tone, label, size = 'small' }) => {
  const resolvedTone = tone ?? TONE_BY_STATUS[status] ?? 'neutral';
  const style = TONE_STYLES[resolvedTone];
  const text = label ?? LABEL_BY_STATUS[status] ?? status;

  return (
    <Chip
      label={text}
      size={size}
      sx={{ backgroundColor: style.bg, color: style.color, fontWeight: 600 }}
    />
  );
};

export default StatusChip;
