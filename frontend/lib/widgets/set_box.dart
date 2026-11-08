import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'dashed_border.dart';

const pillColors = [
  Color(0xFF8A3030),
  Color(0xFF96422E),
  Color(0xFF9C6A24),
  Color(0xFF8A7F2A),
  Color(0xFF2F8A70),
  Color(0xFF2E7D9E),
  Color(0xFF4F87A8),
];
const pillWarm = Color(0xFF4A4A4A);

class SetBoxData {
  final double w;
  final int reps;
  final int rir;
  final int durationSec;
  final double distanceM;
  final RecordFormat format;
  final int? pct;
  final bool pctApprox;
  final bool planned;

  const SetBoxData({
    this.w = 0,
    this.reps = 0,
    this.rir = 0,
    this.durationSec = 0,
    this.distanceM = 0,
    this.format = RecordFormat.weightReps,
    this.pct,
    this.pctApprox = false,
    this.planned = false,
  });
}

class SetFlow extends StatelessWidget {
  final List<SetBoxData> sets;
  final void Function(int index)? onSetTap;
  const SetFlow({super.key, required this.sets, this.onSetTap});

  static const double gap = 8;

  bool get _compact {
    if (sets.length != 5) return false;
    return sets
        .every((s) => _value(s).replaceAll(RegExp(r'\D'), '').length <= 5);
  }

  static String _value(SetBoxData s) {
    final weight = fmtW(appState.weightFromKg(s.w));
    final distance = fmtW(appState.distanceFromMeters(s.distanceM));
    return switch (s.format) {
      RecordFormat.weightReps => '$weight×${s.reps}',
      RecordFormat.weightTime => '$weight×${fmtDuration(s.durationSec)}',
      RecordFormat.timeReps => '${fmtDuration(s.durationSec)}×${s.reps}',
      RecordFormat.timeDistance => '${fmtDuration(s.durationSec)}×$distance',
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final compact = _compact;
      final itemW = compact
          ? (cons.maxWidth - gap * 4) / 5
          : (cons.maxWidth - gap * 3) / 4;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < sets.length; i++)
            SizedBox(
              width: itemW,
              child: GestureDetector(
                onTap: onSetTap == null ? null : () => onSetTap!(i),
                child: SetBox(data: sets[i], compact: compact),
              ),
            ),
        ],
      );
    });
  }
}

class SetBox extends StatelessWidget {
  final SetBoxData data;
  final bool compact;
  const SetBox({super.key, required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    // Плановый подход цикла: серая пунктирная обводка и серая RIR-плашка.
    // После сохранения подхода обводка сплошная, плашка — в цвет RIR.
    final box = Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border:
            data.planned ? null : Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SetValueText(data: data, compact: compact),
          if (data.pct != null)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text('${data.pctApprox ? '~' : ''}${data.pct}%',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textDim)),
            ),
          const SizedBox(height: 4),
          if (data.format.usesRir)
            RirPill(code: data.rir, gray: data.planned),
        ],
      ),
    );
    if (data.planned) {
      return Opacity(
        opacity: 0.75,
        child: DashedBorder(
            color: const Color(0xFF666666), radius: 12, child: box),
      );
    }
    return Opacity(opacity: data.rir == -1 ? 0.5 : 1, child: box);
  }
}

class SetValueText extends StatelessWidget {
  final SetBoxData data;
  final bool compact;
  const SetValueText({super.key, required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final text = SetFlow._value(data);
    final digits = text.replaceAll(RegExp(r'\D'), '').length;
    final separator = data.format == RecordFormat.timeDistance
        ? ' · '
        : (digits >= 5 ? '×' : ' × ');
    final parts = text.split('×');
    final shown = parts.length == 2 ? '${parts[0]}$separator${parts[1]}' : text;
    final style = digits >= 7 || data.format == RecordFormat.timeDistance
        ? const TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: -0.8)
        : digits >= 5
            ? const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.5)
            : const TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(shown, maxLines: 1, style: style),
    );
  }
}

class RirPill extends StatelessWidget {
  final int code;
  final bool gray;
  const RirPill({super.key, required this.code, this.gray = false});

  @override
  Widget build(BuildContext context) {
    final bg =
        (gray || code == -1) ? pillWarm : pillColors[code.clamp(0, 6)];
    return Container(
      height: 20,
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            rirLabel(code),
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.15),
          ),
        ),
      ),
    );
  }
}
