import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthDataSource {
  final SupabaseClient _client;

  SupabaseAuthDataSource(this._client);

  Future<Map<String, dynamic>> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(email: email, password: password);

    final authUser = response.user;
    if (authUser == null) {
      throw Exception('Authentication failed');
    }

    final userData = await _client.from('users').select().eq('id', authUser.id).maybeSingle();
    if (userData != null) return userData;

    return _createUserProfile(authUser, email);
  }

  Future<Map<String, dynamic>> signUp(String email, String password) async {
    final response = await _client.auth.signUp(email: email, password: password);

    final authUser = response.user;
    if (authUser == null) {
      throw Exception('Registration failed');
    }

    try {
      return await _createUserProfile(authUser, email);
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;

      final userData = await _client.from('users').select().eq('id', authUser.id).maybeSingle();
      if (userData != null) return userData;

      throw Exception('User profile already exists but could not be loaded');
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final data = await _client.from('users').select().eq('id', user.id).maybeSingle();
    if (data == null) {
      throw Exception('User profile not found');
    }

    return data;
  }

  Future<String> refreshToken() async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('No session');
    final refreshed = await _client.auth.setSession(session.accessToken);
    return refreshed.session!.accessToken;
  }

  Future<Map<String, dynamic>> _createUserProfile(User authUser, String fallbackEmail) async {
    final newUser = {
      'id': authUser.id,
      'email': authUser.email ?? fallbackEmail,
      'role': 'user',
      'status': 'active',
    };

    return _client.from('users').insert(newUser).select().single();
  }
}
