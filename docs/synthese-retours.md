# Synthèse des retours utilisateurs — Aricie

> Document à compléter **après la séance de démonstration**. Il exploite les
> réponses du questionnaire (voir `questionnaire-retours.md`) collectées via le
> Google Form. Les valeurs entre crochets `[…]` et le bloc « Exemple » sont à
> remplacer par les données réelles.

## 1. Méthode de collecte

- **Contexte** : séance de démonstration où les participants testent eux-mêmes
  l'application sur les appareils du groupe (profil de démo partagé).
- **Outil** : questionnaire Google Forms, accessible via le bouton
  « Donner un avis » (Réglages) et par QR code.
- **Période** : `[date(s) de la séance]`
- **Participants** : `[nombre]` répondants — profils : `[clients potentiels,
  enseignants-experts, étudiants, …]`
- **Nature des retours** : quantitatifs (échelles, notes) et qualitatifs
  (questions ouvertes).

## 2. Indicateurs quantitatifs

| Indicateur | Source (question) | Valeur | Formule / calcul |
|-----------|-------------------|--------|------------------|
| Note globale moyenne (/5) | B1 | `[…]` | `=MOYENNE(B:B)` |
| Ergonomie & clarté (/5) | C1–C4 | `[…]` | moyenne des 4 affirmations |
| Performance perçue (/5) | E1–E3 | `[…]` | moyenne des 3 affirmations |
| Confiance / sécurité (/5) | F1–F2 | `[…]` | moyenne des 2 affirmations |
| Fonctionnalité la plus testée | D1 | `[…]` | % de répondants l'ayant cochée |
| Fonctionnalité la plus appréciée | D3 | `[…]` | mode (choix majoritaire) |
| **NPS** (−100 à +100) | H1 | `[…]` | `% promoteurs (9–10) − % détracteurs (0–6)` |

## 3. Synthèse qualitative

Regrouper les réponses ouvertes (G1/G2/G3) par **thème**, en comptant les
récurrences (un point cité plusieurs fois est prioritaire).

### Points positifs (G1)
- `[thème 1 — nombre de mentions]`
- `[thème 2 — …]`

### Problèmes rencontrés (G2)
- `[problème 1 — nombre de mentions — gravité]`
- `[problème 2 — …]`

### Suggestions d'amélioration (G3)
- `[suggestion 1 — nombre de mentions]`
- `[suggestion 2 — …]`

## 4. Priorisation des améliorations

Croiser **fréquence** (nombre de mentions) et **impact** (gêne / valeur ajoutée)
pour décider quoi corriger dans la version révisée.

| Amélioration | Fréquence | Impact | Décision | Justification |
|--------------|-----------|--------|----------|---------------|
| `[…]` | `[élevée/moyenne/faible]` | `[élevé/moyen/faible]` | `[retenue / reportée / écartée]` | `[…]` |

## 5. Conclusion

`[Synthèse en quelques lignes : niveau de satisfaction global, forces
principales, axes d'amélioration prioritaires retenus et intégrés à la version
suivante.]`

---

## Exemple illustratif (à remplacer par les données réelles)

> ⚠️ Données fictives, uniquement pour montrer le format attendu.

**Participants** : 8 répondants (5 étudiants, 2 enseignants-experts, 1 partenaire).

| Indicateur | Valeur (exemple) |
|-----------|------------------|
| Note globale moyenne | 4,1 / 5 |
| Ergonomie & clarté | 4,3 / 5 |
| Performance perçue | 3,6 / 5 |
| Confiance / sécurité | 3,9 / 5 |
| Fonctionnalité la plus testée | Suivi de consommation en temps réel (88 %) |
| Fonctionnalité la plus appréciée | Assistant IA |
| NPS | +38 |

**Points positifs** : interface moderne et claire (6), suivi temps réel
convaincant (5), assistant IA apprécié (4).

**Problèmes rencontrés** : léger délai d'affichage des graphiques (3),
vocabulaire technique par endroits (2).

**Suggestions** : mode hors-ligne (3), export des données de consommation (2).

**Priorisation** : correction du délai d'affichage → *retenue* (fréquence
moyenne, impact élevé sur la perception de performance) ; export des données →
*reportée* (valeur réelle mais hors périmètre de la V2).
