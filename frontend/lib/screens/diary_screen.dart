import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/set_box.dart';
import '../widgets/set_sheet.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/dashed_border.dart';
import 'diary_exercise_picker.dart';

const _dows = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _months = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];
const _monthsNom = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _monday(DateTime d) =>
    _dateOnly(d).subtract(Duration(days: (d.weekday - 1) % 7));

/// Вкладка «Дневник»: календарь + тренировка выбранного дня.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime _selected = _dateOnly(DateTime.now());
  late DateTime _viewMonth = DateTime(_selected.year, _selected.month);
  bool _monthOpen = false;

  void _select(DateTime d) {
    setState(() {
      _selected = _dateOnly(d);
      _viewMonth = DateTime(d.year, d.month);
    });
  }

  bool _isToday(DateTime d) => _dateOnly(d) == _dateOnly(DateTime.now());

  /* ---------- действия с подходами и упражнениями ---------- */

  Future<void> _editSet(DiaryEntry e, int i) async {
    final s = e.sets[i];
    final res = await showSetSheet(
      context,
      mode: SetSheetMode.editSet,
      format: e.recordFormat,
      initial: CycleSet(
        w: s.w,
        reps: s.reps,
        rir: s.rir,
        durationSec: s.durationSec,
        distanceM: s.distanceM,
      ),
    );
    if (res == null) return;
    if (res.deleted) {
      e.sets.removeAt(i);
      if (e.sets.isEmpty) {
        appState.deleteEntry(_selected, e);
      } else {
        appState.touch();
      }
    } else if (res.set != null) {
      final value = res.set!;
      e.sets[i] = DiarySet(
        w: value.w ?? 0,
        reps: value.reps,
        rir: value.rir,
        durationSec: value.durationSec,
        distanceM: value.distanceM,
      );
      appState.touch();
    }
  }

  Future<void> _addSet(DiaryEntry e) async {
    final res = await showSetSheet(context,
        mode: SetSheetMode.newSet, format: e.recordFormat);
    if (res?.set != null) {
      final value = res!.set!;
      e.sets.add(DiarySet(
        w: value.w ?? 0,
        reps: value.reps,
        rir: value.rir,
        durationSec: value.durationSec,
        distanceM: value.distanceM,
      ));
      appState.touch();
    }
  }

  void _finish(DiaryEntry e) {
    final res = appState.finishEntry(e);
    if (res != null && mounted) _showCelebrate(res);
  }

  void _confirmDelete(DiaryEntry e) async {
    if (await showConfirmDialog(
        context, 'Вы уверены, что хотите удалить это упражнение?')) {
      appState.deleteEntry(_selected, e);
    }
  }

  Future<void> _pickExercise() async {
    final picked = await showDiaryExercisePicker(context);
    if (picked == null) return;
    if (picked.withCycle) {
      final c = appState.cycleById(picked.cycleId);
      if (c != null) {
        appState.addEntry(_selected, c.name,
            cycleId: c.id,
            dayIdx: c.curDay,
            presetSets: [
              for (final s in c.days[c.curDay].sets)
                DiarySet(
                    w: setWeight(c, s),
                    reps: s.reps,
                    rir: s.rir,
                    planned: true),
            ]);
        return;
      }
    }
    appState.addEntry(_selected, picked.name);
  }

  /* ---------- поздравление с концом цикла ---------- */

  void _showCelebrate(FinishResult res) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉 Цикл пройден!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _CelebrateAnim(oldTm: res.oldTm, step: res.step),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: appState.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Так держать!',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ---------- сборка ---------- */

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final accent = appState.accent;
        final entries = appState.entriesOf(_selected);
        final isToday = _isToday(_selected);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCalendar(accent),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  'Тренировка — ${isToday ? 'сегодня' : '${_selected.day} ${_months[_selected.month - 1]}'}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text('В этот день записей нет',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.textDim)),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: entries.length,
                  onReorderItem: (oldI, newI) {
                    entries.insert(newI, entries.removeAt(oldI));
                    appState.touch();
                  },
                  itemBuilder: (context, i) => _buildEntryCard(
                      entries[i], i, accent,
                      key: ValueKey(entries[i].id)),
                ),
              const SizedBox(height: 2),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickExercise,
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
                      child: Text('+ Добавить упражнение',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textDim)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /* ---------- календарь ---------- */

  static const _weekHeight = 58.0;
  static const _monthRowHeight = 44.0;
  static const _monthHeaderHeight = 70.0;

  Widget _buildCalendar(Color accent) {
    final y = _viewMonth.year, m = _viewMonth.month;
    final lead = (DateTime(y, m, 1).weekday - 1) % 7;
    final daysIn = DateTime(y, m + 1, 0).day;
    final cellCount = ((lead + daysIn + 6) ~/ 7) * 7;
    final first = DateTime(y, m, 1).subtract(Duration(days: lead));
    final dates = [
      for (var i = 0; i < cellCount; i++) first.add(Duration(days: i))
    ];
    final monday = _monday(_selected);
    final weekIndex = dates.indexWhere((d) => _dateOnly(d) == monday);
    final weekRow = weekIndex < 0 ? -1 : weekIndex ~/ 7;
    final rows = cellCount ~/ 7;
    final monthHeight = _monthHeaderHeight +
        rows * _monthRowHeight +
        (weekRow >= 0 ? _weekHeight - _monthRowHeight : 0);
    final weekTop =
        weekRow < 0 ? 0.0 : _monthHeaderHeight + weekRow * _monthRowHeight;

    return GestureDetector(
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v > 200 && !_monthOpen) setState(() => _monthOpen = true);
        if (v < -200 && _monthOpen) setState(() => _monthOpen = false);
      },
      child: Container(
        key: const Key('calendar'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            ClipRect(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                height: _monthOpen ? monthHeight : _weekHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: monthHeight,
                      child: IgnorePointer(
                        ignoring: !_monthOpen,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _monthOpen ? 1 : 0,
                          child: _buildMonth(accent, dates, weekRow),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      left: 0,
                      right: 0,
                      top: _monthOpen ? weekTop : 0,
                      height: _weekHeight,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _monthOpen && weekRow < 0 ? 0 : 1,
                        child: _buildWeekRow(accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              key: const Key('calendar-handle'),
              onTap: () => setState(() => _monthOpen = !_monthOpen),
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF555555),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekRow(Color accent) {
    final monday = _monday(_selected);
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _weekDay(monday.add(Duration(days: i)), i, accent),
            ),
          ),
      ],
    );
  }

  Widget _weekDay(DateTime d, int dow, Color accent) {
    final sel = _dateOnly(d) == _selected;
    final today = _isToday(d);
    final has =
        appState.log.containsKey(dkey(d)) && appState.log[dkey(d)]!.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _select(d),
      child: Container(
        height: _weekHeight,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color:
              sel ? accent : (_monthOpen ? AppColors.accentDim(accent) : null),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: today && !sel ? accent : AppColors.border,
            width: today && !sel ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(_dows[dow],
                style: TextStyle(
                    fontSize: 11,
                    color: sel
                        ? Colors.black.withValues(alpha: 0.67)
                        : AppColors.textDim)),
            const SizedBox(height: 2),
            Text('${d.day}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.black : AppColors.text)),
            SizedBox(
              height: 8,
              child: has
                  ? Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                          color: sel ? Colors.black : accent,
                          shape: BoxShape.circle),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonth(Color accent, List<DateTime> dates, int weekRow) {
    final y = _viewMonth.year, m = _viewMonth.month;
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _monthNav(
                    '‹', () => setState(() => _viewMonth = DateTime(y, m - 1))),
                Text('${_monthsNom[m - 1]} $y',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                _monthNav(
                    '›', () => setState(() => _viewMonth = DateTime(y, m + 1))),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 18,
          child: Row(children: [
            for (final d in _dows)
              Expanded(
                  child: Center(
                      child: Text(d,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textDim))))
          ]),
        ),
        for (var r = 0; r < dates.length ~/ 7; r++)
          SizedBox(
            height: r == weekRow ? _weekHeight : _monthRowHeight,
            child: r == weekRow
                ? null
                : Row(children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                          child: _monthCell(dates[r * 7 + c], accent: accent))
                  ]),
          ),
      ],
    );
  }

  Widget _monthNav(String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 16))),
      ),
    );
  }

  Widget _monthCell(DateTime d, {required Color accent}) {
    final sel = _dateOnly(d) == _selected;
    final today = _isToday(d);
    final monday = _monday(_selected);
    final inWeek = !_dateOnly(d).isBefore(monday) &&
        _dateOnly(d).isBefore(monday.add(const Duration(days: 7)));
    final other = d.month != _viewMonth.month;
    final has =
        appState.log.containsKey(dkey(d)) && appState.log[dkey(d)]!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _select(d),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: sel ? accent : (inWeek ? AppColors.accentDim(accent) : null),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: today && !sel ? accent : AppColors.border,
              width: today && !sel ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text('${d.day}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      color: sel
                          ? Colors.black
                          : other
                              ? const Color(0xFF777777)
                              : AppColors.text)),
              SizedBox(
                height: 7,
                child: has
                    ? Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                            color: sel ? Colors.black : accent,
                            shape: BoxShape.circle),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ---------- карточка упражнения ---------- */

  Widget _buildEntryCard(DiaryEntry e, int index, Color accent,
      {required Key key}) {
    final c = appState.cycleById(e.cycleId);
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 26),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: _DragHandle(),
                      ),
                    ),
                    Expanded(
                      child: Text(appState.exerciseName(e.exerciseId, e.name),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    if (c != null && e.dayIdx != null)
                      Text('день ${e.dayIdx! + 1}/${c.days.length}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SetFlow(
                sets: [
                  for (final s in e.sets)
                    SetBoxData(
                      w: s.w,
                      reps: s.reps,
                      rir: s.rir,
                      durationSec: s.durationSec,
                      distanceM: s.distanceM,
                      format: e.recordFormat,
                      planned: s.planned,
                    ),
                ],
                onSetTap: e.done ? null : (i) => _editSet(e, i),
              ),
              if (!e.done) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _finish(e),
                        child: Container(
                          height: 45,
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text('Завершить',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _addSet(e),
                        child: DashedBorder(
                          color: AppColors.border,
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('+ Подход',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: accent)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: e.done
                ? InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => appState.undoFinish(e),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Text('⚙',
                          style: TextStyle(
                              fontSize: 17, color: Color(0xFF777777))),
                    ),
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => _confirmDelete(e),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFA03030), width: 1.5),
                      ),
                      child: const Center(
                        child: Text('✕',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFD06060),
                                height: 1)),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Три серые горизонтальные палочки — ручка перетаскивания.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 14,
            height: 2,
            margin: const EdgeInsets.symmetric(vertical: 1.6),
            decoration: BoxDecoration(
                color: const Color(0xFF666666),
                borderRadius: BorderRadius.circular(1)),
          ),
      ],
    );
  }
}

/// Анимация поздравления: ТМ уезжает влево, появляется «+шаг», оба пульсируют ×1,5.
class _CelebrateAnim extends StatefulWidget {
  final double oldTm;
  final double step;
  const _CelebrateAnim({required this.oldTm, required this.step});

  @override
  State<_CelebrateAnim> createState() => _CelebrateAnimState();
}

class _CelebrateAnimState extends State<_CelebrateAnim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = appState.accent;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        // 0–0,35: плюс въезжает справа; 0,35–1: общая пульсация 1 → 1,5 → 1
        final inT = (t / 0.35).clamp(0.0, 1.0);
        final pulse = t < 0.35
            ? 0.0
            : Curves.easeInOut
                .transform(((t - 0.35) / 0.65 * 2).clamp(0.0, 2.0));
        final scale = 1 + 0.5 * (pulse <= 1 ? pulse : 2 - pulse);
        return Transform.scale(
          scale: scale,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🔥 ${fmtW(widget.oldTm)} кг',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      shadows: const [
                        Shadow(color: Colors.black26, blurRadius: 2)
                      ])),
              Opacity(
                opacity: inT,
                child: Transform.translate(
                  offset: Offset(16 * (1 - inT), 0),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('+${fmtW(widget.step)} кг',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF9D45))),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
