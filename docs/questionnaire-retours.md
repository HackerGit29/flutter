# Questionnaire de retour utilisateur — Aricie (séance de démonstration ETSIA)

> **Objectif** : recueillir les retours des participants après qu'ils aient **testé eux-mêmes** l'application Aricie lors de la séance de démonstration.
>
> **Contexte technique** : les tests se font sur **les appareils du groupe**, avec un **profil de démonstration partagé**. Un même appareil est passé de main en main. Le questionnaire doit donc :
> - **accepter plusieurs réponses** (plusieurs testeurs remplissent depuis le même appareil / profil) ;
> - **identifier chaque répondant** dans le formulaire lui-même (section A), puisque l'application ne peut pas distinguer les testeurs.
>
> **Accès** : bouton **« Donner un avis »** dans l'écran *Réglages* de l'application (ouvre ce formulaire). Un QR code identique peut être affiché sur la diapositive finale de la présentation, en secours.

---

## Comment l'utiliser

1. Créer un **Google Form** (ou Microsoft Forms) et y recopier les questions ci-dessous.
2. Appliquer le **paramétrage recommandé** (section « Paramétrage Google Forms »).
3. Copier le **lien du formulaire** et le coller dans l'application :
   `lib/screens/settings/settings_screen.dart` → constante `_feedbackFormUrl`.
4. (Optionnel) Générer un **QR code** du même lien (voir annexe) pour la diapositive finale.

---

## Structure du questionnaire

### Section A — Identification du répondant *(obligatoire)*

| # | Question | Type Google Forms | Options / précisions |
|---|----------|-------------------|----------------------|
| A1 | Votre prénom ou pseudo | Réponse courte | Sert à dédoublonner les réponses (profil partagé) |
| A2 | Quel est votre profil ? | Choix multiples (unique) | Client potentiel · Partenaire · Enseignant-expert · Étudiant · Autre |
| A3 | Utilisez-vous déjà une application de suivi de consommation d'énergie ? | Choix multiples (unique) | Oui, régulièrement · Occasionnellement · Jamais |

### Section B — Impression générale

| # | Question | Type | Options |
|---|----------|------|---------|
| B1 | Note globale de l'application | Échelle linéaire | 1 (Très mauvaise) → 5 (Excellente) |
| B2 | En un mot, votre première impression | Réponse courte | — |

### Section C — Ergonomie et clarté des interfaces
*Échelle d'accord 1 → 5 (1 = Pas du tout d'accord, 5 = Tout à fait d'accord). Type conseillé : **grille à choix multiples** (une ligne par affirmation, colonnes 1 à 5).*

- C1. L'application est agréable et moderne visuellement.
- C2. La navigation est intuitive (je trouve facilement ce que je cherche).
- C3. Les écrans et les informations affichées sont clairs et compréhensibles.
- C4. J'ai pu accomplir les actions souhaitées sans aide extérieure.

### Section D — Pertinence des fonctionnalités

| # | Question | Type | Options |
|---|----------|------|---------|
| D1 | Quelles fonctionnalités avez-vous testées ? | Cases à cocher | Suivi de consommation en temps réel · Statistiques et historique · Contrôle des appareils (allumer/éteindre) · Assistant IA (chatbot) · Conseils d'économie d'énergie · Notifications |
| D2 | Utilité de chaque fonctionnalité testée | Grille à choix multiples | Lignes = les 6 fonctionnalités ci-dessus ; Colonnes = 1 (Inutile) → 5 (Très utile) · Non testée |
| D3 | Quelle fonctionnalité vous a le plus séduit ? | Choix multiples (unique) | Mêmes 6 fonctionnalités |

### Section E — Performance perçue
*Échelle d'accord 1 → 5 (grille à choix multiples conseillée).*

- E1. L'application réagit rapidement à mes actions.
- E2. Les données (consommation, graphiques) s'affichent sans attente notable.
- E3. Je n'ai rencontré aucun ralentissement ni blocage.

### Section F — Confiance et sécurité perçues
*Échelle d'accord 1 → 5.*

- F1. L'application m'inspire confiance quant à la protection de mes données.
- F2. Les mécanismes de connexion / déconnexion me paraissent sûrs.

### Section G — Retours ouverts *(le cœur qualitatif)*

| # | Question | Type |
|---|----------|------|
| G1 | Quels sont, selon vous, les **points positifs** ? | Paragraphe |
| G2 | Quels **problèmes, bugs ou points de confusion** avez-vous rencontrés ? | Paragraphe |
| G3 | Quelles **améliorations ou fonctionnalités** souhaiteriez-vous ? | Paragraphe |

### Section H — Recommandation

| # | Question | Type | Options |
|---|----------|------|---------|
| H1 | Recommanderiez-vous Aricie à un proche ou un collègue ? | Échelle linéaire | 0 (Pas du tout) → 10 (Tout à fait) — *indicateur NPS* |
| H2 | Souhaitez-vous être recontacté ? Si oui, votre e-mail (facultatif) | Réponse courte | Laisser vide sinon |

---

## Paramétrage Google Forms recommandé

- **Réponses → Accepter les réponses** : activé pendant la séance.
- **Paramètres → Réponses** :
  - *Collecter les adresses e-mail* : **Non** (l'e-mail est demandé en H2 uniquement si le répondant le souhaite).
  - *Limiter à 1 réponse* : **Non** (⚠️ indispensable — plusieurs testeurs sur le même appareil/profil).
  - *Modifier après l'envoi* : Non.
- **Présentation** :
  - *Afficher la barre de progression* : activé.
  - *Mélanger l'ordre des questions* : non.
  - **Message de confirmation** : « Merci pour votre retour ! Vous pouvez rendre l'appareil au groupe pour le testeur suivant. »
- **Réponses → Lier à Google Sheets** : activé → export automatique pour la **synthèse des retours** (tâche 4).

---

## Exploitation pour la synthèse (tâche 4)

Le questionnaire est conçu pour alimenter directement la synthèse :

- **Quantitatif** : moyenne de B1 (note globale), moyennes des grilles C/E/F, taux d'usage par fonctionnalité (D1), utilité moyenne (D2), **NPS** calculé depuis H1 (% promoteurs 9–10 − % détracteurs 0–6).
- **Qualitatif** : regroupement thématique des réponses G1 (points positifs), G2 (problèmes rencontrés), G3 (suggestions), à prioriser dans la version révisée de la solution.

---

## Annexe — Génération du QR code (optionnel)

Une fois l'URL du formulaire connue, générer un QR code (par ex. avec `qrencode`) :

```bash
# macOS : brew install qrencode
qrencode -o docs/qr_feedback.png -s 10 "https://docs.google.com/forms/d/e/1FAIpQLScrLheoHHWJMnSyPWituMwEv8JOzURaxYXRtdenPH-TxA4u5A/viewform"
```

Le PNG peut être inséré dans la diapositive finale de la présentation. Il n'est **pas** indispensable puisque l'accès principal se fait via le bouton *« Donner un avis »* de l'application.
