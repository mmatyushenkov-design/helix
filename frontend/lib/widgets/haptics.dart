import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

/// Короткий, но отчётливый виброимпульс (сильнее клавиатурного selectionClick).
/// Вызовы чаще, чем раз в 90 мс, игнорируются: одно нажатие — один импульс,
/// даже если обработчик сработал и глобально, и локально.
void hapticTick() {
  final now = DateTime.now();
  if (now.difference(_lastTick).inMilliseconds < 90) return;
  _lastTick = now;
  HapticFeedback.lightImpact();
}

/// Глобальная виброотдача на любое нажатие интерактивного элемента:
/// кнопки, плашки, пункты списков, дропдауны и т. д. Определяет короткий
/// тап без сдвига над виджетом с обработчиком жестов; свайпы и скролл
/// отдачи не дают.
class HapticTapScope extends StatefulWidget {
  final Widget child;
  const HapticTapScope({super.key, required this.child});

  @override
  State<HapticTapScope> createState() => _HapticTapScopeState();
}

class _HapticTapScopeState extends State<HapticTapScope> {
  Offset? _downPos;
  int _downMs = 0;
  bool _tappable = false;

  void _onDown(PointerDownEvent event) {
    _downPos = event.position;
    _downMs = event.timeStamp.inMilliseconds;
    _tappable = false;
    final result = HitTestResult();
    RendererBinding.instance
        .hitTestInView(result, event.position, View.of(context).viewId);
    for (final entry in result.path) {
      if (entry.target is RenderPointerListener) {
        _tappable = true;
        break;
      }
    }
  }

  void _onUp(PointerUpEvent event) {
    final down = _downPos;
    if (down == null) return;
    final moved = (event.position - down).distance;
    final elapsed = event.timeStamp.inMilliseconds - _downMs;
    if (_tappable && moved < 12 && elapsed < 400) hapticTick();
    _downPos = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: (_) => _downPos = null,
      child: widget.child,
    );
  }
}
