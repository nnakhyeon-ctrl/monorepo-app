import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';
import '../core/readiness.dart';
import '../game/catalog.dart';
import '../game/engine.dart';
import '../game/rendering.dart';
import '../game/stages.dart';
import '../game/combat_model.dart';
import '../game/progress.dart';
import '../core/game_feedback.dart';
import 'battle_hud.dart';
import 'pilot_pose.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});
  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  BattleEngine? _game;
  late final Ticker _ticker;
  final ValueNotifier<int> _paintFrame = ValueNotifier(0);
  int _hudTick = -1;
  Duration? _previous;
  bool _readyStarted = false, _failed = false;
  bool _settling = false, _settled = false;
  String _runId = '';
  int _tutorial = 0;
  int _stage = 1;
  int _accountEpoch = 0;
  CampaignController? _campaign;
  bool _accountChanged = false;
  void _checkAccount() {
    if (_game != null &&
        _campaign!.scopeEpoch != _accountEpoch &&
        !_accountChanged) {
      _ticker.stop();
      _game!.pause();
      _feedback?.battle(false);
      if (mounted) setState(() => _accountChanged = true);
    }
  }

  FeedbackController? _feedback;
  bool _allowLeave = false, _exitDialog = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((elapsed) {
      if (_game != null && _game!.phase != BattlePhase.playing) {
        _ticker.stop();
        return;
      }
      final previous = _previous;
      _previous = elapsed;
      if (_tutorial > 0) {
        return;
      }
      if (previous != null && _game?.phase == BattlePhase.playing) {
        final health = _game!.health, shots = _game!.shotsFired;
        _game!.step((elapsed - previous).inMicroseconds / 1000000);
        _paintFrame.value++;
        final hudTick = (_game!.elapsed * 10).floor();
        if (hudTick != _hudTick ||
            _game!.health != health ||
            _game!.phase != BattlePhase.playing) {
          _hudTick = hudTick;
          setState(() {});
        }
        if (_game!.shotsFired > shots) {
          _feedback?.cue(FeedbackCue.shot);
        }
        if (_game!.health < health) {
          _feedback?.cue(FeedbackCue.hit);
        }
        if (_game!.phase != BattlePhase.playing) {
          _ticker.stop();
          _finish();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_readyStarted) {
      _readyStarted = true;
      _prepare();
    }
  }

  Future<void> _prepare() async {
    try {
      final services = AppServices.of(context);
      if (_campaign == null) {
        _campaign = services.campaign;
        _campaign!.addListener(_checkAccount);
      }
      _feedback = services.feedback;
      await services.battleAssets.prepare();
      await services.campaign.ready;
      await services.loadout.ready;
      await services.battleAssets.preparePilot('pilot');
      await services.battleAssets.preparePilot(services.loadout.pilot.id);
      if (!mounted) return;
      setState(() {
        _stage = services.campaign.selectedStage;
        _newBattle(services.campaign);
        _tutorial = services.campaign.progress.tutorialDone ? 0 : 1;
        if (_tutorial > 0) {
          _game!.step(.01);
        }
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
          _game!.pause();
        }
        _failed = false;
      });
      _feedback!.battle(true);
      _feedback!.pause(_game!.phase != BattlePhase.playing);
      if (!_ticker.isActive && _game!.phase == BattlePhase.playing) {
        _ticker.start();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _newBattle(CampaignController campaign) {
    _accountEpoch = campaign.scopeEpoch;
    _game = BattleEngine(
      AppServices.of(context).loadout,
      stage: stageByNumber(_stage),
    );
    _runId = campaign.newRunId();
    _settled = false;
    _settling = false;
    _previous = null;
    _hudTick = -1;
  }

  Future<void> _finish() async {
    final g = _game;
    if (g == null ||
        _settled ||
        _settling ||
        (g.phase != BattlePhase.won && g.phase != BattlePhase.lost)) {
      return;
    }
    setState(() => _settling = true);
    if (g.phase == BattlePhase.won) {
      _feedback?.cue(FeedbackCue.clear);
    }
    _feedback?.battle(false);
    await AppServices.of(context).campaign.finish(
      runId: _runId,
      stage: _stage,
      won: g.phase == BattlePhase.won,
      score: g.score,
      expectedScopeEpoch: _accountEpoch,
    );
    if (mounted) {
      setState(() {
        _settling = false;
        _settled = true;
      });
    }
  }

  void _retry({bool next = false}) {
    final campaign = AppServices.of(context).campaign;
    if (_settling || _accountChanged || !campaign.loaded) {
      return;
    }
    if (next) {
      if (_stage >= campaign.progress.unlocked || _stage >= stages.length) {
        return;
      }
      _stage++;
      campaign.selectStage(_stage);
    } else {
      campaign.metric('retry');
      campaign.selectStage(_stage);
    }
    setState(() {
      _newBattle(campaign);
      _feedback?.battle(true);
      if (!_ticker.isActive) {
        _ticker.start();
      }
    });
  }

  void _skill(BattleEngine g) {
    setState(() {
      if (g.activateSkill()) {
        _feedback?.cue(FeedbackCue.skill);
        if (_tutorial == 3) {
          _tutorial = 0;
          AppServices.of(context).campaign.completeTutorial();
        }
      }
    });
    _finish();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _game != null && mounted) {
      setState(_game!.pause);
      _ticker.stop();
      _feedback?.pause(true);
    }
    _previous = null;
  }

  @override
  void dispose() {
    _campaign?.removeListener(_checkAccount);
    _ticker.dispose();
    _paintFrame.dispose();
    _feedback?.battle(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _pauseToggle() {
    setState(() {
      if (_game!.phase == BattlePhase.playing) {
        _game!.pause();
        _ticker.stop();
      } else {
        _game!.resume();
        if (!_ticker.isActive) _ticker.start();
      }
      _previous = null;
    });
    _feedback?.pause(_game!.phase != BattlePhase.playing);
  }

  Future<void> _requestExit() async {
    if (_exitDialog || _settling) {
      return;
    }
    final g = _game;
    final active =
        g != null &&
        (g.phase == BattlePhase.playing || g.phase == BattlePhase.paused);
    if (active) {
      _exitDialog = true;
      final wasPlaying = g.phase == BattlePhase.playing;
      if (wasPlaying) {
        _pauseToggle();
      }
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('홈으로 이동할까요?'),
          content: const Text(
            '진행 중인 전투의 점수와 진행은 저장되지 않습니다. 이미 완료한 작전·해금·최고 기록은 유지됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('전투로 돌아가기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('홈으로 이동'),
            ),
          ],
        ),
      );
      _exitDialog = false;
      if (!mounted) {
        return;
      }
      if (leave != true) {
        if (wasPlaying &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          _pauseToggle();
        }
        return;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _allowLeave = true);
    Navigator.of(context).popUntil(
      (route) => route.settings.name == AppRoutes.home || route.isFirst,
    );
  }

  Future<void> _retryPaused() async {
    if (_exitDialog) {
      return;
    }
    _exitDialog = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('처음부터 다시 도전할까요?'),
        content: const Text('이번 전투의 점수와 진행은 초기화됩니다. 이미 저장한 기록과 선택한 장비는 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('다시 도전'),
          ),
        ],
      ),
    );
    _exitDialog = false;
    if (confirmed == true && mounted) {
      _retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accountChanged) {
      return AppPage(
        title: '계정 변경',
        children: [
          const Text('계정 상태가 바뀌어 전투를 중단했습니다. 이전 전투 결과를 새 계정에 저장하지 않았습니다.'),
          FilledButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: const Text('처음 화면으로'),
          ),
        ],
      );
    }
    final g = _game;
    return PopScope(
      canPop:
          _allowLeave ||
          (!_settling &&
              g != null &&
              g.phase != BattlePhase.playing &&
              g.phase != BattlePhase.paused),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _requestExit();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _requestExit),
          title: Text('작전 ${_stage.toString().padLeft(2, '0')}'),
          actions: [
            if (g?.phase == BattlePhase.won)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 60,
                  child: PilotPose(g!.pilot, height: 48, victory: true),
                ),
              ),
            if (g != null &&
                (g.phase == BattlePhase.playing ||
                    g.phase == BattlePhase.paused))
              IconButton(
                key: const Key('pauseBattle'),
                tooltip: g.phase == BattlePhase.playing ? '일시정지' : '계속하기',
                onPressed: _pauseToggle,
                icon: Icon(
                  g.phase == BattlePhase.playing
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: g == null
              ? Center(
                  child: _failed
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('전투 이미지를 준비하지 못했습니다.'),
                            TextButton(
                              onPressed: _prepare,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        )
                      : const CircularProgressIndicator(),
                )
              : LayoutBuilder(
                  builder: (context, viewport) {
                    final largeText =
                        MediaQuery.textScalerOf(context).scale(15) > 24;
                    final short = viewport.maxHeight < 430 || largeText;
                    final field = _field(g);
                    final status = BattleHud(g);
                    final controls = _controls(g);
                    if (short) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            status,
                            const SizedBox(height: 10),
                            SizedBox(height: 340, child: field),
                            controls,
                          ],
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                      child: Column(
                        children: [
                          status,
                          const SizedBox(height: 10),
                          Expanded(child: field),
                          controls,
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _field(BattleEngine g) => Center(
    child: AspectRatio(
      aspectRatio: BattleEngine.width / BattleEngine.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, bounds) => Stack(
            fit: StackFit.expand,
            children: [
              Focus(
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is KeyUpEvent) return KeyEventResult.ignored;
                  final delta = switch (event.logicalKey) {
                    LogicalKeyboardKey.arrowLeft => const Vec(-15, 0),
                    LogicalKeyboardKey.arrowRight => const Vec(15, 0),
                    LogicalKeyboardKey.arrowUp => const Vec(0, -15),
                    LogicalKeyboardKey.arrowDown => const Vec(0, 15),
                    _ => null,
                  };
                  if (delta != null) {
                    setState(() => g.moveBy(delta));
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.space) {
                    _skill(g);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Semantics(
                  label: '전투 영역. 드래그로 기체를 움직이며 기본 사격은 자동입니다.',
                  child: GestureDetector(
                    key: const Key('battleField'),
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) {
                      final gain =
                          BattleEngine.width /
                          bounds.maxWidth *
                          AppServices.of(context).campaign.progress.sensitivity;
                      g.moveBy(Vec(d.delta.dx * gain, d.delta.dy * gain));
                      _paintFrame.value++;
                      if (_tutorial == 1) {
                        setState(() => _tutorial = 2);
                      }
                    },
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: BattlePainter(
                          g,
                          AppServices.of(context).battleAssets
                              .imageFor(g.aircraft),
                          assets: AppServices.of(context).battleAssets,
                          reduceEffects:
                              AppServices.of(context)
                                  .preferences
                                  .reduceMotion ||
                              MediaQuery.disableAnimationsOf(context),
                          repaint: _paintFrame,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_tutorial > 0 && g.phase == BattlePhase.playing)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Material(
                    color: Palette.panel,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(switch (_tutorial) {
                            1 =>
                              '1/3 · 화면 아래 빈 곳을 드래그하세요. 손가락 위치로 기체가 튀지 않습니다.',
                            2 => '2/3 · 기본 사격은 자동입니다. 청록색 긴 탄은 아군탄, 주황색 둥근 탄은 적탄입니다.',
                            _ => '3/3 · 아래 보호막 버튼을 누르세요. 2초 방어 후 10초 뒤 다시 사용할 수 있습니다.',
                          }, style: const TextStyle(fontSize: 14)),
                          if (_tutorial == 2)
                            TextButton(
                              key: const Key('tutorialFire'),
                              onPressed: () => setState(() => _tutorial = 3),
                              child: const Text('사격 확인'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (g.phase != BattlePhase.playing)
                ColoredBox(
                  color: Palette.navy.withValues(alpha: .88),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            switch (g.phase) {
                              BattlePhase.paused => '일시정지',
                              BattlePhase.won => '작전 완료',
                              _ => '다시 도전하세요',
                            },
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '점수 ${g.score} · 격추 ${g.defeated}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          if (g.phase != BattlePhase.paused)
                            ListenableBuilder(
                              listenable: AppServices.of(context).campaign,
                              builder: (context, _) {
                                final campaign = AppServices.of(context)
                                    .campaign;
                                return Text(
                                  _settling
                                      ? '기록 저장 중…'
                                      : campaign.saveFailed ||
                                            campaign.writeBlocked
                                      ? '기기 기록 저장 실패 · 기존 파일은 보존됩니다. 설정에서 상태를 확인하세요.'
                                      : '기기 기록 저장 완료 · 최고 ${campaign.progress.records[_stage]?.best ?? 0}점',
                                  textAlign: TextAlign.center,
                                );
                              },
                            ),
                          if (g.phase == BattlePhase.won &&
                              _stage < stages.length)
                            FilledButton(
                              key: const Key('nextStage'),
                              onPressed: _settled && !_settling
                                  ? () => _retry(next: true)
                                  : null,
                              child: const Text('다음 작전'),
                            ),
                          if (g.phase == BattlePhase.paused)
                            FilledButton(
                              onPressed: _pauseToggle,
                              child: const Text('계속하기'),
                            )
                          else
                            FilledButton(
                              key: const Key('retryBattle'),
                              onPressed: _settling ? null : _retry,
                              child: const Text('다시 도전'),
                            ),
                          if (g.phase == BattlePhase.paused)
                            OutlinedButton(
                              key: const Key('retryPausedBattle'),
                              onPressed: _retryPaused,
                              child: const Text('처음부터 재도전'),
                            ),
                          TextButton(
                            onPressed: _settling ? null : _requestExit,
                            child: const Text('첫 화면으로'),
                          ),
                          const Text(
                            '서버 기록 저장은 연결 준비 중입니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _controls(BattleEngine g) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (1 - g.cooldown / g.skillRechargeDuration).clamp(0, 1),
            minHeight: 3,
            color: Palette.teal,
            backgroundColor: Palette.panel,
          ),
        ),
        const SizedBox(height: 7),
        FilledButton.icon(
          key: const Key('useSkill'),
          onPressed: g.cooldown > 0 || g.phase != BattlePhase.playing
              ? null
              : () => _skill(g),
          icon: Icon(catalogEntry(g.skill).icon),
          label: Text(
            g.cooldown > 0
                ? '${g.skill == 'signature' ? g.pilot.technique : catalogEntry(g.skill).name} · ${g.cooldown.ceil()}초 후'
                : '${g.skill == 'signature' ? g.pilot.technique : catalogEntry(g.skill).name} 사용',
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '드래그 이동 · 자동 사격 · 중앙 점이 피격 위치',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Palette.muted),
        ),
      ],
    ),
  );
}

class ControlsScreen extends StatelessWidget {
  const ControlsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: '조작 방법',
    children: [
      InfoPanel(
        title: '기체 이동과 사격',
        body: '전투 영역을 드래그해 기체를 움직입니다. 기본 사격은 자동입니다. PC에서는 방향키로 이동하고 스페이스 키로 스킬을 사용합니다.',
        icon: Icons.touch_app_outlined,
      ),
      SectionTitle('무료 보호막'),
      Text(
        '화면 아래의 보호막 사용 버튼을 누르면 2초 동안 적탄을 방어합니다. 사용 후 10초가 지나야 다시 사용할 수 있습니다. 보호막의 남은 시간과 재사용 대기시간을 화면에서 확인하세요.',
      ),
      SectionTitle('전투와 일시정지'),
      Text(
        '중앙의 흰 점이 피격 위치입니다. 주황색 원형 적탄을 피하며 적을 격추하세요. 정찰기·확산기·장갑기와 마지막 보스의 패턴이 다릅니다. 상단 일시정지 버튼으로 멈출 수 있고 앱을 벗어나도 자동으로 멈춥니다. 복귀 후 계속하기를 눌러 주세요.',
      ),
      SectionTitle('선택과 이용권'),
      Text(
        '전투기·장비에서 캐릭터와 스킬을 선택하면 다음 전투에 적용됩니다. 기본 캐릭터·기본 사격·보호막은 무료이며, 추가 구성에는 유효한 구독 이용권이 필요합니다.',
      ),
      const SectionTitle('현재 구현된 스킬'),
      for (final skill in catalogEntries.where(
        (e) => e.category == CatalogCategory.skill,
      ))
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            '${skill.name} · ${skill.premium ? '구독 이용권 필요' : '무료'}\n${skill.detail}',
          ),
        ),
      const Text(
        '현재 선택한 스킬은 전투 아래 버튼과 재사용 대기시간으로 확인합니다. 이든의 보호막 지속 증가·코어 튜너의 대기시간 감소가 선택 구성에 따라 적용됩니다.',
      ),
      const SectionTitle('재도전과 홈으로 이동'),
      const Text(
        '일시정지에서 계속하거나 처음부터 재도전할 수 있습니다. 전투 중 홈으로 나가면 이번 전투 진행과 점수는 저장되지 않으며 이미 완료한 작전과 최고 기록은 유지됩니다.',
      ),
      RouteTile(title: '전투기·장비', route: AppRoutes.hangar),
      RouteTile(title: '지원 및 안내', route: AppRoutes.support),
    ],
  );
}
