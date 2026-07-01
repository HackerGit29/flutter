import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/usecases/auth/get_current_user.dart';
import 'package:aricie/domain/usecases/auth/logout_user.dart';
import 'package:aricie/providers/subscription_provider.dart';
import 'package:aricie/services/profile_service.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../admin/admin_dashboard_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_preferences_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  String? _displayName;
  bool _isLoading = true;
  String? _error;

  final _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    final name = await _profileService.getDisplayName();
    if (!mounted) return;
    setState(() => _displayName = name);
  }

  Future<void> _loadUser() async {
    final result = await GetCurrentUser(sl()).call();
    result.fold(
      (failure) {
        if (!mounted) return;
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (user) {
        if (!mounted) return;
        setState(() {
          _user = user;
          _error = null;
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
              SizedBox(height: AppSpacing.s3),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.s4),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadUser();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(AppSpacing.s4),
      children: [
        CircleAvatar(
          radius: 50,
          child: Text(
            (_displayName?.isNotEmpty == true
                    ? _displayName!
                    : _user?.email ?? 'U')
                .substring(0, 1)
                .toUpperCase(),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        SizedBox(height: AppSpacing.s6),
        Text(
          _displayName?.isNotEmpty == true
              ? _displayName!
              : _user?.email ?? 'Utilisateur',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        if (_displayName?.isNotEmpty == true) ...[
          SizedBox(height: AppSpacing.s1),
          Text(
            _user?.email ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
            textAlign: TextAlign.center,
          ),
        ],
        SizedBox(height: AppSpacing.s8),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Modifier le profil'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final email = _user?.email;
            if (email == null) return;
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => EditProfileScreen(email: email),
              ),
            );
            if (changed == true) {
              _loadDisplayName();
            }
          },
        ),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Changer le mot de passe'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
          ),
        ),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Préférences de notification'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NotificationPreferencesScreen(),
            ),
          ),
        ),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        if (_user?.isAdmin == true) ...[
          ListTile(
            leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
            title: const Text('Administration', style: TextStyle(color: Colors.orange)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
            ),
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
        ],
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Déconnexion'),
          onTap: () async {
            if (!mounted) return;
            context.read<SubscriptionProvider>().reset();
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
    );
  }
}
