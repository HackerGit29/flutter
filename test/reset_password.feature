Feature: Réinitialisation du mot de passe

  Background:
    Given the reset password screen is open

  Scenario: Un code de vérification vide affiche une erreur
    When I tap {'Réinitialiser le mot de passe'} text
    Then I see {'Veuillez entrer le code reçu'} text

  Scenario: Un code trop court affiche une erreur
    When I enter {'123'} into {0} input field
    And I tap {'Réinitialiser le mot de passe'} text
    Then I see {'Le code doit comporter 6 chiffres'} text

  Scenario: Un mot de passe vide affiche une erreur
    When I enter {'123456'} into {0} input field
    And I tap {'Réinitialiser le mot de passe'} text
    Then I see {'Veuillez entrer un mot de passe'} text

  Scenario: Un mot de passe trop court affiche une erreur
    When I enter {'123456'} into {0} input field
    And I enter {'abc'} into {1} input field
    And I tap {'Réinitialiser le mot de passe'} text
    Then I see {'Au moins 6 caractères'} text

  Scenario: Une confirmation différente affiche une erreur
    When I enter {'123456'} into {0} input field
    And I enter {'motdepasse'} into {1} input field
    And I enter {'different'} into {2} input field
    And I tap {'Réinitialiser le mot de passe'} text
    Then I see {'Les mots de passe ne correspondent pas'} text
