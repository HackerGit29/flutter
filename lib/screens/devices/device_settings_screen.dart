import 'package:flutter/material.dart';

class DeviceSettingsScreen extends StatelessWidget {
  const DeviceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres des appareils'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Ajouter un appareil'),
            onTap: () {
              // TODO: Implement add device
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.room_outlined),
            title: const Text('Gérer les pièces'),
            onTap: () {
              // TODO: Implement room management
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications des appareils'),
            onTap: () {
              // TODO: Implement device notifications
            },
          ),
        ],
      ),
    );
  }
}