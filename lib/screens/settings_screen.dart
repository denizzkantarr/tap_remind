import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _settingsBoxName = 'settings';
  static const String _soundKey = 'notification_sound';

  final List<String> _soundOptions = [
    'Varsayılan',
    'Yumuşak',
    'Yüksek',
    'Melodi 1',
    'Melodi 2',
  ];

  String _selectedSound = 'Varsayılan';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settingsBox = Hive.box(_settingsBoxName);
    setState(() {
      _selectedSound = settingsBox.get(_soundKey, defaultValue: 'Varsayılan');
    });
  }

  Future<void> _saveSoundSetting(String sound) async {
    final settingsBox = Hive.box(_settingsBoxName);
    await settingsBox.put(_soundKey, sound);
    setState(() {
      _selectedSound = sound;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ayarlar kaydedildi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Bildirim Ayarları',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('Bildirim Sesi'),
            subtitle: Text(_selectedSound),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Bildirim Sesi Seç'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _soundOptions.map((sound) {
                      return RadioListTile<String>(
                        title: Text(sound),
                        value: sound,
                        groupValue: _selectedSound,
                        onChanged: (value) {
                          if (value != null) {
                            _saveSoundSetting(value);
                            Navigator.pop(context);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Hakkında',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const ListTile(
            title: Text('Versiyon'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}

