import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/usecases/auth/logout_user.dart';
import 'package:aricie/domain/usecases/auth/get_current_user.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../admin/admin_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final result = await GetCurrentUser(sl()).call();
    result.fold(
      (_) {},
      (user) {
        if (user != null) {
          setState(() => _user = user);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.s4),
        children: [
          CircleAvatar(
            radius: 50,
            child: Text(
              _user?.email.substring(0, 1).toUpperCase() ?? 'U',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          SizedBox(height: AppSpacing.s6),
          Text(
            _user?.email ?? 'Utilisateur',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.s8),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Modifier le profil'),
            onTap: () {},
          ),
          Divider(color: AppColors.textMuted),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Préférences de notification'),
            onTap: () {},
          ),
          Divider(color: AppColors.textMuted),
          if (_user?.isAdmin == true) ...[
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
              title: const Text('Administration', style: TextStyle(color: Colors.orange)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
            ),
            Divider(color: AppColors.textMuted),
          ],
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Déconnexion'),
            onTap: () async {
              final result = await LogoutUser(sl()).call();
              result.fold(
                (_) {},
                (_) {
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
