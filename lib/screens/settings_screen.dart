import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Offline Map Navigation Feature
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.map, color: Colors.purple, size: 32),
                        const SizedBox(width: 16),
                        const Flexible(
                          child: Text(
                            'Offline Map Navigation',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Coming Soon',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Navigate anywhere without internet connection. Download maps for your region and get voice guided directions!',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 150,
                        color: Colors.grey[300],
                        child: Center(
                          child: Icon(
                            Icons.map_outlined,
                            size: 64,
                            color: Colors.purple.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: null, // Disabled button
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.withOpacity(0.6),
                        disabledBackgroundColor: Colors.purple.withOpacity(0.3),
                        disabledForegroundColor: Colors.white70,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications),
                          SizedBox(width: 8),
                          Text('Notify Me When Available'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Regular Settings
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'App Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ),
            ),
            _buildSettingTile(
              context,
              icon: Icons.record_voice_over,
              title: 'Voice Settings',
              subtitle: 'Adjust voice speed and volume',
            ),
            _buildSettingTile(
              context,
              icon: Icons.tune,
              title: 'Detection Sensitivity',
              subtitle: 'Adjust object detection sensitivity',
            ),
            _buildSettingTile(
              context,
              icon: Icons.color_lens,
              title: 'Theme',
              subtitle: 'Change app appearance',
            ),
            _buildSettingTile(
              context,
              icon: Icons.info,
              title: 'About',
              subtitle: 'App information and version',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.purple),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title settings coming soon'),
            backgroundColor: Colors.purple,
          ),
        );
      },
    );
  }
}
