import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../theme/app_theme.dart';
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
    final box = Hive.box(_settingsBoxName);
    setState(() {
      _selectedSound = box.get(_soundKey, defaultValue: 'Varsayılan') as String;
      _selectedLanguage = box.get(_languageKey, defaultValue: 'tr') as String;
    });
  }

  Future<void> _saveSoundSetting(String sound) async {
    await Hive.box(_settingsBoxName).put(_soundKey, sound);
    setState(() => _selectedSound = sound);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings_saved'.tr())),
      );
    }
  }

  Future<void> _saveLanguageSetting(String languageCode) async {
    await Hive.box(_settingsBoxName).put(_languageKey, languageCode);
    if (!mounted) return;
    await context.setLocale(
      languageCode == 'en' ? const Locale('en') : const Locale('tr'),
    );
    if (!mounted) return;
    setState(() => _selectedLanguage = languageCode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings_saved'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final su = ScreenUtil.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('settings'.tr())),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: su.w(16), vertical: su.h(12)),
        children: [
          _SectionHeader(label: 'notification_settings'.tr(), su: su),
          _SettingsTile(
            icon: Icons.music_note_rounded,
            title: 'notification_sound'.tr(),
            subtitle: _selectedSound,
            su: su,
            onTap: () => _showSoundPicker(context, su),
          ),
          SizedBox(height: su.h(8)),
          _SectionHeader(label: 'language'.tr(), su: su),
          _SettingsTile(
            icon: Icons.language_rounded,
            title: 'language'.tr(),
            subtitle: _selectedLanguage == 'en' ? 'english'.tr() : 'turkish'.tr(),
            su: su,
            onTap: () => _showLanguagePicker(context, su),
          ),
          SizedBox(height: su.h(8)),
          _SectionHeader(label: 'about'.tr(), su: su),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'version'.tr(),
            subtitle: '1.0.0',
            su: su,
          ),
        ],
      ),
    );
  }

  void _showSoundPicker(BuildContext context, ScreenUtil su) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('select_notification_sound'.tr()),
        content: RadioGroup<String>(
          groupValue: _selectedSound,
          onChanged: (value) {
            if (value != null) {
              _saveSoundSetting(value);
              Navigator.pop(ctx);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _soundOptions
                .map((s) => RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      title: Text(s.tr(),
                          style: TextStyle(fontSize: su.sp(14))),
                      value: s,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, ScreenUtil su) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('select_language'.tr()),
        content: RadioGroup<String>(
          groupValue: _selectedLanguage,
          onChanged: (value) {
            if (value != null) {
              _saveLanguageSetting(value);
              Navigator.pop(ctx);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                title: Text('turkish'.tr(),
                    style: TextStyle(fontSize: su.sp(14))),
                value: 'tr',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                title: Text('english'.tr(),
                    style: TextStyle(fontSize: su.sp(14))),
                value: 'en',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final ScreenUtil su;
  const _SectionHeader({required this.label, required this.su});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(su.w(4), su.h(16), 0, su.h(8)),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: su.sp(11),
          fontWeight: FontWeight.w700,
          color: AppColors.textHint,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ─── Settings Tile ────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ScreenUtil su;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.su,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppDecorations.card(),
        padding: EdgeInsets.symmetric(
            horizontal: su.w(16), vertical: su.h(14)),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(su.r(8)),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: su.sp(18), color: AppColors.primary),
            ),
            SizedBox(width: su.w(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: su.sp(15),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: su.h(2)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: su.sp(13),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  size: su.sp(20), color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
