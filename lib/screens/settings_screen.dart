import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _settingsBoxName = 'settings';
  static const String _soundKey = 'notification_sound';
  static const String _languageKey = 'language';

  final List<String> _soundOptions = [
    'Varsayılan',
    'Yumuşak',
    'Yüksek',
    'Melodi 1',
    'Melodi 2',
  ];

  String _selectedSound = 'Varsayılan';
  String _selectedLanguage = 'tr';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settingsBox = Hive.box(_settingsBoxName);
    setState(() {
      _selectedSound = settingsBox.get(_soundKey, defaultValue: 'Varsayılan');
      _selectedLanguage = settingsBox.get(_languageKey, defaultValue: 'tr');
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
        SnackBar(content: Text('settings_saved'.tr())),
      );
    }
  }

  Future<void> _saveLanguageSetting(String languageCode) async {
    final settingsBox = Hive.box(_settingsBoxName);
    await settingsBox.put(_languageKey, languageCode);
    
    // Change app locale
    await context.setLocale(languageCode == 'en' ? const Locale('en') : const Locale('tr'));
    
    setState(() {
      _selectedLanguage = languageCode;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings_saved'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr()),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'notification_settings'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: Text('notification_sound'.tr()),
            subtitle: Text(_selectedSound),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('select_notification_sound'.tr()),
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
          ListTile(
            title: Text('language'.tr()),
            subtitle: Text(_selectedLanguage == 'en' ? 'english'.tr() : 'turkish'.tr()),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('select_language'.tr()),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<String>(
                        title: Text('turkish'.tr()),
                        value: 'tr',
                        groupValue: _selectedLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            _saveLanguageSetting(value);
                            Navigator.pop(context);
                          }
                        },
                      ),
                      RadioListTile<String>(
                        title: Text('english'.tr()),
                        value: 'en',
                        groupValue: _selectedLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            _saveLanguageSetting(value);
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'about'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: Text('version'.tr()),
            subtitle: const Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}

