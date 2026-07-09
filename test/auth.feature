Feature: Authentification

  Background:
    Given the app is running

  Scenario: Soumettre le formulaire de connexion vide affiche une erreur
    When I tap {'Se connecter'} text
    Then I see {'Veuillez entrer votre email'} text

  Scenario: Un email au format invalide affiche une erreur
    When I enter {'pas-un-email'} into {0} input field
    And I tap {'Se connecter'} text
    Then I see {'Veuillez entrer un email valide'} text

  Scenario: Un mot de passe manquant affiche une erreur
    When I enter {'utilisateur@exemple.com'} into {0} input field
    And I tap {'Se connecter'} text
    Then I see {'Veuillez entrer votre mot de passe'} text

  Scenario: Depuis le login, accéder à l'écran d'inscription
    When I tap {"S'inscrire"} text
    And I wait
    Then I see {'Créer un compte'} text

  Scenario: Ouvrir la fenêtre de mot de passe oublié
    When I tap {'Mot de passe oublié?'} text
    And I wait
    Then I see {'Envoyer'} text
