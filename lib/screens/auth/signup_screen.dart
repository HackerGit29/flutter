import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home_screen.dart';
import 'login_screen.dart'; // Importer la page de connexion

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _passwordStrength = '';
  Color _strengthColor = Colors.grey;
  double _strengthValue = 0.0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Implement Supabase authentication
        final supabase = Supabase.instance.client;
        final AuthResponse response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {'full_name': _nameController.text.trim()},
        );

        // Navigate to home screen on successful authentication
        if (response.user != null && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } on AuthException catch (e) {
        // Handle Supabase auth-specific exceptions
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur d\'inscription: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _navigateToLogin() {
    // Naviguer vers la page de connexion
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                   Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Titre de la page
                  const Text(
                    'Créer un compte',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Inscrivez-vous pour accéder à toutes les fonctionnalités',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Full Name
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Email Address
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Password
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    ],
                  ),
                  
                  // Password strength indicator
                  if (_passwordStrength.isNotEmpty) ...[
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Sign Up Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      elevation: 4,
                      shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'S\'inscrire',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Already have an account
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Vous avez déjà un compte?',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                        ),
                      ),
                      TextButton(
                        onPressed: _navigateToLogin,
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Se connecter'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Copyright
                  Column(
                    children: [
                      Text(
                        'Copyright ${DateTime.now().year} Aricie ©',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF4F46E5),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Politique de confidentialité'),
                          ),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF4F46E5),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Conditions d\'utilisation'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}