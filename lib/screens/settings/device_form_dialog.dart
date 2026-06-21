import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/usecases/auth/get_current_user.dart';
import '../../models/device_model.dart';

class DeviceFormDialog extends StatefulWidget {
  final DeviceModel? device;
  final String? initialName;
  final String? initialLocation;

  const DeviceFormDialog({
    super.key,
    this.device,
    this.initialName,
    this.initialLocation,
  });

  @override
  State<DeviceFormDialog> createState() => _DeviceFormDialogState();
}

class _DeviceFormDialogState extends State<DeviceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with device data, or initialName/initialLocation if provided
    if (widget.device != null) {
      _nameController = TextEditingController(text: widget.device!.name);
      _locationController = TextEditingController(
        text: widget.device!.location,
      );
    } else {
      _nameController = TextEditingController(text: widget.initialName ?? '');
      _locationController = TextEditingController(
        text: widget.initialLocation ?? '',
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveDevice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userResult = await GetCurrentUser(sl()).call();
      final user = userResult.getOrElse(() => null);
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vous devez être connecté pour effectuer cette action',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final deviceData = {
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'user_id': user.id,
      };

      DeviceModel? savedDevice;

      if (widget.device == null) {
        final response =
            await Supabase.instance.client
                .from('devices')
                .insert(deviceData)
                .select()
                .single();

        savedDevice = DeviceModel.fromJson(response);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${savedDevice.name} ajouté avec succès')),
        );
      } else {
        final response =
            await Supabase.instance.client
                .from('devices')
                .update(deviceData)
                .eq('id', widget.device!.id)
                .select()
                .single();

        savedDevice = DeviceModel.fromJson(response);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${savedDevice.name} mis à jour avec succès')),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(savedDevice);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.device == null ? 'Ajouter un appareil' : 'Modifier l\'appareil',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'appareil',
                  hintText: 'Ex: Ventilateur, Télévision...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Emplacement',
                  hintText: 'Ex: Salon, Cuisine...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer un emplacement';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveDevice,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Text(widget.device == null ? 'Ajouter' : 'Mettre à jour'),
        ),
      ],
    );
  }
}
