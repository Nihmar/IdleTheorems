import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';

import '../providers/game_state_provider.dart';
import '../ui/theme/palette.dart';

/// Main game surface: the paper board background.
///
/// All gameplay logic lives in systems behind [GameStateNotifier]; this class
/// only binds the Riverpod container, forwards taps/clicks and advances the
/// simulation tick (plan section 10). Decorative content (title, chalk
/// formulas) is rendered by the Flutter overlay so it can use real KaTeX.
class IdleGame extends FlameGame with RiverpodGameMixin, TapCallbacks {
  GameStateNotifier? _notifier;

  /// Paints reused across frames (plan section 10: no per-frame allocation).
  late final Paint _paperPaint = Paint()..color = Palette.paper;
  late final Paint _gridPaint = Paint()
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke
    ..color = Palette.gridLine;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    addToGameWidgetBuild(() {
      _notifier ??= ref.read(gameStateProvider.notifier);
    });
  }

  @override
  void onTapUp(TapUpEvent event) {
    _notifier?.solveExercise();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _notifier?.tick(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final h = size.y;
    // Paper board.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _paperPaint);
    // Faint grid.
    const step = 64.0;
    for (double x = step; x < w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), _gridPaint);
    }
    for (double y = step; y < h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), _gridPaint);
    }
  }
}
