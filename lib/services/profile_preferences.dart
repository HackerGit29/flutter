import 'package:shared_preferences/shared_preferences.dart';

/// Stockage du "nom d'affichage" de l'utilisateur.
///
/// STOPGAP : l'entité `User` / la table `users` n'ont pas encore de colonne
/// `name`. En attendant la migration BDD (coordination équipe Admin), le nom
/// d'affichage est persisté **localement** sur l'appareil. Quand la colonne
/// existera, remplacer cette persistance par un appel Supabase (datasource +
/// repository), l'écran et le use-case n'ayant pas à changer d'interface.
class ProfilePreferences {
  static const String _displayNameKey = 'profile_display_name';

  /// Renvoie le nom d'affichage, ou `null` si l'utilisateur n'en a pas défini.
  Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_displayNameKey)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> setDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_displayNameKey);
    } else {
      await prefs.setString(_displayNameKey, trimmed);
    }
  }
}
