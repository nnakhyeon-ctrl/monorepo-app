import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../coop/client.dart';
import '../core/design.dart';
import '../core/readiness.dart';
import '../game/rendering.dart';
import '../game/engine.dart';

class CoopScreen extends StatefulWidget {
  const CoopScreen({super.key});
  @override
  State<CoopScreen> createState() => _CoopScreenState();
}

class _CoopScreenState extends State<CoopScreen> with WidgetsBindingObserver {
  late final CoopClient _client;
  final _code = TextEditingController();
  @override
  void initState() {
    super.initState();
    _client = CoopClient(
      Uri.tryParse(const String.fromEnvironment('COOP_URL')) ?? Uri(),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _client.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _client.leave();
    _client.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _client,
    builder: (context, _) {
      final c = _client, game = c.game;
      return AppPage(
        title: '친구와 협동 · 개발 중',
        children: [
          const InfoPanel(
            title: '두 기기 검증 전 시험 기능',
            body: '현재 무료 기본 구성의 방·전투 동기화 시험용입니다. 계정 기록·보상 지급은 아직 연결되지 않았습니다. 싱글 기록과 구매 권한을 변경하지 않습니다.',
            icon: Icons.people_outline,
          ),
          if (!c.configured)
            const InfoPanel(
              title: '협동 서버 설정 대기',
              body: '검증된 HTTPS/WSS 서버 주소와 인증·결과 저장 준비가 필요합니다. 현재 외부 서버를 운영하거나 연결하지 않습니다.',
            ),
          Text(
            c.status,
            style: const TextStyle(fontSize: 16, color: Palette.teal),
          ),
          const SizedBox(height: 12),
          if (!c.connected)
            FilledButton(
              onPressed: c.configured && !c.connecting
                  ? () => c.connect(resume: c.code.isNotEmpty)
                  : null,
              child: Text(
                c.connecting
                    ? '연결 중…'
                    : c.code.isEmpty
                    ? '서버 연결'
                    : '재접속',
              ),
            ),
          if (c.connected && c.code.isEmpty) ...[
            FilledButton(
              onPressed: () =>
                  c.create(AppServices.of(context).campaign.selectedStage),
              child: const Text('방 만들기'),
            ),
            TextField(
              controller: _code,
              maxLength: 8,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z2-9]')),
              ],
              decoration: const InputDecoration(labelText: '친구 초대 코드 (8자리)'),
            ),
            OutlinedButton(
              onPressed: () => c.join(_code.text),
              child: const Text('친구 방 참가'),
            ),
          ],
          if (c.code.isNotEmpty) ...[
            SelectableText(
              '초대 코드 ${c.code}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            Text(
              '참가 ${c.participants}/2 · 준비 ${c.readyCount}/2 · 내 기체 ${c.player + 1}',
            ),
            if (game == null && c.connected) ...[
              OutlinedButton(
                onPressed: c.toggleReady,
                child: Text(c.ready ? '준비 취소' : '준비 완료'),
              ),
              if (c.player == 0)
                FilledButton(
                  onPressed: c.readyCount == 2 && c.participants == 2
                      ? c.start
                      : null,
                  child: const Text('함께 시작'),
                ),
            ],
          ],
          if (game != null) ...[
            Text(
              '1번 장갑 ${game.health}/3 · 2번 장갑 ${game.partner!.health}/3 · 점수 ${game.score}',
            ),
            LayoutBuilder(
              builder: (context, bounds) => AspectRatio(
                aspectRatio: 360 / 600,
                child: GestureDetector(
                  onPanUpdate: (d) => c.move(
                    d.delta.dx * 360 / bounds.maxWidth,
                    d.delta.dy * 360 / bounds.maxWidth,
                  ),
                  child: CustomPaint(
                    painter: BattlePainter(
                      game,
                      AppServices.of(context).battleAssets.player,
                      assets: AppServices.of(context).battleAssets,
                    ),
                  ),
                ),
              ),
            ),
            FilledButton(
              onPressed: c.connected && game.phase == BattlePhase.playing
                  ? c.skill
                  : null,
              child: const Text('내 보호막 사용'),
            ),
            const Text(
              '서버가 전투 상태를 계산합니다. 연결이 끊기면 양쪽 전투가 멈추며 15초 동안 재접속을 기다립니다.',
            ),
          ],
          if (c.code.isNotEmpty)
            TextButton(
              onPressed: () async {
                await c.leave();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('방 나가기'),
            ),
        ],
      );
    },
  );
}
