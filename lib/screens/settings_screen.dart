import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/screen_util.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('settings_saved'.tr())));
    }
  }

  Future<void> _saveLanguageSetting(String languageCode) async {
    final settingsBox = Hive.box(_settingsBoxName);
    await settingsBox.put(_languageKey, languageCode);

    if (!mounted) return;

    await context.setLocale(
      languageCode == 'en' ? const Locale('en') : const Locale('tr'),
    );

    if (!mounted) return;

    setState(() {
      _selectedLanguage = languageCode;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('settings_saved'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final su = ScreenUtil.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('settings'.tr())),
      body: ListView(
        children: [
          Padding(
            padding: EdgeInsets.all(su.r(16)),
            child: Text(
              'notification_settings'.tr(),
              style: TextStyle(
                fontSize: su.sp(20),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: su.w(16)),
            title: Text(
              'notification_sound'.tr(),
              style: TextStyle(
                fontSize: su.sp(16),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              _selectedSound,
              style: TextStyle(fontSize: su.sp(14)),
            ),
            trailing: Icon(Icons.arrow_forward_ios, size: su.sp(16)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'select_notification_sound'.tr(),
                    style: TextStyle(
                      fontSize: su.sp(16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  content: RadioGroup<String>(
                    groupValue: _selectedSound,
                    onChanged: (value) {
                      if (value != null) {
                        _saveSoundSetting(value);
                        Navigator.pop(context);
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _soundOptions.map((sound) {
                        return RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          title: Text(
                            sound.tr(),
                            style: TextStyle(fontSize: su.sp(14)),
                          ),
                          value: sound,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: su.w(16)),
            title: Text(
              'language'.tr(),
              style: TextStyle(
                fontSize: su.sp(16),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              _selectedLanguage == 'en' ? 'english'.tr() : 'turkish'.tr(),
              style: TextStyle(fontSize: su.sp(14)),
            ),
            trailing: Icon(Icons.arrow_forward_ios, size: su.sp(16)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'select_language'.tr(),
                    style: TextStyle(
                      fontSize: su.sp(16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  content: RadioGroup<String>(
                    groupValue: _selectedLanguage,
                    onChanged: (value) {
                      if (value != null) {
                        _saveLanguageSetting(value);
                        Navigator.pop(context);
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          title: Text(
                            'turkish'.tr(),
                            style: TextStyle(fontSize: su.sp(14)),
                          ),
                          value: 'tr',
                        ),
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          title: Text(
                            'english'.tr(),
                            style: TextStyle(fontSize: su.sp(14)),
                          ),
                          value: 'en',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Divider(thickness: su.h(1)),
          Padding(
            padding: EdgeInsets.all(su.r(16)),
            child: Text(
              'about'.tr(),
              style: TextStyle(
                fontSize: su.sp(20),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: su.w(16)),
            title: Text(
              'version'.tr(),
              style: TextStyle(fontSize: su.sp(16)),
            ),
            subtitle: Text(
              '1.0.0',
              style: TextStyle(fontSize: su.sp(14)),
            ),
          ),
        ],
      ),
    );
  }
}
