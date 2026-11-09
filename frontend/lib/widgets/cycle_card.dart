import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/cycle_edit_screen.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'day_neck.dart';
import 'haptics.dart';
import 'set_box.dart';

/// Карточка цикла на главной вкладке: чипы дней, шейка, панель подходов.
class CycleCard extends StatefulWidget {
  final Cycle cycle;
  final Color accent;
  const CycleCard({super.key, required this.cycle, required this.accent});

  @override
  State<CycleCard> createState() => _CycleCardState();
}

class _CycleCardState extends State<CycleCard>
    with SingleTickerProviderStateMixin {
  static const double chipH = 34;
  static const double chipGap = 6;
  static const double panelGap = 8; // зазор между рядом чипов и панелью

  late int _sel = widget.cycle.curDay.clamp(0, widget.cycle.days.length - 1);
  late int _prev = _sel;
  late int _lastCurDay = widget.cycle.curDay;

  /// Двухфазная анимация смены дня: 0–0,5 старые подходы уезжают, 0,5–1 новые выезжают.
  late final AnimationController _swap = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200));

  @override
  void dispose() {
    _swap.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _sel) return;
    setState(() {
      _prev = _sel;
      _sel = i;
    });
    _swap.forward(from: 0);
  }

  /// Выбор дня чипом — просто просмотр, без диалогов.
  void _requestDay(int i) {
    hapticTick();
    _select(i);
  }

  /// «Начать»: если выбран не текущий (в т. ч. уже пройденный) день —
  /// сначала предупреждение и подтверждение смены дня цикла.
  Future<void> _start() async {
    hapticTick();
    final c = widget.cycle;
    if (_sel != c.curDay) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Вы уверены, что хотите начать день ${_sel + 1}?'),
          content: Text('Текущий день цикла — ${c.curDay + 1}'),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('future-day-no'),
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Нет'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('future-day-yes'),
                    onPressed: () => Navigator.pop(ctx, true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD06060),
                      side: const BorderSide(
                          color: Color(0xFFA03030), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Да'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      if (accepted != true) return;
      c.curDay = _sel;
      _lastCurDay = _sel;
      appState.touch();
    }
    appState.startCycleDay(c);
  }

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CycleEditScreen(cycle: widget.cycle)));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cycle;
    // внешнее изменение curDay (завершение/отмена в дневнике) — снапим выбор на текущий день
    if (c.curDay != _lastCurDay) {
      _lastCurDay = c.curDay;
      _prev = _sel = c.curDay.clamp(0, c.days.length - 1);
      _swap.value = 1;
    }
    final accent = widget.accent;
    final accentDim = AppColors.accentDim(accent);
    final n = c.days.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // название + огонёк + бейдж
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(appState.exerciseName(c.exerciseId, c.name),
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    GestureDetector(
                      onTap: () => _openEditor(context),
                      child: FlameLabel(
                          text:
                              '${fmtW(appState.weightFromKg(c.bestW))}×${c.bestR} | ${fmtW(appState.weightFromKg(c.tm))} ${appState.weightLabel}'),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: accentDim, borderRadius: BorderRadius.circular(20)),
                child: Text('День ${c.curDay + 1} / $n',
                    style: TextStyle(
                        fontSize: 12,
                        color: accent,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // чипы дней + шейка + панель подходов
          LayoutBuilder(builder: (context, cons) {
            final w = cons.maxWidth;
            final chipW = (w - chipGap * (n - 1)) / n;
            final selLeft = _sel * (chipW + chipGap);
            final isFirst = _sel == 0;
            final isLast = _sel == n - 1;

            final panel = Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentDim,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isFirst ? 0 : 12),
                  topRight: Radius.circular(isLast ? 0 : 12),
                  bottomLeft: const Radius.circular(12),
                  bottomRight: const Radius.circular(12),
                ),
              ),
              child: AnimatedBuilder(
                animation: _swap,
                builder: (context, _) {
                  final t = _swap.value;
                  final out = t < 0.5; // фаза уезжания / выезжания
                  final p = out ? t * 2 : (t - 0.5) * 2;
                  final dayIdx = out ? _prev : _sel;
                  final toBigger = _sel >
                      _prev; // новые прилетают слева, старые уезжают вправо
                  // максимальный сдвиг — 1/5 ширины плашки подхода
                  final tileW = (w - 20 - 8 * 3) / 4;
                  final maxDx = tileW / 5;
                  final dx = out
                      ? (toBigger ? maxDx : -maxDx) * p
                      : (toBigger ? -maxDx : maxDx) * (1 - p);
                  return Opacity(
                    opacity: (out ? 1 - p : p).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(dx, 0),
                      child: SetFlow(sets: [
                        for (final s in c.days[dayIdx].sets)
                          SetBoxData(
                              w: setWeight(c, s), reps: s.reps, rir: s.rir),
                      ]),
                    ),
                  );
                },
              ),
            );

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Column(children: [
                  const SizedBox(height: chipH),
                  const SizedBox(height: panelGap),
                  panel,
                ]),
                // шейка (под пилюлей)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.ease,
                  left: selLeft - NeckPainter.r,
                  top: chipH / 2,
                  width: chipW + NeckPainter.r * 2,
                  height: chipH / 2 + panelGap,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: NeckPainter(
                          color: accentDim, edgeL: isFirst, edgeR: isLast),
                    ),
                  ),
                ),
                // пилюля выделения
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.ease,
                  left: selLeft,
                  top: 0,
                  width: chipW,
                  height: chipH,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                // чипы
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: chipH,
                  child: Row(children: [
                    for (var i = 0; i < n; i++) ...[
                      if (i > 0) const SizedBox(width: chipGap),
                      Expanded(child: _chip(c, i, accent)),
                    ],
                  ]),
                ),
              ],
            );
          }),
          const SizedBox(height: 14),
          // кнопки
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () => _openEditor(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Изменить', style: TextStyle(fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: _start,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Начать',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _chip(Cycle c, int i, Color accent) {
    final sel = i == _sel;
    final missed =
        i < c.curDay; // пока без дневника: прошедшие дни — пропущенные
    final next = i == c.curDay && !sel;
    return GestureDetector(
      onTap: () => _requestDay(i),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: sel
                  ? Colors.transparent
                  : (next ? accent : AppColors.border)),
        ),
        child: Text(
          dayChipLabel(c, i),
          maxLines: 1,
          style: TextStyle(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
            color: sel
                ? Colors.black
                : (next
                    ? accent
                    : (missed ? const Color(0xFF666666) : AppColors.textDim)),
            decoration: missed && !sel ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}

/// Огонёк с градиентным текстом и мерцанием.
class FlameLabel extends StatefulWidget {
  final String text;
  const FlameLabel({super.key, required this.text});

  @override
  State<FlameLabel> createState() => _FlameLabelState();
}

class _FlameLabelState extends State<FlameLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) => Transform.scale(
              scale: 1 + 0.18 * _ctrl.value,
              child: Transform.rotate(
                  angle: -0.05 + 0.1 * _ctrl.value, child: child),
            ),
            child: const Text('🔥', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 3),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFFFF9D45), Color(0xFFE05A2B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(r),
            child: Text(widget.text,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
