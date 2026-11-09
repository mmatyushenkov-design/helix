import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/set_box.dart';
import '../widgets/set_sheet.dart';
import '../widgets/close_icon.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/haptics.dart';
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
  static const _pageBase = 10000;
  DateTime _selected = _dateOnly(DateTime.now());
  late DateTime _viewMonth = DateTime(_selected.year, _selected.month);
  late DateTime _viewMonday = _monday(_selected);
  bool _monthOpen = false;
  late final PageController _weekPages =
      PageController(initialPage: _weekPage(_viewMonday));
  late final PageController _monthPages =
      PageController(initialPage: _monthPage(_viewMonth));

  DateTime get _minDate => DateTime(2025);
  DateTime get _maxDate => DateTime(DateTime.now().year + 1, 12, 31);
  int _weekPage(DateTime monday) =>
      _pageBase + monday.difference(_monday(_minDate)).inDays ~/ 7;
  DateTime _weekAt(int page) =>
      _monday(_minDate).add(Duration(days: (page - _pageBase) * 7));
  int _monthPage(DateTime month) =>
      _pageBase + (month.year - 2025) * 12 + month.month - 1;
  DateTime _monthAt(int page) {
    final offset = page - _pageBase;
    return DateTime(2025 + offset ~/ 12, offset % 12 + 1);
  }

  @override
  void dispose() {
    _weekPages.dispose();
    _monthPages.dispose();
    super.dispose();
  }

  void _syncPages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final weekPage = _weekPage(_viewMonday);
      final monthPage = _monthPage(_viewMonth);
      if (_weekPages.hasClients && _weekPages.page?.round() != weekPage) {
        _weekPages.jumpToPage(weekPage);
      }
      if (_monthPages.hasClients && _monthPages.page?.round() != monthPage) {
        _monthPages.jumpToPage(monthPage);
      }
    });
  }

  void _select(DateTime d) {
    d = _dateOnly(d);
    if (d.isBefore(_minDate) || d.isAfter(_maxDate)) return;
    hapticTick();
    setState(() {
      _selected = d;
      _viewMonday = _monday(d);
      _viewMonth = DateTime(d.year, d.month);
    });
    _syncPages();
  }

  void _returnToSelectedWeek() {
    setState(() => _viewMonday = _monday(_selected));
    _syncPages();
  }

  void _toggleMonth() {
    setState(() {
      _monthOpen = !_monthOpen;
      if (!_monthOpen) {
        _viewMonday = _monday(_selected);
        _viewMonth = DateTime(_selected.year, _selected.month);
      }
    });
    _syncPages();
  }

  void _changeMonth(int delta) {
    final next = DateTime(_viewMonth.year, _viewMonth.month + delta);
    if (next.isBefore(DateTime(2025)) ||
        next.isAfter(DateTime(DateTime.now().year + 1, 12))) {
      return;
    }
    hapticTick();
    _monthPages.animateToPage(_monthPage(next),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic);
  }

  Future<void> _pickMonth() async {
    var year = _viewMonth.year;
    var month = _viewMonth.month;
    final picked = await showDialog<(int, int)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Widget plaque(Widget dropdown) => Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(child: dropdown),
              );
          const textStyle =
              TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Выберите месяц и год'),
            content: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: plaque(DropdownButton<int>(
                    value: month,
                    isExpanded: true,
                    style: textStyle,
                    dropdownColor: AppColors.surface2,
                    items: [
                      for (var i = 1; i <= 12; i++)
                        DropdownMenuItem(
                            value: i, child: Text(_monthsNom[i - 1]))
                    ],
                    onChanged: (value) =>
                        setDialogState(() => month = value ?? month),
                  )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: plaque(DropdownButton<int>(
                    value: year,
                    isExpanded: true,
                    style: textStyle,
                    dropdownColor: AppColors.surface2,
                    items: [
                      for (var y = 2025; y <= DateTime.now().year + 1; y++)
                        DropdownMenuItem(value: y, child: Text('$y'))
                    ],
                    onChanged: (value) =>
                        setDialogState(() => year = value ?? year),
                  )),
                ),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: appState.accent,
                        side: BorderSide(color: appState.accent, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, (year, month)),
                      style: FilledButton.styleFrom(
                        backgroundColor: appState.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Выбрать',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    if (picked != null) _select(DateTime(picked.$2, picked.$1));
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
    hapticTick();
    // Остались серые плановые подходы — сначала предупреждение.
    if (e.sets.any((s) => s.planned)) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          content: const Text(
              'Выполнены не все подходы, запланированные на это упражнение. Завершить?'),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Продолжить'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('finish-anyway'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _finishNow(e);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: appState.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Завершить',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      return;
    }
    _finishNow(e);
  }

  void _finishNow(DiaryEntry e) {
    final res = appState.finishEntry(e);
    if (res != null && mounted) _showCelebrate(res);
  }

  void _confirmDelete(DiaryEntry e) async {
    hapticTick();
    if (await showConfirmDialog(
        context, 'Вы уверены, что хотите удалить это упражнение?')) {
      appState.deleteEntry(_selected, e);
    }
  }

  Future<void> _pickExercise() async {
    hapticTick();
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
        _returnToSelectedWeek();
        return;
      }
    }
    appState.addEntry(_selected, picked.name);
    _returnToSelectedWeek();
  }

  /* ---------- поздравление с концом цикла ---------- */

  void _showCelebrate(FinishResult res) {
    var ready = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
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
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                CelebrateAnim(
                  oldTm: res.oldTm,
                  step: res.step,
                  onReady: () => setDialogState(() => ready = true),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('celebrate-continue'),
                    onPressed: ready ? () => Navigator.pop(ctx) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: appState.accent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: AppColors.surface2,
                      disabledForegroundColor: AppColors.textDim,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Так держать!',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
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
    final rows = ((lead + DateTime(y, m + 1, 0).day + 6) ~/ 7);
    final monthHeight = _monthHeaderHeight + rows * _monthRowHeight;
    final weekCount =
        _monday(_maxDate).difference(_monday(_minDate)).inDays ~/ 7 + 1;
    final monthCount = (DateTime.now().year + 1 - 2025 + 1) * 12;
    // Нумерация страниц начинается с _pageBase, поэтому учитываем его в count.
    final weekItemCount = _pageBase + weekCount;
    final monthItemCount = _pageBase + monthCount;

    return GestureDetector(
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v > 200 && !_monthOpen) _toggleMonth();
        if (v < -200 && _monthOpen) _toggleMonth();
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
                      height: _monthHeaderHeight,
                      child: Offstage(
                        offstage: !_monthOpen,
                        child: _buildMonthHeader(),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _monthHeaderHeight,
                      bottom: 0,
                      child: Offstage(
                        offstage: !_monthOpen,
                        child: PageView.builder(
                          controller: _monthPages,
                          itemCount: monthItemCount,
                          onPageChanged: (page) {
                            if (_monthOpen) {
                              setState(() => _viewMonth = _monthAt(page));
                            }
                          },
                          itemBuilder: (context, page) {
                            final month = _monthAt(page);
                            final firstLead =
                                (DateTime(month.year, month.month, 1).weekday -
                                        1) %
                                    7;
                            final count = ((firstLead +
                                        DateTime(month.year, month.month + 1, 0)
                                            .day +
                                        6) ~/
                                    7) *
                                7;
                            final first = DateTime(month.year, month.month, 1)
                                .subtract(Duration(days: firstLead));
                            return SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: _buildMonth(accent, month, [
                                for (var i = 0; i < count; i++)
                                  first.add(Duration(days: i))
                              ]),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Offstage(
                        offstage: _monthOpen,
                        child: PageView.builder(
                          controller: _weekPages,
                          itemCount: weekItemCount,
                          onPageChanged: (page) {
                            if (!_monthOpen) {
                              hapticTick();
                              setState(() => _viewMonday = _weekAt(page));
                            }
                          },
                          itemBuilder: (context, page) =>
                              _buildWeekRow(accent, _weekAt(page)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              key: const Key('calendar-handle'),
              onTap: _toggleMonth,
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

  /// Точки мышечных групп под числом даты: одна точка на группу.
  Widget _dayDots(DateTime d, bool selected, {double dot = 6, double top = 2}) {
    final groups = appState.dayMuscleGroups(d);
    if (groups.isEmpty) return SizedBox(height: top + dot);
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: SizedBox(
        height: dot,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < groups.length && i < 4; i++)
              Container(
                width: dot,
                height: dot,
                margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                decoration: BoxDecoration(
                  color: muscleGroupColor(groups[i]),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekRow(Color accent, DateTime monday) {
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
            _dayDots(d, sel),
          ],
        ),
      ),
    );
  }

  /// Шапка не входит в PageView: при свайпе движется только сетка дат.
  Widget _buildMonthHeader() {
    final y = _viewMonth.year, m = _viewMonth.month;
    return Column(children: [
      SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _monthNav('‹', () => _changeMonth(-1)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: InkWell(
                    key: const Key('month-picker'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pickMonth,
                    child: Container(
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_monthsNom[m - 1]} $y',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
              _monthNav('›', () => _changeMonth(1)),
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
    ]);
  }

  Widget _buildMonth(Color accent, DateTime month, List<DateTime> dates) {
    return Column(children: [
      for (var r = 0; r < dates.length ~/ 7; r++)
        SizedBox(
          height: _monthRowHeight,
          child: Row(children: [
            for (var c = 0; c < 7; c++)
              Expanded(
                  child: _monthCell(dates[r * 7 + c],
                      month: month, accent: accent))
          ]),
        ),
    ]);
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

  Widget _monthCell(DateTime d,
      {required DateTime month, required Color accent}) {
    final sel = _dateOnly(d) == _selected;
    final today = _isToday(d);
    final monday = _monday(_selected);
    final inWeek = !_dateOnly(d).isBefore(monday) &&
        _dateOnly(d).isBefore(monday.add(const Duration(days: 7)));
    final other = d.month != month.month;
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
              _dayDots(d, sel, dot: 5, top: 2),
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
    // Зажатие в любом месте карточки — перетаскивание для смены порядка.
    return ReorderableDelayedDragStartListener(
      key: key,
      index: index,
      child: Container(
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
              top: -2,
              right: -2,
              child: e.done
                  ? InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => appState.undoFinish(e),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.settings_outlined,
                            size: 18, color: Color(0xFF777777)),
                      ),
                    )
                  : InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: () => _confirmDelete(e),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: CloseBadge(size: 20),
                      ),
                    ),
            ),
          ],
        ),
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

/// Расчётный максимум прокручивается к новому значению и пульсирует.
class CelebrateAnim extends StatefulWidget {
  final double oldTm;
  final double step;
  final VoidCallback onReady;
  const CelebrateAnim(
      {super.key,
      required this.oldTm,
      required this.step,
      required this.onReady});

  @override
  State<CelebrateAnim> createState() => _CelebrateAnimState();
}

class _CelebrateAnimState extends State<CelebrateAnim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2500))
    ..forward();
  bool _announced = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _isDigit(String ch) => ch.length == 1 && '0123456789'.contains(ch);

  /// Ширина символа: у цифр единая, у остальных — по измерению.
  double _charW(String ch, TextStyle style, double digitW) {
    if (_isDigit(ch)) return digitW;
    final tp = TextPainter(
        text: TextSpan(text: ch, style: style),
        textDirection: TextDirection.ltr)
      ..layout();
    return tp.width;
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontSize: 22, fontWeight: FontWeight.w800, color: appState.accent);
    // Сначала выравниваем дробную часть, затем целую. У каждого разряда
    // остаётся собственная колонка: 122,5 → 125,0 и 125,0 → 127,5.
    final oldRaw = fmtW(appState.weightFromKg(widget.oldTm));
    final newRaw = fmtW(appState.weightFromKg(widget.oldTm + widget.step));
    final oldParts = oldRaw.split(',');
    final newParts = newRaw.split(',');
    final decimals = (oldParts.length > 1 ? oldParts[1].length : 0) >
            (newParts.length > 1 ? newParts[1].length : 0)
        ? (oldParts.length > 1 ? oldParts[1].length : 0)
        : (newParts.length > 1 ? newParts[1].length : 0);
    String withDecimals(List<String> parts) => decimals == 0
        ? parts[0]
        : '${parts[0]},${(parts.length > 1 ? parts[1] : '').padRight(decimals, '0')}';
    final oldDecimal = withDecimals(oldParts);
    final newDecimal = withDecimals(newParts);
    final width = oldDecimal.length > newDecimal.length
        ? oldDecimal.length
        : newDecimal.length;
    final oldPadded = oldDecimal.padLeft(width);
    final newPadded = newDecimal.padLeft(width);

    // Единая ширина цифры и высота строки для барабанов.
    final measure = TextPainter(
        text: TextSpan(text: '0', style: style),
        textDirection: TextDirection.ltr)
      ..layout();
    final digitW = measure.width;
    final lineH = measure.height;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final roll =
            Curves.easeInOut.transform(((t - 0.2) / 0.4).clamp(0.0, 1.0));
        var scale = 1.0;
        if (t >= 0.6 && t < 0.7) {
          scale = 1 - 0.15 * ((t - 0.6) / 0.1); // лёгкое сжатие
        } else if (t >= 0.7 && t < 0.78) {
          scale = 0.85 + 0.33 * ((t - 0.7) / 0.08); // сильный рост
        } else if (t >= 0.78) {
          scale = 1.18 - 0.18 * ((t - 0.78) / 0.1).clamp(0.0, 1.0);
        }
        if (t >= 0.9 && !_announced) {
          _announced = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.onReady());
        }

        final cells = <Widget>[];
        for (var i = 0; i < newPadded.length; i++) {
          final oldCh = i < oldPadded.length ? oldPadded[i] : ' ';
          final newCh = newPadded[i];
          if (oldCh == newCh) {
            // Неизменные цифры и символы остаются на месте.
            cells.add(_staticCell(newCh, style, digitW, lineH));
          } else if (_isDigit(oldCh) && _isDigit(newCh)) {
            cells.add(_rollingDigit(oldCh, newCh, roll, style, digitW, lineH));
          } else {
            cells.add(_swapCell(oldCh, newCh, roll, style, digitW, lineH));
          }
        }

        return Transform.scale(
          scale: scale,
          child: SizedBox(
            height: lineH + 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥 ', style: TextStyle(fontSize: 20)),
                  ...cells,
                  Text(' ${appState.weightLabel}', style: style),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _staticCell(String ch, TextStyle style, double digitW, double lineH) {
    return SizedBox(
      width: _charW(ch, style, digitW),
      height: lineH,
      child: Text(ch, style: style, textAlign: TextAlign.center),
    );
  }

  /// Барабан одной цифры: пролетают все промежуточные значения сверху вниз.
  Widget _rollingDigit(String oldCh, String newCh, double progress,
      TextStyle style, double digitW, double lineH) {
    final oldD = int.parse(oldCh);
    final newD = int.parse(newCh);
    final steps = (newD - oldD) % 10 == 0 ? 10 : (newD - oldD) % 10;
    return SizedBox(
      width: digitW,
      height: lineH,
      child: ClipRect(
        child: Stack(
          children: [
            for (var k = 0; k <= steps; k++)
              Positioned(
                top: lineH * (progress * steps - k),
                left: 0,
                right: 0,
                height: lineH,
                child: Text('${(oldD + k) % 10}',
                    style: style, textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }

  /// Нечисловой символ (запятая, новый разряд): мягкая смена сверху вниз.
  /// Ширина обязательна: Stack только с Positioned-детьми иначе растянется.
  Widget _swapCell(String oldCh, String newCh, double progress, TextStyle style,
      double digitW, double lineH) {
    return SizedBox(
      width: _charW(newCh, style, digitW),
      height: lineH,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              top: lineH * progress,
              left: 0,
              right: 0,
              child: Text(oldCh, style: style, textAlign: TextAlign.center),
            ),
            Positioned(
              top: -lineH * (1 - progress),
              left: 0,
              right: 0,
              child: Text(newCh, style: style, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}
