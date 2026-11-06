import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/cycles_screen.dart';
import 'screens/diary_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/templates_screen.dart';
import 'state/app_state.dart';
import 'state/persistence.dart';
import 'state/strings.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initPersistence();
  appState.tabIndex = int.tryParse(Uri.base.queryParameters['tab'] ?? '') ?? 0;
  runApp(const WorkoutTrackerApp());
}

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => MaterialApp(
        title: 'Workout Tracker',
        debugShowCheckedModeBanner: false,
        locale: Locale(appState.language),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.dark(accent: appState.accent),
        home: switch (Uri.base.queryParameters['screen']) {
          'stats' => const StatsListScreen(),
          'stats-detail' => Builder(builder: (context) {
              final exercise = appState.exerciseByName(
                      Uri.base.queryParameters['ex'] ?? 'Жим лёжа') ??
                  appState.exercises.first;
              return StatsDetailScreen(
                  exerciseId: exercise.id,
                  name: exercise.name(appState.language));
            }),
          _ => const MainShell(),
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final PageController _controller =
      PageController(initialPage: appState.tabIndex);

  static const _screens = [
    CyclesScreen(),
    TemplatesScreen(),
    DiaryScreen(),
    StatsListScreen(embedded: true),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    appState.addListener(_syncTab);
  }

  void _syncTab() {
    if (!_controller.hasClients) return;
    final current = _controller.page?.round() ?? appState.tabIndex;
    if (current != appState.tabIndex) {
      _controller.animateToPage(
        appState.tabIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    appState.removeListener(_syncTab);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: PageView(
            controller: _controller,
            onPageChanged: appState.goToTab,
            children: _screens,
          ),
        ),
        bottomNavigationBar: _AnimatedNavBar(controller: _controller),
      ),
    );
  }
}

class _AnimatedNavBar extends StatelessWidget {
  final PageController controller;
  const _AnimatedNavBar({required this.controller});

  static const _items = [
    (Icons.repeat, 'cycles'),
    (Icons.view_list_outlined, 'templates'),
    (Icons.calendar_month_outlined, 'diary'),
    (Icons.bar_chart_outlined, 'stats'),
    (Icons.settings_outlined, 'settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = appState.accent;
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, cons) {
            final itemWidth = cons.maxWidth / _items.length;
            return AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final page = controller.hasClients
                    ? controller.page ?? appState.tabIndex.toDouble()
                    : appState.tabIndex.toDouble();
                return SizedBox(
                  height: 68,
                  child: Stack(
                    children: [
                      Positioned(
                        left: page * itemWidth + 6,
                        top: 7,
                        width: itemWidth - 12,
                        height: 54,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                      ),
                      Row(children: [
                        for (var i = 0; i < _items.length; i++)
                          Expanded(
                            child: InkWell(
                              onTap: () => appState.goToTab(i),
                              borderRadius: BorderRadius.circular(13),
                              child: SizedBox(
                                height: 68,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(_items[i].$1,
                                        size: 20,
                                        color: (page - i).abs() < .5
                                            ? Colors.black
                                            : AppColors.textDim),
                                    const SizedBox(height: 3),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        tr(_items[i].$2),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: (page - i).abs() < .5
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: (page - i).abs() < .5
                                              ? Colors.black
                                              : AppColors.textDim,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
