import 'dart:async';

import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/models/resources.dart';
import 'domain/models/game_state.dart';
import 'domain/services/offline_service.dart';
import 'domain/services/save_service.dart';
import 'domain/services/subject_service.dart';
import 'game/idle_game.dart';
import 'providers/game_state_provider.dart';
import 'ui/overlays/main_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Persistence first: load save, apply offline earnings, wire saves back.
  final saveService = SaveService();
  await saveService.init();

  GameState state = GameState();
  Resources? offlineGains;
  try {
    final loaded = await saveService.load();
    if (loaded != null) {
      state = GameState.fromSave(loaded);
      final mods = const SubjectService().modifiers(state);
      final report = const OfflineService().compute(
        loaded,
        DateTime.now(),
        capMultiplier: mods.offlineCapMult,
        mods: mods,
      );
      offlineGains = report.gained;
    }
  } catch (e) {
    // Corrupt save: start fresh instead of bricking the app.
    debugPrint('Failed to load save, starting fresh: $e');
    state = GameState();
  }

  final notifier = container.read(gameStateProvider.notifier);
  notifier.bootstrap(state, offlineGains: offlineGains);
  notifier.setSaveHook(() => saveService.save(notifier.snapshotForSave()));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: IdleTheoremsApp(
        saveNow: () => saveService.save(
            container.read(gameStateProvider.notifier).snapshotForSave()),
        onResumed: (awaySince) {
          final n = container.read(gameStateProvider.notifier);
          n.applyAwayEarnings(n.snapshotForSave(awaySince), DateTime.now());
        },
      ),
    ),
  );
}

class IdleTheoremsApp extends StatelessWidget {
  const IdleTheoremsApp({required this.saveNow, required this.onResumed, super.key});

  /// Persists the current state (used by autosave + lifecycle hooks).
  final Future<void> Function() saveNow;

  /// Credits away time when the app returns to the foreground.
  final void Function(DateTime awaySince) onResumed;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Idle Theorems',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: GameScreen(saveNow: saveNow, onResumed: onResumed),
    );
  }
}

/// Hosts the Flame surface plus Flutter overlays, and owns the persistence
/// timers: autosave every 60s while foreground, immediate save on pause
/// (plan section 14.5), and away-time crediting on resume (section 13.10).
class GameScreen extends StatefulWidget {
  const GameScreen({required this.saveNow, required this.onResumed, super.key});

  final Future<void> Function() saveNow;

  /// Invoked when the app comes back to the foreground with the moment it
  /// left; the caller credits that gap at offline rate.
  final void Function(DateTime awaySince) onResumed;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final Timer _autosave;
  late final GlobalKey<RiverpodAwareGameWidgetState<IdleGame>> _gameKey;
  late final IdleGame _game;
  DateTime? _awaySince;

  @override
  void initState() {
    super.initState();
    _gameKey = GlobalKey<RiverpodAwareGameWidgetState<IdleGame>>();
    _game = IdleGame();
    _autosave = Timer.periodic(const Duration(seconds: 60), (_) {
      widget.saveNow();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosave.cancel();
    widget.saveNow();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Keep the earliest departure timestamp across hidden->paused hops.
        _awaySince ??= DateTime.now();
        widget.saveNow();
      case AppLifecycleState.resumed:
        if (_awaySince != null) {
          widget.onResumed(_awaySince!);
          _awaySince = null;
        }
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RiverpodAwareGameWidget<IdleGame>(
        game: _game,
        key: _gameKey,
        initialActiveOverlays: const ['main'],
        overlayBuilderMap: <String, OverlayWidgetBuilder<IdleGame>>{
          'main': (context, game) => const MainOverlay(),
        },
      ),
    );
  }
}
