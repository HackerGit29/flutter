import 'package:supabase_flutter/supabase_flutter.dart';

/// Gestion du "nom d'affichage" de l'utilisateur.
///
/// Le nom est stocké dans les **métadonnées du compte Supabase Auth**
/// (`user_metadata.display_name`) : synchronisé au compte (donc à tous les
/// appareils), sans colonne dédiée dans la table `users` ni migration BDD.
/// L'email reste l'identifiant de connexion (non modifiable ici).
class ProfileService {
  static const String _displayNameKey = 'display_name';

  SupabaseClient get _client => Supabase.instance.client;

  /// Renvoie le nom d'affichage du compte, ou `null` s'il n'en a pas défini.
  Future<String?> getDisplayName() async {
    final value = _client.auth.currentUser?.userMetadata?[_displayNameKey];
    final name = value is String ? value.trim() : '';
    return name.isEmpty ? null : name;
  }

  /// Enregistre le nom d'affichage dans les métadonnées du compte.
  Future<void> setDisplayName(String name) async {
    await _client.auth.updateUser(
      UserAttributes(data: {_displayNameKey: name.trim()}),
    );
  }
}
