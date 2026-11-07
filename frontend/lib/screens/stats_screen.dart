import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/strings.dart';
import '../theme.dart';
import '../widgets/set_box.dart';

const _monthsRu = [
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

class SessionMetrics {
  final String date;
  final RecordFormat format;
  final double e1rm;
  final double maxWeight;
  final double volume;
  final int maxReps;
  final int totalReps;
  final int maxDuration;
  final int totalDuration;
  final double distanceM;
  final int sets;

  const SessionMetrics({
    required this.date,
    required this.format,
    required this.e1rm,
    required this.maxWeight,
    required this.volume,
    required this.maxReps,
    required this.totalReps,
    required this.maxDuration,
    required this.totalDuration,
    required this.distanceM,
    required this.sets,
  });
}

SessionMetrics? sessionMetrics(String date, DiaryEntry e) {
  final sets = e.sets.where((s) => !s.planned).toList();
  if (sets.isEmpty) return null;
  double maxDouble(Iterable<double> values) =>
      values.fold(0.0, (a, b) => b > a ? b : a);
  final work = sets.where((s) => s.rir >= 0).toList();
  final e1rmSets = work.isEmpty ? sets : work;
  return SessionMetrics(
    date: date,
    format: e.recordFormat,
    e1rm: e.recordFormat == RecordFormat.weightReps
        ? maxDouble(
            e1rmSets.map((s) => s.w * (1 + (s.reps + s.rir.clamp(0, 6)) / 30)))
        : 0,
    maxWeight: maxDouble(sets.map((s) => s.w)),
    volume: e.recordFormat == RecordFormat.weightReps
        ? sets.fold(0.0, (a, s) => a + s.w * s.reps)
        : 0,
    maxReps: sets.fold(0, (a, s) => s.reps > a ? s.reps : a),
    totalReps: sets.fold(0, (a, s) => a + s.reps),
    maxDuration: sets.fold(0, (a, s) => s.durationSec > a ? s.durationSec : a),
    totalDuration: sets.fold(0, (a, s) => a + s.durationSec),
    distanceM: sets.fold(0.0, (a, s) => a + s.distanceM),
    sets: sets.length,
  );
}

List<(String, DiaryEntry)> entriesFor(String exerciseId) {
  final out = <(String, DiaryEntry)>[];
  final keys = appState.log.keys.toList()..sort();
  for (final key in keys) {
    for (final e in appState.log[key]!) {
      if (e.exerciseId == exerciseId) out.add((key, e));
    }
  }
  return out;
}

class MetricDef {
  final String key;
  final String ru;
  final String en;
  const MetricDef(this.key, this.ru, this.en);
  String label() => appState.language == 'en' ? en : ru;
}

List<MetricDef> metricsFor(RecordFormat format) => switch (format) {
      RecordFormat.weightReps => const [
          MetricDef(
              'e1rm', 'Расчётный разовый максимум', 'Estimated one-rep max'),
          MetricDef('maxw', 'Максимальный сделанный вес', 'Max weight'),
          MetricDef('vol', 'Объём (тоннаж) тренировки', 'Workout volume'),
          MetricDef('maxr', 'Макс. повторений', 'Max reps'),
        ],
      RecordFormat.weightTime => const [
          MetricDef('maxw', 'Максимальный вес', 'Max weight'),
          MetricDef('maxdur', 'Максимальное время', 'Max duration'),
          MetricDef('time', 'Суммарное время', 'Total duration'),
        ],
      RecordFormat.timeReps => const [
          MetricDef('maxr', 'Макс. повторений', 'Max reps'),
          MetricDef('reps', 'Всего повторений', 'Total reps'),
          MetricDef('maxdur', 'Максимальное время', 'Max duration'),
          MetricDef('time', 'Суммарное время', 'Total duration'),
        ],
      RecordFormat.timeDistance => const [
          MetricDef('distance', 'Дистанция', 'Distance'),
          MetricDef('time', 'Время', 'Duration'),
          MetricDef('pace', 'Темп', 'Pace'),
          MetricDef('speed', 'Скорость', 'Speed'),
        ],
    };

double metricValue(SessionMetrics p, String key) {
  final distance = appState.distanceFromMeters(p.distanceM);
  final hours = p.totalDuration / 3600;
  return switch (key) {
    'e1rm' => appState.weightFromKg(p.e1rm),
    'maxw' => appState.weightFromKg(p.maxWeight),
    'vol' => appState.weightFromKg(p.volume),
    'maxr' => p.maxReps.toDouble(),
    'reps' => p.totalReps.toDouble(),
    'maxdur' => p.maxDuration.toDouble(),
    'time' => p.totalDuration.toDouble(),
    'distance' => distance,
    'pace' => distance > 0 ? p.totalDuration / distance : 0,
    'speed' => hours > 0 ? distance / hours : 0,
    _ => 0,
  };
}

String metricUnit(String key) => switch (key) {
      'e1rm' || 'maxw' || 'vol' => appState.weightLabel,
      'maxdur' || 'time' => '',
      'distance' => appState.distanceLabel,
      'pace' => 'мин/${appState.distanceLabel}',
      'speed' => '${appState.distanceLabel}/ч',
      _ => '',
    };

String formatMetric(double value, String key) {
  if (key == 'maxdur' || key == 'time') return fmtDuration(value.round());
  if (key == 'pace') {
    final seconds = value.round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
  final rounded = (value * 10).roundToDouble() / 10;
  return rounded == rounded.truncateToDouble()
      ? rounded.truncate().toString()
      : rounded.toStringAsFixed(1).replaceAll('.', ',');
}

const _periods = [
  ('1 мес', 30),
  ('3 мес', 90),
  ('6 мес', 183),
  ('1 год', 365),
  ('Всё', 36500)
];

class StatsListScreen extends StatelessWidget {
  final bool embedded;
  const StatsListScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final accent = appState.accent;
    final all = appState.log.values.expand((x) => x).toList();
    final ids = <String>{for (final e in all) e.exerciseId}.toList();
    ids.sort((a, b) {
      final ac = appState.cycles.any((c) => c.exerciseId == a);
      final bc = appState.cycles.any((c) => c.exerciseId == b);
      if (ac != bc) return ac ? -1 : 1;
      return appState.exerciseName(a).compareTo(appState.exerciseName(b));
    });
    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (embedded)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(tr('stats'),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
        if (ids.isEmpty)
          Text(tr('noData'), style: const TextStyle(color: AppColors.textDim)),
        for (final id in ids)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => StatsDetailScreen(
                      exerciseId: id, name: appState.exerciseName(id)))),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(appState.exerciseName(id),
                            style: const TextStyle(fontSize: 15))),
                    if (appState.cycles.any((c) => c.exerciseId == id))
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                            color: AppColors.accentDim(accent),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('в цикле',
                            style: TextStyle(fontSize: 12, color: accent)),
                      )
                    else
                      Text(
                          '${all.where((e) => e.exerciseId == id).length} трен.',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textDim)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    if (embedded) return body;
    return Scaffold(
        appBar: AppBar(leading: const BackButton(), title: Text(tr('stats'))),
        body: body);
  }
}

class StatsDetailScreen extends StatefulWidget {
  final String exerciseId;
  final String name;
  const StatsDetailScreen(
      {super.key, required this.exerciseId, required this.name});

  @override
  State<StatsDetailScreen> createState() => _StatsDetailScreenState();
}

class _StatsDetailScreenState extends State<StatsDetailScreen> {
  late RecordFormat format = appState.exerciseById(widget.exerciseId)?.format ??
      RecordFormat.weightReps;
  late String metric = metricsFor(format).first.key;
  int period = 90;
  bool history = false;
  bool metricOpen = false;

  @override
  Widget build(BuildContext context) {
    final accent = appState.accent;
    final all = entriesFor(widget.exerciseId);
    final cutoff = DateTime.now().subtract(Duration(days: period));
    final points = [
      for (final (key, entry) in all)
        if (DateTime.parse(key).isAfter(cutoff) &&
            sessionMetrics(key, entry) != null)
          sessionMetrics(key, entry)!,
    ];
    final defs = metricsFor(format);
    if (!defs.any((d) => d.key == metric)) metric = defs.first.key;
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: Text(widget.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              for (final (i, label) in [tr('stats'), tr('history')].indexed)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 0 ? 8 : 0),
                    child: InkWell(
                      onTap: () => setState(() => history = i == 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color:
                              history == (i == 1) ? accent : AppColors.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: history == (i == 1)
                                      ? Colors.black
                                      : AppColors.textDim)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!history) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final (label, days) in _periods)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              onTap: () => setState(() => period = days),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: period == days
                                      ? accent
                                      : AppColors.surface2,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Center(
                                  child: Text(label,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: period == days
                                              ? Colors.black
                                              : AppColors.textDim)),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, cons) => CustomPaint(
                      size: Size(cons.maxWidth, cons.maxWidth * 200 / 360),
                      painter: _ChartPainter(
                          points: points, metric: metric, accent: accent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() => metricOpen = !metricOpen),
                          child: Padding(
                            padding: const EdgeInsets.all(11),
                            child: Center(
                                child: Text(
                                    '${defs.firstWhere((d) => d.key == metric).label()} ▾')),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: metricOpen
                              ? Column(children: [
                                  for (final def in defs)
                                    InkWell(
                                      onTap: () => setState(() {
                                        metric = def.key;
                                        metricOpen = false;
                                      }),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(11),
                                        decoration: const BoxDecoration(
                                            border: Border(
                                                top: BorderSide(
                                                    color: AppColors.border))),
                                        child: Center(
                                          child: Text(def.label(),
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: metric == def.key
                                                      ? accent
                                                      : AppColors.textDim)),
                                        ),
                                      ),
                                    ),
                                ])
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildTiles(all, accent),
          ] else
            _buildHistory(all),
        ],
      ),
    );
  }

  Widget _buildTiles(List<(String, DiaryEntry)> all, Color accent) {
    final metrics = [
      for (final (k, e) in all)
        if (sessionMetrics(k, e) != null) sessionMetrics(k, e)!
    ];
    if (metrics.isEmpty) {
      return Text(tr('noData'),
          style: const TextStyle(color: AppColors.textDim));
    }
    final defs = metricsFor(format);
    String date(String value) =>
        '${value.substring(8, 10)}.${value.substring(5, 7)}.${value.substring(0, 4)}';
    SessionMetrics best(String key) => metrics
        .reduce((a, b) => metricValue(b, key) > metricValue(a, key) ? b : a);
    final tiles = <(String, String, String)>[
      for (final def in defs.take(4))
        (
          def.label(),
          '${formatMetric(metricValue(best(def.key), def.key), def.key)} ${metricUnit(def.key)}'
              .trim(),
          date(best(def.key).date)
        ),
      (
        'Всего повторений',
        '${metrics.fold(0, (a, p) => a + p.totalReps)}',
        'за всё время'
      ),
      (
        'Всего подходов',
        '${metrics.fold(0, (a, p) => a + p.sets)}',
        'за всё время'
      ),
      (
        format == RecordFormat.timeDistance
            ? 'Общая дистанция'
            : format == RecordFormat.weightReps
                ? 'Общий объём'
                : 'Общее время',
        format == RecordFormat.timeDistance
            ? '${fmtW(appState.distanceFromMeters(metrics.fold(0.0, (a, p) => a + p.distanceM)))} ${appState.distanceLabel}'
            : format == RecordFormat.weightReps
                ? '${fmtW(appState.weightFromKg(metrics.fold(0.0, (a, p) => a + p.volume)))} ${appState.weightLabel}'
                : fmtDuration(metrics.fold(0, (a, p) => a + p.totalDuration)),
        'за всё время'
      ),
      ('Всего тренировок', '${metrics.length}', 'за всё время'),
    ];
    return GridView(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 104,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final (label, value, subtitle) in tiles)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textDim)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: accent)),
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textDim)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHistory(List<(String, DiaryEntry)> all) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return Column(children: [
      for (final (key, entry) in all.reversed)
        Builder(builder: (context) {
          final date = DateTime.parse(key);
          final ago = start.difference(date).inDays;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${date.day} ${_monthsRu[date.month - 1]}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              Text(
                  ago == 0
                      ? 'сегодня'
                      : ago == 1
                          ? 'вчера'
                          : '$ago дн. назад',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textDim)),
              const SizedBox(height: 12),
              SetFlow(sets: [
                for (final set in entry.sets)
                  SetBoxData(
                    w: set.w,
                    reps: set.reps,
                    rir: set.rir,
                    durationSec: set.durationSec,
                    distanceM: set.distanceM,
                    format: entry.recordFormat,
                    planned: set.planned,
                  ),
              ]),
            ]),
          );
        }),
    ]);
  }
}

class _ChartPainter extends CustomPainter {
  final List<SessionMetrics> points;
  final String metric;
  final Color accent;
  const _ChartPainter(
      {required this.points, required this.metric, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    canvas.scale(size.width / 360);
    const width = 360.0,
        height = 200.0,
        left = 36.0,
        right = 8.0,
        top = 8.0,
        bottom = 20.0;
    final values = [for (final p in points) metricValue(p, metric)];
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min != 0
        ? max - min
        : (max.abs() * 0.1 != 0 ? max.abs() * 0.1 : 1.0);
    final span = range / 0.5;
    final lo = min - span * 0.4, hi = max + span * 0.1;
    double x(int i) =>
        left +
        (points.length == 1
            ? (width - left - right) / 2
            : i * (width - left - right) / (points.length - 1));
    double y(double v) => top + (hi - v) / (hi - lo) * (height - top - bottom);
    final spread = hi - lo;
    final ladder = metric == 'vol' || metric == 'time' || metric == 'maxdur'
        ? [10.0, 20, 50, 100, 200, 500, 1000, 2000, 5000]
        : metric == 'maxr' || metric == 'reps'
            ? spread < 10
                ? [1.0, 2, 4]
                : spread < 20
                    ? [2.0, 4, 10]
                    : [5.0, 10, 20, 50]
            : [2.5, 5, 10, 25, 50, 100];
    final step =
        ladder.firstWhere((s) => spread / s <= 20, orElse: () => ladder.last);
    final lines = spread / step;
    final every = lines > 20
        ? 5
        : lines > 10
            ? 2
            : 1;
    final grid = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 0.7;
    const style = TextStyle(fontSize: 9, color: Color(0xFF777777));
    final k0 = (lo / step - 1e-9).ceil(), k1 = (hi / step + 1e-9).floor();
    for (var k = k0; k <= k1; k++) {
      final value = (k * step * 100).roundToDouble() / 100;
      final gy = y(value);
      canvas.drawLine(Offset(left, gy), Offset(width - right, gy), grid);
      if ((k - k0) % every == 0) {
        _text(canvas, formatMetric(value, metric), Offset(left - 5, gy), style,
            alignRight: true);
      }
    }
    final indexes = <int>{
      0,
      ((points.length - 1) * .25).round(),
      ((points.length - 1) * .5).round(),
      ((points.length - 1) * .75).round(),
      points.length - 1
    };
    for (final i in indexes) {
      final date = points[i].date;
      _text(canvas, '${date.substring(8, 10)}.${date.substring(5, 7)}',
          Offset(x(i), height - 8), style,
          center: true);
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final point = Offset(x(i), y(values[i]));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = accent
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke);
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(x(i), y(values[i])), 4, Paint()..color = accent);
    }
  }

  void _text(Canvas canvas, String value, Offset at, TextStyle style,
      {bool alignRight = false, bool center = false}) {
    final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr)
      ..layout();
    final dx = alignRight
        ? at.dx - painter.width
        : center
            ? at.dx - painter.width / 2
            : at.dx;
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points || old.metric != metric || old.accent != accent;
}
