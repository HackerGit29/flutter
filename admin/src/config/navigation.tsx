import React from 'react';
import HomeRoundedIcon from '@mui/icons-material/HomeRounded';
import MapRoundedIcon from '@mui/icons-material/MapRounded';
import RouterRoundedIcon from '@mui/icons-material/RouterRounded';
import PeopleAltOutlinedIcon from '@mui/icons-material/PeopleAltOutlined';
import ReceiptLongOutlinedIcon from '@mui/icons-material/ReceiptLongOutlined';
import PsychologyOutlinedIcon from '@mui/icons-material/PsychologyOutlined';
import FileDownloadOutlinedIcon from '@mui/icons-material/FileDownloadOutlined';
import SupportAgentRoundedIcon from '@mui/icons-material/SupportAgentRounded';
import SecurityRoundedIcon from '@mui/icons-material/SecurityRounded';
import SettingsOutlinedIcon from '@mui/icons-material/SettingsOutlined';

import type { AdminLevel } from '../types/admin';

export interface NavItem {
  path: string;
  label: string;
  hint: string;
  icon: React.ReactNode;
  /**
   * Niveau RBAC minimal pour voir l'entrée.
   * `viewer` = lecture pour tous ; `super_admin` = journal d'audit complet.
   */
  minLevel: AdminLevel;
  /** Référence à la section du cahier des charges, pour la traçabilité. */
  spec: string;
}

const icon = (node: React.ReactNode) => node;

/**
 * Navigation unique du backoffice.
 *
 * Source de vérité partagée par la barre latérale (desktop) et le tiroir
 * mobile, pour qu'un ajout de page n'ait jamais à être dupliqué. L'ordre suit
 * le parcours de pilotage du cahier des charges §6 : vue d'ensemble →
 * géomarketing → parc → clients → revenus → produit → exploitation.
 */
export const NAV_ITEMS: NavItem[] = [
  {
    path: '/',
    label: 'Tableau de bord',
    hint: 'KPI décisionnels et santé de la plateforme',
    icon: icon(<HomeRoundedIcon sx={{ fontSize: 21 }} />),
    minLevel: 'viewer',
    spec: '§6.1',
  },
  {
    path: '/coverage',
    label: 'Carte & couverture',
    hint: 'Géomarketing, clusters et heatmap énergie',
    icon: icon(<MapRoundedIcon sx={{ fontSize: 21 }} />),
    minLevel: 'viewer',
    spec: '§6.2 · §6.3',
  },
  {
    path: '/boxes',
    label: 'Parc IoT',
    hint: 'Boîtiers, télémétrie et monitoring des commandes',
    icon: icon(<RouterRoundedIcon sx={{ fontSize: 21 }} />),
    minLevel: 'viewer',
    spec: '§6.5',
  },
  {
    path: '/users',
    label: 'Clients',
    hint: 'Fiches 360°, énergie et historique',
    icon: icon(<PeopleAltOutlinedIcon sx={{ fontSize: 21 }} />),
    minLevel: 'viewer',
    spec: '§6.4',
  },
  {
    path: '/subscriptions',
    label: 'Abonnements',
    hint: 'VIP, renouvellements, churn et licences',
    icon: icon(<ReceiptLongOutlinedIcon sx={{ fontSize: 21 }} />),
    minLevel: 'viewer',
    spec: '§5.3.9 · §6.9',
  },
  {
    path: '/agent',
    label: 'Agent IA',
    hint: 'Usage des outils, confirmations, blocages',
    icon: icon(<PsychologyOutlinedIcon sx={{ fontSize: 21 }} />),
    minLevel: 'viewer',
    spec: '§6.6',
  },
  {
    path: '/exports',
    label: 'Exports',
    hint: 'Extractions CSV/XLSX et rapports',
    icon: icon(<FileDownloadOutlinedIcon sx={{ fontSize: 21 }} />),
    minLevel: 'operator',
    spec: '§6.7',
  },
  {
    path: '/support',
    label: 'Support',
    hint: 'Notes internes et tickets client',
    icon: icon(<SupportAgentRoundedIcon sx={{ fontSize: 21 }} />),
    minLevel: 'operator',
    spec: '§6.8',
  },
  {
    path: '/audit',
    label: 'Audit & conformité',
    hint: "Journal des actions admin et RGPD",
    icon: icon(<SecurityRoundedIcon sx={{ fontSize: 20 }} />),
    minLevel: 'super_admin',
    spec: '§7',
  },
];

/** Entrées épinglées en bas de la barre latérale. */
export const BOTTOM_NAV_ITEMS: NavItem[] = [
  {
    path: '/settings',
    label: 'Paramètres',
    hint: 'Compte, devise, RBAC et intégrations',
    icon: icon(<SettingsOutlinedIcon sx={{ fontSize: 20 }} />),
    minLevel: 'viewer',
    spec: '§7',
  },
];
