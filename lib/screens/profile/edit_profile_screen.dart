import 'package:aricie/services/profile_preferences.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Édition du profil utilisateur.
///
/// - Email : lecture seule (identifiant de connexion, non modifiable ici).
/// - Nom d'affichage : éditable. Persisté localement pour l'instant (voir
///   [ProfilePreferences]) en attendant la colonne BDD.
///
/// Renvoie `true` via `Navigator.pop` si le profil a été modifié, afin que
/// l'écran appelant puisse se rafraîchir.
class EditProfileScreen extends StatefulWidget {
  final String email;

  const EditProfileScreen({super.key, required this.email});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _profilePrefs = ProfilePreferences();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final name = await _profilePrefs.getDisplayName();
    if (!mounted) return;
    setState(() {
      _nameController.text = name ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    await _profilePrefs.setDisplayName(_nameController.text);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil mis à jour.')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le profil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s6),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email (lecture seule)
                        TextFormField(
                          initialValue: widget.email,
                          readOnly: true,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            helperText:
                                'L\'email est votre identifiant de connexion '
                                'et ne peut pas être modifié ici.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s5),

                        // Nom d'affichage (éditable)
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Nom d\'affichage',
                            hintText: 'Ex. Lance N.',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          validator: (value) {
                            if (value != null && value.trim().length > 40) {
                              return '40 caractères maximum';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        Text(
                          'Le nom d\'affichage est enregistré sur cet appareil '
                          'pour le moment ; il sera synchronisé à votre compte '
                          'prochainement.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                        const SizedBox(height: AppSpacing.s6),

                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Enregistrer'),
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
