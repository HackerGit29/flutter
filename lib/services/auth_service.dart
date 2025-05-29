import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home_screen.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  final _supabase = Supabase.instance.client;
  
  // Clés pour SharedPreferences
  static const String _sessionKey = 'user_session';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  
  factory AuthService() {
    return _instance;
  }
  
  AuthService._internal();
  
  // Vérifier si l'utilisateur est connecté
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSession = prefs.getBool(_sessionKey) ?? false;
    
    // Vérifier également si la session Supabase est toujours valide
    final currentUser = _supabase.auth.currentUser;
    
    return hasSession && currentUser != null;
  }
  
  // Sauvegarder les informations de session après connexion
  Future<void> saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, true);
    await prefs.setString(_userIdKey, user.id);
    await prefs.setString(_userEmailKey, user.email ?? '');
  }
  
  // Effacer les informations de session lors de la déconnexion
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, false);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
  }
  
  // Récupérer l'email de l'utilisateur connecté
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }
  
  // Déconnexion complète
  Future<void> signOut(BuildContext context) async {
    await _supabase.auth.signOut();
    await clearSession();
    
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}