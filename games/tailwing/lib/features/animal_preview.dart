import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/readiness.dart';
import '../game/animal_roster.dart';
import '../game/combat_model.dart';
import '../game/engine.dart';
import '../game/rendering.dart';
import '../game/stages.dart';
import 'battle_hud.dart';

// No repository, account token, entitlement grant, reward or persistence.
class _PreviewLoadout implements CombatLoadout {
  const _PreviewLoadout(this.id);
  final String id;
  @override
  String selected(CatalogCategory c) => !kDebugMode
      ? const FreeLoadout().selected(c)
      : switch (c) {
          CatalogCategory.character => id,
          CatalogCategory.skill => 'signature',
          _ => const FreeLoadout().selected(c),
        };
  @override
  bool sanitize() => false;
}

class AnimalPreviewScreen extends StatefulWidget {
  const AnimalPreviewScreen({super.key});
  @override
  State<AnimalPreviewScreen> createState() => _AnimalPreviewScreenState();
}

class _AnimalPreviewScreenState extends State<AnimalPreviewScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _paint = ValueNotifier(0);
  Duration? _previous;
  BattleEngine? _game;
  String _id = 'pilot';
  int _stage = 1, _epoch = 0, _scope = 0, _hud = -1;
  bool _busy = false, _failed = false, _started = false, _scopeChanged = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((time) {
      final g = _game, old = _previous;
      _previous = time;
      if (g == null || g.phase != BattlePhase.playing) return;
      if (AppServices.of(context).campaign.scopeEpoch != _scope) {
        g.pause();
        _ticker.stop();
        setState(() => _scopeChanged = true);
        return;
      }
      if (old != null) g.step((time - old).inMicroseconds / 1000000);
      _paint.value++;
      final hud = (g.elapsed * 10).floor();
      if (hud != _hud || g.phase != BattlePhase.playing) {
        _hud = hud;
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && kDebugMode) {
      _started = true;
      _launch();
    }
  }

  Future<void> _launch() async {
    if (!kDebugMode) return;
    final token = ++_epoch, id = _id;
    _ticker.stop();
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final s = AppServices.of(context);
      await s.battleAssets.prepare();
      await s.battleAssets.preparePilot(id);
      if (!mounted || token != _epoch) return;
      setState(() {
        _game = BattleEngine(_PreviewLoadout(id), stage: stageByNumber(_stage));
        _scope = s.campaign.scopeEpoch;
        _scopeChanged = false;
        _previous = null;
        _busy = false;
        _hud = -1;
      });
      _ticker.start();
    } catch (_) {
      if (mounted && token == _epoch) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _game?.pause();
      _ticker.stop();
      _previous = null;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _epoch++;
    _ticker.dispose();
    _paint.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(body: Center(child: Text('개발 전용 화면입니다.')));
    }
    final pilot = animalPilot(_id)!, g = _game;
    return Scaffold(
      appBar: AppBar(title: const Text('테일윙 · 개발 연구소')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('무기록 전투 미리보기 · 구독을 부여하지 않습니다. 일반 플레이/계정 기록과 분리됩니다.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in animalPilots)
                  ChoiceChip(
                    key: Key('trial-${p.id}'),
                    label: Text('${p.species} ${p.name}'),
                    selected: p.id == _id,
                    onSelected: _busy
                        ? null
                        : (_) {
                            setState(() => _id = p.id);
                            _launch();
                          },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Image.asset(
                  pilot.portrait,
                  cacheWidth: 192,
                  height: 110,
                  width: 90,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pilot.name} · ${pilot.role}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                      Text(pilot.technique),
                      Text(pilot.description),
                    ],
                  ),
                ),
              ],
            ),
            if (_scopeChanged)
              const Text('계정 변경으로 시험 전투를 종료했습니다. 다시 시작할 수 있습니다.'),
            if (_busy) const LinearProgressIndicator(),
            if (_failed) const Text('이미지를 준비하지 못했습니다. 다시 시작을 눌러 재시도하세요.'),
            if (g != null && !_busy && !_failed) ...[
              BattleHud(g),
              const SizedBox(height: 10),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AspectRatio(
                    aspectRatio: 360 / 600,
                    child: GestureDetector(
                      key: const Key('trialField'),
                      onPanUpdate: (d) {
                        final render = context.findRenderObject() as RenderBox?;
                        final width =
                            (render?.size.width ?? 360).clamp(100.0, 472.0) -
                            32;
                        g.moveBy(
                          Vec(
                            d.delta.dx * 360 / width,
                            d.delta.dy * 360 / width,
                          ),
                        );
                        _paint.value++;
                      },
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: BattlePainter(
                            g,
                            null,
                            assets: AppServices.of(context).battleAssets,
                            reduceEffects:
                                AppServices.of(context)
                                    .preferences
                                    .reduceMotion ||
                                MediaQuery.disableAnimationsOf(context),
                            repaint: _paint,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('trialSkill'),
                onPressed:
                    _scopeChanged ||
                        g.cooldown > 0 ||
                        g.phase != BattlePhase.playing
                    ? null
                    : () {
                        setState(g.activateSkill);
                      },
                child: Text(
                  g.cooldown > 0
                      ? '${pilot.technique} · ${g.cooldown.ceil()}초'
                      : pilot.technique,
                ),
              ),
              Text(
                '체력 ${g.health} · ${g.phase.name} · 방향성 갑판 내구 ${g.animal.durability} · 수집 ${g.animal.captured.length}',
              ),
            ],
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                  key: const Key('trialRestart'),
                  onPressed: _busy ? null : _launch,
                  child: const Text('다시 시작'),
                ),
                OutlinedButton(
                  onPressed: g == null || _scopeChanged
                      ? null
                      : () {
                          setState(() {
                            if (g.phase == BattlePhase.paused) {
                              g.resume();
                              _previous = null;
                              _ticker.start();
                            } else {
                              g.pause();
                              _ticker.stop();
                            }
                          });
                        },
                  child: const Text('일시정지 / 계속'),
                ),
                DropdownButton<int>(
                  value: _stage,
                  items: [
                    for (final s in stages)
                      DropdownMenuItem(
                        value: s.number,
                        child: Text('작전 ${s.number}'),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _stage = value);
                            _launch();
                          }
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
