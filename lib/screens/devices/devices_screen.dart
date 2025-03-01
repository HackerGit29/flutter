import 'package:flutter/material.dart';
import 'device_settings_screen.dart';
import '../profile/profile_screen.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gestion des appareils',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DeviceSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_outline),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Device list
            Expanded(
              child: ListView(
                children: const [
                  DeviceCard(
                    name: 'Ventilateur',
                    location: 'Salon',
                    isActive: true,
                    consumption: '20W',
                    icon: Icons.air,
                  ),
                  SizedBox(height: 16),
                  DeviceCard(
                    name: 'Congélateur',
                    location: 'Cuisine',
                    isActive: true,
                    consumption: '80W',
                    icon: Icons.ac_unit,
                  ),
                  SizedBox(height: 16),
                  DeviceCard(
                    name: 'Télévision',
                    location: 'Salon',
                    isActive: false,
                    consumption: '0W',
                    icon: Icons.tv,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Device Card Widget
class DeviceCard extends StatelessWidget {
  final String name;
  final String location;
  final bool isActive;
  final String consumption;
  final IconData icon;

  const DeviceCard({
    super.key,
    required this.name,
    required this.location,
    required this.isActive,
    required this.consumption,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary.withAlpha(25)
                    : Theme.of(context).colorScheme.surface.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withAlpha(128),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    'Location: $location',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Consommation: $consumption',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(
              value: isActive,
              onChanged: (value) {
                // Implement device toggle with a callback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${value ? 'Activating' : 'Deactivating'} $name...'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}