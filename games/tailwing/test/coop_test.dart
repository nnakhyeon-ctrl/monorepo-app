import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/coop/protocol.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/engine.dart';

import '../server/coop_server.dart';

class Peer {
  Peer(this.socket) {
    socket.listen((raw) {
      messages.add(jsonDecode(raw as String));
    });
  }
  final WebSocket socket;
  final List<Map<String, dynamic>> messages = [];
  void send(String type, [Map<String, Object> data = const {}]) =>
      socket.add(jsonEncode({'v': 1, 'type': type, ...data}));
  Future<Map<String, dynamic>> wait(String type, {int after = 0}) async {
    final end = DateTime.now().add(const Duration(seconds: 4));
    while (DateTime.now().isBefore(end)) {
      final matches = messages.skip(after).where((m) => m['type'] == type);
      if (matches.isNotEmpty) {
        return matches.first;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw StateError('No $type received');
  }
}

void main() {
  test('two loopback clients create/join/ready/start and receive identical authoritative state', () async {
    final server = CoopServer();
    await server.start();
    final clients = <Peer>[];
    addTearDown(() async {
      for (final p in clients) {
        await p.socket.close();
      }
      await server.close();
    });
    Future<Peer> connect() async {
      final p = Peer(
        await WebSocket.connect('ws://127.0.0.1:${server.port}/coop'),
      );
      clients.add(p);
      return p;
    }

    final a = await connect(), b = await connect();
    a.send('create', {'stage': 1});
    final welcome = await a.wait('welcome');
    b.send('join', {'code': welcome['code']});
    await b.wait('welcome');
    a.send('start');
    await a.wait('error'); // both ready required
    a.send('ready', {'ready': true});
    b.send('ready', {'ready': true});
    await Future<void>.delayed(const Duration(milliseconds: 80));
    a.send('start');
    await a.wait('snapshot');
    await b.wait('snapshot');
    a.send('input', {'seq': 0, 'dx': 12, 'dy': 0, 'skill': true});
    b.send('input', {'seq': 0, 'dx': -12, 'dy': 0, 'skill': true});
    Map<String, dynamic>? matchedA, matchedB;
    final until = DateTime.now().add(const Duration(seconds: 4));
    while (DateTime.now().isBefore(until) && matchedA == null) {
      for (final candidate
          in a.messages
              .where((m) => m['type'] == 'snapshot')
              .toList()
              .reversed) {
        if (candidate['state']['players'][0][0] != 132 ||
            candidate['state']['players'][1][0] != 228) {
          continue;
        }
        final matches = b.messages.where(
          (m) =>
              m['type'] == 'snapshot' &&
              m['state']['tick'] == candidate['state']['tick'],
        );
        if (matches.isNotEmpty) {
          matchedA = candidate;
          matchedB = matches.first;
          break;
        }
      }
      if (matchedA == null) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
    expect(
      matchedA,
      isNotNull,
      reason: 'wait for matching authoritative ticks, not a fixed host delay',
    );
    final snapA = matchedA!, sameTick = matchedB!;
    expect(snapA['state'], sameTick['state']);
    final g = readSnapshot(snapA['state']);
    expect(g.player.dx, 132);
    expect(g.partner!.player.dx, 228);
    expect(g.protected, isTrue);
    expect(g.partner!.protected, isTrue);
    final prior = a.messages.length;
    a.send('input', {'seq': 0, 'dx': 30, 'dy': 0});
    await a.wait('error', after: prior);
    final c = await connect();
    c.send('join', {'code': welcome['code']});
    await c.wait('error');
    await b.socket.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      a.messages.lastWhere((m) => m['type'] == 'snapshot')['state']['phase'],
      BattlePhase.paused.index,
    );
    final resumed = await connect();
    final bWelcome = b.messages.firstWhere((m) => m['type'] == 'welcome');
    resumed.send('resume', {
      'code': bWelcome['code'],
      'token': bWelcome['token'],
    });
    await resumed.wait('welcome');
    final newSnap = await resumed.wait('snapshot');
    expect(newSnap['state']['phase'], BattlePhase.playing.index);
    final count = a.messages.length;
    resumed.send('leave');
    final end = await a.wait('ended', after: count);
    expect(
      end['rewardCommitted'],
      isFalse,
      reason: 'No account ledger configured',
    );
    resumed.send('leave');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(
      a.messages.skip(count).where((m) => m['type'] == 'ended'),
      hasLength(1),
    );
  });
  test('second player shares enemies and damage; one survivor can finish', () {
    final g = BattleEngine(
      const FreeLoadout(),
      partnerLoadout: const FreeLoadout(),
    );
    g.partner!.activateSkill();
    g.bullets.add(Projectile(g.partner!.player, Vec.zero));
    g.step(.01);
    expect(g.partner!.health, 3);
    g.health = 0;
    g.step(.01);
    expect(g.phase, BattlePhase.playing);
    g.enemies.add(Enemy(const Vec(180, 100), EnemyKind.boss)..health = 10);
    g.bullets.add(Projectile(const Vec(180, 100), Vec.zero, friendly: true));
    g.step(.01);
    expect(g.phase, BattlePhase.won);
    expect(g.score, 1000);
  });
  test(
    'snapshot reader rejects invalid coordinates and unsupported protocol',
    () {
      final g = BattleEngine(
        const FreeLoadout(),
        partnerLoadout: const FreeLoadout(),
      );
      final valid = battleSnapshot(g, 1);
      expect(readSnapshot(valid).partner, isNotNull);
      expect(() => readSnapshot({...valid, 'v': 99}), throwsFormatException);
      expect(
        () => readSnapshot({
          ...valid,
          'players': [
            [double.nan, 500, 3, 0, 0],
            [240, 510, 3, 0, 0],
          ],
        }),
        throwsFormatException,
      );
    },
  );
}
