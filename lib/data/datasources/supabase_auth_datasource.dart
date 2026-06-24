import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthDataSource {
  final SupabaseClient _client;

  SupabaseAuthDataSource(this._client);

  Future<Map<String, dynamic>> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(email: email, password: password);
    if (response.user == null) throw Exception('Authentication failed');
    try {
      final userData = await _client.from('users').select().eq('id', response.user!.id).single();
      return userData;
    } catch (e) {
      // Create missing public.users record if it doesn't exist
      final newUser = {
        'id': response.user!.id,
        'email': response.user!.email ?? email,
        'role': 'user',
        'status': 'active',
      };
      await _client.from('users').insert(newUser);
      return newUser;
    }
  }

  Future<Map<String, dynamic>> signUp(String email, String password) async {
    final response = await _client.auth.signUp(email: email, password: password);
    if (response.user == null) throw Exception('Registration failed');
    final newUser = {
      'id': response.user!.id,
      'email': response.user!.email ?? email,
      'role': 'user',
      'status': 'active',
    };
    try {
      await _client.from('users').insert(newUser);
    } catch (_) {
      // Ignore if it already exists
    }
    try {
      final userData = await _client.from('users').select().eq('id', response.user!.id).single();
      return userData;
    } catch (e) {
      return newUser;
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final data = await _client.from('users').select().eq('id', user.id).single();
    return data;
  }

  Future<String> refreshToken() async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('No session');
    final refreshed = await _client.auth.setSession(session.accessToken);
    return refreshed.session!.accessToken;
  }
}
