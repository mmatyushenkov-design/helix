import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'keypad.dart';
import 'rir_slider.dart';

enum SetSheetMode { editCycle, newCycleSet, tmCalc, newSet, editSet }

class SetSheetResult {
  final CycleSet? set;
  final bool deleted;
  final double? tm;
  final double? bestW;
  final int? bestR;
  const SetSheetResult(
      {this.set, this.deleted = false, this.tm, this.bestW, this.bestR});
}

Future<SetSheetResult?> showSetSheet(
  BuildContext context, {
  required SetSheetMode mode,
  Cycle? cycle,
  CycleSet? initial,
  RecordFormat format = RecordFormat.weightReps,
}) {
  return showModalBottomSheet<SetSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      top: false,
      child:
          _SetSheet(mode: mode, cycle: cycle, initial: initial, format: format),
    ),
  );
}

enum _Field { weight, reps, pct, duration, distance }

class _SetSheet extends StatefulWidget {
  final SetSheetMode mode;
  final Cycle? cycle;
  final CycleSet? initial;
  final RecordFormat format;
  const _SetSheet(
      {required this.mode, this.cycle, this.initial, required this.format});

  @override
  State<_SetSheet> createState() => _SetSheetState();
}

class _SetSheetState extends State<_SetSheet> {
  late String _wBuf;
  late String _rBuf;
  late String _pctBuf;
  late String _timeBuf;
  late String _distBuf;
  _Field? _target;
  bool _approxW = false;
  bool _approxP = false;
  _Field _lastEdited = _Field.pct;
  int _rirIdx = 2;

  bool get _isCycle =>
      widget.mode == SetSheetMode.editCycle ||
      widget.mode == SetSheetMode.newCycleSet;
  bool get _isTm => widget.mode == SetSheetMode.tmCalc;
  bool get _isNew =>
      widget.mode == SetSheetMode.newCycleSet ||
      widget.mode == SetSheetMode.newSet;
  bool get _canDelete =>
      widget.mode == SetSheetMode.editCycle ||
      widget.mode == SetSheetMode.editSet;
  RecordFormat get _format =>
      _isCycle || _isTm ? RecordFormat.weightReps : widget.format;

  @override
  void initState() {
    super.initState();
    final c = widget.cycle;
    final s = widget.initial;
    if (_isTm && c != null) {
      _wBuf = fmtW(appState.weightFromKg(c.bestW));
      _rBuf = '${c.bestR}';
      _pctBuf = '75';
      _timeBuf = '60';
      _distBuf = '5';
      _target = _Field.weight;
    } else if (s != null && _isCycle && c != null) {
      _wBuf = fmtW(appState.weightFromKg(setWeight(c, s)));
      _rBuf = '${s.reps}';
      _timeBuf = '${s.durationSec}';
      _distBuf = fmtW(appState.distanceFromMeters(s.distanceM));
      _rirIdx = s.rir.clamp(0, 6);
      if (s.pct != null) {
        _pctBuf = '${s.pct}';
        final exact = c.tm * s.pct! / 100 + c.wOffset;
        _approxW = (setWeight(c, s) - exact).abs() > 0.001;
      } else {
        _pctBuf = '${((s.w! - c.wOffset) / c.tm * 100).round()}';
        _approxP = true;
        _lastEdited = _Field.weight;
      }
    } else if (s != null) {
      _wBuf = fmtW(appState.weightFromKg(s.w ?? 0));
      _rBuf = '${s.reps}';
      _pctBuf = '75';
      _timeBuf = '${s.durationSec}';
      _distBuf = fmtW(appState.distanceFromMeters(s.distanceM));
      _rirIdx = s.rir.clamp(0, 6);
    } else {
      _wBuf = '120';
      _rBuf = '4';
      _pctBuf = '75';
      _timeBuf = '60';
      _distBuf = '5';
    }
  }

  double _num(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0;

  String _buf(_Field f) => switch (f) {
        _Field.weight => _wBuf,
        _Field.reps => _rBuf,
        _Field.pct => _pctBuf,
        _Field.duration => _timeBuf,
        _Field.distance => _distBuf,
      };

  void _setBuf(_Field f, String value) {
    switch (f) {
      case _Field.weight:
        _wBuf = value;
      case _Field.reps:
        _rBuf = value;
      case _Field.pct:
        _pctBuf = value;
      case _Field.duration:
        _timeBuf = value;
      case _Field.distance:
        _distBuf = value;
    }
  }

  void _pressKey(String k) {
    final t = _target;
    if (t == null) return;
    var buf = _buf(t);
    if (k == '⌫') {
      buf = buf.isEmpty ? '' : buf.substring(0, buf.length - 1);
    } else if (k == ',') {
      if ((t == _Field.weight || t == _Field.distance) && !buf.contains(',')) {
        buf = '${buf.isEmpty ? '0' : buf},';
      }
    } else if (buf.replaceAll(RegExp(r'[,.]'), '').length < 7) {
      buf = (buf == '0' ? '' : buf) + k;
    }
    setState(() {
      _setBuf(t, buf);
      if (_isCycle && widget.cycle != null) {
        final c = widget.cycle!;
        if (t == _Field.pct) {
          _lastEdited = _Field.pct;
          final exact = _num(buf) * c.tm / 100 + c.wOffset;
          final rounded =
              ((exact / c.step).round() * c.step * 100).roundToDouble() / 100;
          _approxW = (rounded - exact).abs() > 0.001;
          _approxP = false;
          _wBuf = fmtW(appState.weightFromKg(rounded));
        } else if (t == _Field.weight) {
          _lastEdited = _Field.weight;
          final exactPct =
              (appState.weightToKg(_num(buf)) - c.wOffset) / c.tm * 100;
          final roundedPct = exactPct.round();
          _approxP = (roundedPct - exactPct).abs() > 0.001;
          _approxW = false;
          _pctBuf = '$roundedPct';
        }
      }
    });
  }

  double get _tmResult => roundDownToStep(
      epley(appState.weightToKg(_num(_wBuf)), int.tryParse(_rBuf) ?? 0),
      widget.cycle?.step ?? 2.5);

  void _save() {
    final r = int.tryParse(_rBuf) ?? 0;
    if (_isTm) {
      Navigator.pop(
          context,
          SetSheetResult(
              tm: _tmResult,
              bestW: appState.weightToKg(_num(_wBuf)),
              bestR: r));
      return;
    }
    final format = _format;
    final weight = format.usesWeight ? appState.weightToKg(_num(_wBuf)) : null;
    final result = CycleSet(
      w: _isCycle && _lastEdited != _Field.weight ? null : weight,
      pct: _isCycle && _lastEdited != _Field.weight
          ? int.tryParse(_pctBuf) ?? 75
          : null,
      reps: format.usesReps ? (r == 0 ? (widget.initial?.reps ?? 5) : r) : 0,
      rir: _rirIdx,
      durationSec: format.usesTime ? int.tryParse(_timeBuf) ?? 0 : 0,
      distanceM:
          format.usesDistance ? appState.distanceToMeters(_num(_distBuf)) : 0,
    );
    Navigator.pop(context, SetSheetResult(set: result));
  }

  Widget _field(_Field f, String unit) {
    final active = _target == f;
    final approx =
        f == _Field.weight ? _approxW : (f == _Field.pct ? _approxP : false);
    return GestureDetector(
      onTap: () => setState(() => _target = f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : AppColors.border,
              width: active ? 1.5 : 1),
        ),
        child: Text.rich(
          TextSpan(children: [
            if (approx) const TextSpan(text: '~'),
            TextSpan(text: _buf(f).isEmpty ? '0' : _buf(f)),
            TextSpan(
                text: unit,
                style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
          ]),
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final keypadOpen = _target != null;
    final format = _format;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isTm
                    ? 'Введите свой лучший подход'
                    : (_isNew ? 'Новый подход' : 'Изменить подход'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (format.usesWeight)
                    _field(_Field.weight, ' ${appState.weightLabel}'),
                  if (format.usesWeight)
                    const Text('×',
                        style:
                            TextStyle(fontSize: 18, color: AppColors.textDim)),
                  if (format.usesTime) _field(_Field.duration, ' с'),
                  if (format.usesTime && format.usesReps)
                    const Text('×',
                        style:
                            TextStyle(fontSize: 18, color: AppColors.textDim)),
                  if (format.usesReps) _field(_Field.reps, ''),
                  if (format.usesDistance) ...[
                    const Text('·',
                        style:
                            TextStyle(fontSize: 18, color: AppColors.textDim)),
                    _field(_Field.distance, ' ${appState.distanceLabel}'),
                  ],
                  if (_isCycle) ...[
                    const Text('·',
                        style:
                            TextStyle(fontSize: 18, color: AppColors.textDim)),
                    _field(_Field.pct, ' %'),
                  ],
                ],
              ),
              if (_isTm) ...[
                const SizedBox(height: 10),
                Text(
                    'Расчётный разовый максимум: ${fmtW(appState.weightFromKg(_tmResult))} ${appState.weightLabel}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: accent)),
              ],
              if (!_isTm && format.usesRir)
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: keypadOpen
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            children: [
                              Text(rirTexts[_rirIdx],
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: scaleColors[_rirIdx])),
                              const SizedBox(height: 12),
                              RirSlider(
                                  index: _rirIdx,
                                  onChanged: (i) =>
                                      setState(() => _rirIdx = i)),
                              const SizedBox(height: 12),
                              const Text(
                                  'Сколько повторений осталось в запасе?',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textDim)),
                            ],
                          ),
                        ),
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: keypadOpen
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: NumKeypad(onKey: _pressKey),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        if (_canDelete) {
                          Navigator.pop(
                              context, const SetSheetResult(deleted: true));
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _canDelete
                            ? const Color(0xFFD06060)
                            : AppColors.text,
                        side: BorderSide(
                            color: _canDelete
                                ? const Color(0xFFA03030)
                                : AppColors.border,
                            width: _canDelete ? 1.5 : 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_canDelete ? 'Удалить' : 'Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_isTm ? 'Применить' : 'Сохранить подход',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
