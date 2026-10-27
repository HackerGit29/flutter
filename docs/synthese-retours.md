# Synthèse des retours utilisateurs — Aricie

> Synthèse établie à partir des réponses au questionnaire (voir
> `questionnaire-retours.md`) collectées via le Google Form pendant la séance de
> démonstration.

## 1. Méthode de collecte

- **Contexte** : séance de démonstration où les participants testent eux-mêmes
  l'application sur les appareils du groupe (profil de démonstration partagé).
- **Outil** : questionnaire Google Forms, accessible via le bouton
  « Donner un avis » (Réglages) et par QR code.
- **Période** : 9 juillet 2026.
- **Participants** : **12 répondants**, tous de profil *étudiant*. Concernant
  l'usage préalable d'une application de suivi de consommation : 9 n'en avaient
  jamais utilisé, 1 occasionnellement, 2 régulièrement.
- **Nature des retours** : quantitatifs (échelles, notes) et qualitatifs
  (questions ouvertes).

## 2. Indicateurs quantitatifs

| Indicateur | Source (question) | Valeur | Calcul |
|-----------|-------------------|--------|--------|
| Note globale moyenne (/5) | B1 | **4,42** | moyenne des 12 notes |
| Ergonomie & clarté (/5) | C1–C4 | **3,90** | moyenne des 4 affirmations |
| Performance perçue (/5) | E1–E3 | **3,44** | moyenne des 3 affirmations |
| Confiance / sécurité (/5) | F1–F2 | **3,67** | moyenne des 2 affirmations |
| Fonctionnalité la plus testée | D1 | **Suivi de consommation en temps réel (100 %)** | % de répondants l'ayant cochée |
| Fonctionnalité la plus appréciée | D3 | **Suivi de consommation en temps réel (6/12)** | choix majoritaire |
| **NPS** (−100 à +100) | H1 | **+42** | % promoteurs (9–10) − % détracteurs (0–6) |

**Détail par affirmation :**

- Ergonomie (C) : visuel moderne 3,75 · navigation intuitive 4,08 · écrans
  clairs 3,92 · actions sans aide 3,83.
- Performance (E) : réactivité 3,50 · affichage des données 3,17 · absence de
  ralentissement 3,67.
- Confiance (F) : protection des données 3,67 · connexion/déconnexion 3,67.

**Fonctionnalités testées (D1)** : Suivi temps réel 100 % · Assistant IA 92 % ·
Contrôle des appareils 83 % · Notifications 75 % · Statistiques et historique
67 % · Conseils d'économie 58 %.

**Recommandation (H1, base NPS)** : 7 promoteurs (58 %), 3 passifs (25 %),
2 détracteurs (17 %) → **NPS = +42**.

## 3. Synthèse qualitative

Les premières impressions (B2, en un mot) sont très majoritairement positives et
tournées vers l'innovation : « impressionnant », « innovante », « bien pensé »,
« original », « intuitive »…

### Points positifs (G1)
- **Suivi de la consommation en temps réel** — ~5 mentions (« traquer les gros
  consommateurs », « surveillance en temps réel », « le suivi des données »).
- **Assistant IA / chatbot** — 2 mentions (« assisté par l'IA pour des
  conseils », « le chatbot IA, on ne s'y attend pas »).
- **Qualité de conception** — 1 mention explicite (« respecte les 10
  heuristiques de Jakob Nielsen »).

### Problèmes rencontrés (G2)
- **Lenteur / latence d'affichage** — 2 mentions (« lente », « léger moment de
  latence pour les statistiques ») — gravité faible à moyenne.
- Aucun bug bloquant signalé : la majorité des répondants indiquent « aucun » /
  « RAS » / « rien constaté ».

### Suggestions d'amélioration (G3)
- **Lisibilité en thème sombre** — 1 mention, concrète (« le thème sombre rend
  certains textes illisibles, il faudrait revoir cela »).
- **Chatbot** — 1 mention (à préciser).
- Peu de demandes par ailleurs : plusieurs « RAS » / « déjà au top ».

## 4. Priorisation des améliorations

| Amélioration | Fréquence | Impact | Décision | Justification |
|--------------|-----------|--------|----------|---------------|
| Réduire la latence d'affichage (surtout statistiques/graphiques) | moyenne | élevé | **Retenue** | C'est l'indicateur le plus bas (E2 = 3,17) et le seul problème récurrent. Recoupe la correction déjà apportée à l'actualisation temps réel de l'accueil. |
| Améliorer la lisibilité des textes en thème sombre | faible | moyen | **Retenue** | Problème d'accessibilité concret, correctif simple et à forte valeur perçue. |
| Retour sur le chatbot | faible | à évaluer | **Reportée** | Mention isolée et ambiguë : à clarifier avant tout arbitrage. |

## 5. Conclusion

Le niveau de satisfaction est **élevé** : note globale de **4,42/5** et **NPS de
+42**, avec des premières impressions largement enthousiastes. Les deux forces
qui ressortent nettement sont le **suivi de consommation en temps réel** (testé
par tous, fonctionnalité préférée) et l'**assistant IA** (testé par 92 % des
répondants, souvent cité comme un élément différenciant inattendu).

L'axe d'amélioration prioritaire est la **performance perçue à l'affichage**
(dimension la moins bien notée, seul problème réellement récurrent) ; il est
retenu pour la version suivante, en cohérence avec l'optimisation déjà engagée
sur l'actualisation temps réel de l'écran d'accueil. La **lisibilité en thème
sombre** est également retenue comme correctif rapide.

**Limite de l'étude** : l'échantillon (12 répondants) est homogène — uniquement
des étudiants. Les retours reflètent donc surtout la perception de ce public ;
un panel élargi (clients potentiels, enseignants-experts, partenaires)
consoliderait ces conclusions.
