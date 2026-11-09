import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/strings.dart';
import '../storage/backup_service.dart';
import '../theme.dart';
import '../widgets/haptics.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _accents = [
    AppColors.accentGreen,
    AppColors.accentBlue,
    AppColors.accentOrange,
    AppColors.accentPurple,
    AppColors.accentRed,
  ];

  Future<void> _runFileAction(
      BuildContext context, Future<String> Function() action) async {
    try {
      final path = await action();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(path)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  /// Экспорт: JSON со всеми данными → ZIP → системное окно «Поделиться»
  /// (Telegram, почта, WhatsApp и другие приложения через «Ещё»).
  Future<void> _exportData(BuildContext context) async {
    try {
      final path =
          await LocalBackupService().createExportZip(appState.toJson());
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final picked = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
      final path = picked?.files.single.path;
      if (path == null) return;
      final service = LocalBackupService();
      await service.createBackup(appState.toJson()); // страховка перед импортом
      final snapshot = await service.restoreBackup(path);
      appState.loadJson(snapshot);
      appState.touch();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Данные восстановлены')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(tr('settings'),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
          _group(tr('appearance'), [
            _row(
              tr('accent'),
              trailing: Row(children: [
                for (final c in _accents)
                  _AccentDot(color: c, selected: appState.accent == c)
              ]),
            ),
            _row(
              tr('language'),
              trailing: SizedBox(
                height: 26,
                child: DropdownButton<String>(
                value: appState.language,
                isDense: true,
                underline: const SizedBox.shrink(),
                dropdownColor: AppColors.surface2,
                items: const [
                  DropdownMenuItem(value: 'ru', child: Text('Русский')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (v) {
                  hapticTick();
                  appState.setLanguage(v ?? 'ru');
                },
                ),
              ),
            ),
          ]),
          _group(tr('training'), [
            _row(
              tr('weightUnits'),
              trailing: SizedBox(
                height: 26,
                child: DropdownButton<WeightUnit>(
                value: appState.weightUnit,
                isDense: true,
                underline: const SizedBox.shrink(),
                dropdownColor: AppColors.surface2,
                items: [
                  DropdownMenuItem(
                      value: WeightUnit.kg,
                      child: Text(
                          weightUnitLabel(WeightUnit.kg, appState.language))),
                  const DropdownMenuItem(
                      value: WeightUnit.lb, child: Text('lb')),
                ],
                onChanged: (v) {
                  hapticTick();
                  appState.setWeightUnit(v ?? WeightUnit.kg);
                },
                ),
              ),
            ),
            _row(
              tr('distanceUnits'),
              trailing: SizedBox(
                height: 26,
                child: DropdownButton<DistanceUnit>(
                value: appState.distanceUnit == DistanceUnit.mi
                    ? DistanceUnit.km
                    : appState.distanceUnit,
                isDense: true,
                underline: const SizedBox.shrink(),
                dropdownColor: AppColors.surface2,
                items: [
                  DropdownMenuItem(
                      value: DistanceUnit.km,
                      child: Text(distanceUnitLabel(
                          DistanceUnit.km, appState.language))),
                  // Мили временно отключены: учёт дистанции только в метрах/км.
                ],
                onChanged: (v) {
                  hapticTick();
                  appState.setDistanceUnit(v ?? DistanceUnit.km);
                },
                ),
              ),
            ),
          ]),
          _group(tr('data'), [
            _row(
              tr('backup'),
              trailing: const _Val('›'),
              onTap: () => _exportData(context),
            ),
            _row(tr('restore'),
                trailing: const _Val('›'), onTap: () => _restore(context)),
            _row(
              tr('exportCsv'),
              trailing: const _Val('›'),
              onTap: () => _runFileAction(context,
                  () => LocalBackupService().exportCsv(appState.toJson())),
            ),
          ]),
          _group(tr('about'),
              [_row(tr('version'), trailing: const _Val('beta-0.4.3'))]),
        ],
      ),
    );
  }

  Widget _group(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textDim,
                    letterSpacing: 0.5)),
          ),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, {required Widget trailing, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                hapticTick();
                onTap();
              },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 14))),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _Val extends StatelessWidget {
  final String text;
  const _Val(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 14, color: AppColors.textDim));
}

class _AccentDot extends StatelessWidget {
  final Color color;
  final bool selected;
  const _AccentDot({required this.color, required this.selected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        hapticTick();
        appState.setAccent(color);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: AnimatedScale(
          scale: selected ? 1.15 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 2),
              boxShadow: selected
                  ? [
                      const BoxShadow(color: AppColors.bg, spreadRadius: 3),
                      BoxShadow(color: color, spreadRadius: 5)
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
