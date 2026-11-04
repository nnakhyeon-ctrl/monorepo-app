import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:raikeopeu2026/coop/protocol.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/stages.dart';

/// Local reference authority. It never issues account rewards or paid access.
/// Bind only loopback until TLS, verified identity and a durable result ledger
/// are configured and tested. No service is created or deployed by this file.
class CoopServer {
  CoopServer({this.reconnectWindow = const Duration(seconds: 15)});
  final Duration reconnectWindow;
  HttpServer? _http;
  Timer? _timer;
  final Map<String, _Room> _rooms = {};
  final Set<WebSocket> _sockets = {};
  final Random _random = Random.secure();
  int get port => _http!.port;
  String _token() => List.generate(
    24,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  String _code() => List.generate(
    8,
    (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[_random.nextInt(32)],
  ).join();
  Future<void> start({int port = 0}) async {
    _http = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _http!.listen((request) async {
      if (request.uri.path != '/coop' ||
          !WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }
      if (_sockets.length >= 32) {
        request.response.statusCode = 503;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      socket.pingInterval = const Duration(seconds: 5);
      _sockets.add(socket);
      _Peer? peer;
      var frames = 0, window = DateTime.now();
      socket.listen(
        (raw) {
          try {
            final now = DateTime.now();
            if (now.difference(window).inSeconds >= 1) {
              frames = 0;
              window = now;
            }
            if (++frames > 90 ||
                raw is! String ||
                utf8.encode(raw).length > 2048) {
              socket.close(WebSocketStatus.policyViolation);
              return;
            }
            final data = jsonDecode(raw) as Map<String, dynamic>;
            if (data['v'] != protocolVersion) {
              throw const FormatException('version');
            }
            switch (data['type']) {
              case 'create':
                if (peer != null || _rooms.length >= 16) {
                  throw const FormatException('state');
                }
                final stage = data['stage'];
                if (stage is! int || stage < 1 || stage > stages.length) {
                  throw const FormatException('stage');
                }
                var code = _code();
                while (_rooms.containsKey(code)) {
                  code = _code();
                }
                final room = _Room(code, stage);
                _rooms[code] = room;
                peer = _Peer(room, 0, _token(), socket);
                room.players.add(peer!);
                _welcome(peer!);
              case 'join':
                if (peer != null) {
                  throw const FormatException('state');
                }
                final room = _rooms[data['code']];
                if (room == null ||
                    room.players.length != 1 ||
                    room.game != null ||
                    room.ended) {
                  throw const FormatException('room');
                }
                peer = _Peer(room, 1, _token(), socket);
                room.players.add(peer!);
                _welcome(peer!);
              case 'resume':
                if (peer != null) {
                  throw const FormatException('state');
                }
                final room = _rooms[data['code']];
                final found = room?.players
                    .where((p) => p.token == data['token'])
                    .firstOrNull;
                if (found == null ||
                    found.socket != null ||
                    found.disconnected == null ||
                    now.difference(found.disconnected!) > reconnectWindow ||
                    room!.ended) {
                  throw const FormatException('resume');
                }
                found.socket = socket;
                found.disconnected = null;
                peer = found;
                _welcome(found);
                if (room.players.every((p) => p.socket != null)) {
                  room.game?.resume();
                }
              case 'ready':
                final p = peer;
                if (p == null || p.room.game != null || p.room.ended) {
                  throw const FormatException('state');
                }
                p.ready = data['ready'] == true;
                _broadcastRoom(p.room);
              case 'start':
                final p = peer;
                if (p == null ||
                    p.index != 0 ||
                    p.room.game != null ||
                    p.room.ended ||
                    p.room.players.length != 2 ||
                    p.room.players.any((p) => !p.ready || p.socket == null)) {
                  throw const FormatException('state');
                }
                p.room.game = BattleEngine(
                  const FreeLoadout(),
                  stage: stageByNumber(p.room.stage),
                  partnerLoadout: const FreeLoadout(),
                );
                p.room.runId = _token();
              case 'input':
                final p = peer;
                if (p == null || p.room.game == null || p.room.ended) {
                  throw const FormatException('state');
                }
                final sequence = data['seq'], dx = data['dx'], dy = data['dy'];
                if (sequence is! int ||
                    sequence <= p.sequence ||
                    sequence > p.sequence + 10000 ||
                    dx is! num ||
                    dy is! num ||
                    !dx.isFinite ||
                    !dy.isFinite ||
                    dx.abs() > 30 ||
                    dy.abs() > 30) {
                  throw const FormatException('input');
                }
                p.sequence = sequence;
                // Only input intent is accepted; never health/score/hit/reward.
                p.dx = (p.dx + dx).clamp(-18, 18).toDouble();
                p.dy = (p.dy + dy).clamp(-18, 18).toDouble();
                p.skill = p.skill || data['skill'] == true;
              case 'leave':
                if (peer != null) {
                  _end(peer!.room, 'left');
                }
              default:
                throw const FormatException('type');
            }
          } catch (_) {
            _send(socket, {'type': 'error', 'message': '요청 상태를 확인해 주세요.'});
          }
        },
        onDone: () {
          _sockets.remove(socket);
          if (peer?.socket == socket) {
            peer!.socket = null;
            peer!.disconnected = DateTime.now();
            peer!.room.game?.pause();
            _broadcastRoom(peer!.room);
          }
        },
        onError: (_) {
          socket.close();
        },
      );
    });
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => tick());
  }

  void _send(WebSocket socket, Map<String, Object?> message) {
    if (socket.readyState == WebSocket.open) {
      socket.add(jsonEncode({'v': protocolVersion, ...message}));
    }
  }

  void _welcome(_Peer p) {
    _send(p.socket!, {
      'type': 'welcome',
      'code': p.room.code,
      'token': p.token,
      'player': p.index,
    });
    _broadcastRoom(p.room);
  }

  void _broadcastRoom(_Room room) {
    for (final p in room.players) {
      if (p.socket != null) {
        _send(p.socket!, {
          'type': 'room',
          'code': room.code,
          'stage': room.stage,
          'players': [
            for (final p in room.players)
              {'ready': p.ready, 'connected': p.socket != null},
          ],
        });
      }
    }
  }

  void _end(_Room room, String reason) {
    if (room.ended) {
      return;
    }
    room.ended = true;
    for (final p in room.players) {
      if (p.socket != null) {
        _send(p.socket!, {
          'type': 'ended',
          'reason': reason,
          'run': room.runId,
          'score': room.game?.score ?? 0,
          'rewardCommitted': false,
        });
      }
    }
  }

  void tick() {
    final now = DateTime.now();
    for (final room in _rooms.values.toList()) {
      if (!room.ended &&
          (now.difference(room.created).inMinutes > 10 ||
              room.players.any(
                (p) =>
                    p.disconnected != null &&
                    now.difference(p.disconnected!) > reconnectWindow,
              ))) {
        _end(room, 'disconnected');
      }
      if (room.ended) {
        if (room.players.every((p) => p.socket == null) ||
            now.difference(room.created).inMinutes > 11) {
          _rooms.remove(room.code);
        }
        continue;
      }
      final g = room.game;
      if (g == null) {
        continue;
      }
      if (room.players.every((p) => p.socket != null)) {
        for (final p in room.players) {
          final pilot = p.index == 0 ? g : g.partner!;
          pilot.moveBy(Vec(p.dx, p.dy));
          if (p.skill) {
            pilot.activateSkill();
          }
          p.dx = 0;
          p.dy = 0;
          p.skill = false;
        }
        g.step(.05);
      }
      room.tick++;
      final state = battleSnapshot(g, room.tick);
      for (final p in room.players) {
        if (p.socket != null) {
          _send(p.socket!, {
            'type': 'snapshot',
            'state': state,
            'ack': p.sequence,
          });
        }
      }
      if (g.phase == BattlePhase.won || g.phase == BattlePhase.lost) {
        _end(room, g.phase.name);
      }
    }
  }

  Future<void> close() async {
    _timer?.cancel();
    for (final s in _sockets.toList()) {
      await s.close();
    }
    await _http?.close(force: true);
  }
}

class _Room {
  _Room(this.code, this.stage);
  final String code;
  final int stage;
  final created = DateTime.now();
  final List<_Peer> players = [];
  BattleEngine? game;
  int tick = 0;
  bool ended = false;
  String runId = '';
}

class _Peer {
  _Peer(this.room, this.index, this.token, this.socket);
  final _Room room;
  final int index;
  final String token;
  WebSocket? socket;
  DateTime? disconnected;
  bool ready = false, skill = false;
  int sequence = -1;
  double dx = 0, dy = 0;
}

Future<void> main() async {
  final server = CoopServer();
  await server.start(port: 8787);
  stdout.writeln(
    'AIRZERO local reference: ws://127.0.0.1:${server.port}/coop (free kit, no account rewards)',
  );
  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    exit(0);
  });
}
