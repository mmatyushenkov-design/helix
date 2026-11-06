import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/cycle_card.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/dashed_border.dart';
import '../widgets/set_box.dart';
import '../widgets/set_sheet.dart';

/// Полноэкранный редактор цикла: ТМ, шаг прогресса, дни с подходами.
class CycleEditScreen extends StatefulWidget {
  final Cycle cycle;
  const CycleEditScreen({super.key, required this.cycle});

  @override
  State<CycleEditScreen> createState() => _CycleEditScreenState();
}

class _CycleEditScreenState extends State<CycleEditScreen> {
  Cycle get c => widget.cycle;

  static const stepOptions = [1.0, 1.25, 2.0, 2.5, 4.0, 5.0];

  void _mutate(VoidCallback fn) {
    setState(fn);
    appState.touch();
  }

  Future<void> _editSet(int dayIdx, int setIdx) async {
    final res = await showSetSheet(context, mode: SetSheetMode.editCycle, cycle: c, initial: c.days[dayIdx].sets[setIdx]);
    if (res == null) return;
    _mutate(() {
      if (res.deleted) {
        c.days[dayIdx].sets.removeAt(setIdx);
      } else if (res.set != null) {
        c.days[dayIdx].sets[setIdx] = res.set!;
      }
    });
  }

  Future<void> _addSet(int dayIdx) async {
    final res = await showSetSheet(context, mode: SetSheetMode.newCycleSet, cycle: c);
    if (res == null || res.set == null) return;
    _mutate(() => c.days[dayIdx].sets.add(res.set!));
  }

  Future<void> _editTm() async {
    final res = await showSetSheet(context, mode: SetSheetMode.tmCalc, cycle: c);
    if (res == null || res.tm == null) return;
    _mutate(() {
      c.tm = res.tm!;
      c.bestW = res.bestW!;
      c.bestR = res.bestR!;
    });
  }

  Future<bool> _confirm(String text) => showConfirmDialog(context, text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(appState.exerciseName(c.exerciseId, c.name),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            FlameLabel(
                text:
                    '${fmtW(appState.weightFromKg(c.bestW))}×${c.bestR} | ${fmtW(appState.weightFromKg(c.tm))} ${appState.weightLabel}'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ТМ
          Row(children: [
            const Text('Расчётный максимум:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _editTm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: fmtW(appState.weightFromKg(c.tm))),
                    TextSpan(
                        text: ' ${appState.weightLabel}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
                  ]),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // шаг прогресса
          Row(children: [
            const Text('Минимальный шаг прогресса:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButton<double>(
                value: c.step,
                underline: const SizedBox.shrink(),
                dropdownColor: AppColors.surface2,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                items: [
                  for (final s in stepOptions)
                    DropdownMenuItem(
                        value: s, child: Text('${fmtW(appState.weightFromKg(s))} ${appState.weightLabel}')),
                ],
                onChanged: (v) => _mutate(() => c.step = v ?? c.step),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          const Text('Нажми на подход, чтобы изменить вес, процент или RIR',
              style: TextStyle(fontSize: 12, color: AppColors.textDim)),
          const SizedBox(height: 14),
          for (var i = 0; i < c.days.length; i++) _dayCard(i),
          const SizedBox(height: 4),
          // добавить день
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: c.days.length >= 8 ? null : () => _mutate(() => c.days.add(CycleDay([
                  CycleSet(pct: 60, reps: 5, rir: 3),
                  CycleSet(pct: 65, reps: 5, rir: 2),
                  CycleSet(pct: 70, reps: 5, rir: 2),
                ]))),
            child: DashedBorder(
              color: AppColors.border,
              radius: 14,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('+ Добавить день',
                      style: TextStyle(fontSize: 14, color: AppColors.textDim)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // удалить цикл
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                if (await _confirm('Удалить цикл «${c.name}»?')) {
                  appState.deleteCycle(c);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD06060),
                side: const BorderSide(color: Color(0xFFA03030), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Удалить цикл'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(int i) {
    final d = c.days[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('День ${i + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            GestureDetector(
              onTap: () async {
                if (await _confirm('Удалить день ${i + 1} из цикла?')) {
                  _mutate(() {
                    c.days.removeAt(i);
                    if (c.curDay >= c.days.length) c.curDay = c.days.isEmpty ? 0 : c.days.length - 1;
                  });
                }
              },
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA03030), width: 1.5),
                ),
                child: const Center(
                  child: Text('✕', style: TextStyle(fontSize: 12, color: Color(0xFFD06060), height: 1)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SetFlow(
            sets: [
              for (final s in d.sets)
                SetBoxData(
                  w: setWeight(c, s),
                  reps: s.reps,
                  rir: s.rir,
                  pct: s.pct ?? (s.w! / c.tm * 100).round(),
                  pctApprox: s.pct == null,
                ),
            ],
            onSetTap: (si) => _editSet(i, si),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _addSet(i),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('+ Подход', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
