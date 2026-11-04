import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../game/engine.dart';
import 'protocol.dart';

/// Production transport only accepts WSS with normal platform certificate
/// validation. Local plain-WS testing is confined to server tests on loopback.
class CoopClient extends ChangeNotifier {
  CoopClient(this.endpoint);
  final Uri endpoint;
  WebSocket? _socket;
  Timer? _inputTimer;
  bool _disposed = false, connecting = false, connected = false, ready = false;
  String code = '', _token = '', status = '서버 연결 전';
  int player = 0, participants = 0, readyCount = 0, _seq = 0, _tick = -1;
  BattleEngine? game;
  bool _skill = false;
  double _dx = 0, _dy = 0;
  bool get configured =>
      endpoint.scheme == 'wss' &&
      endpoint.host.isNotEmpty &&
      endpoint.userInfo.isEmpty &&
      endpoint.query.isEmpty &&
      endpoint.fragment.isEmpty &&
      endpoint.path == '/coop';
  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> connect({bool resume = false}) async {
    if (connecting || connected || !configured || _disposed) {
      return;
    }
    connecting = true;
    status = resume ? '재접속 중 · 서버는 최대 15초 기다립니다' : '서버 연결 중';
    _notify();
    try {
      final socket = await WebSocket.connect(endpoint.toString())
          .timeout(const Duration(seconds: 8));
      if (_disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      connected = true;
      socket.pingInterval = const Duration(seconds: 5);
      socket.listen(
        (raw) {
          try {
            if (raw is! String || utf8.encode(raw).length > maxFrameBytes) {
              throw const FormatException('frame');
            }
            final message = jsonDecode(raw) as Map<String, dynamic>;
            if (message['v'] != protocolVersion) {
              throw const FormatException('version');
            }
            switch (message['type']) {
              case 'welcome':
                final room = message['code'],
                    token = message['token'],
                    index = message['player'];
                if (room is! String ||
                    !RegExp(r'^[A-Z2-9]{8}$').hasMatch(room) ||
                    token is! String ||
                    !RegExp(r'^[a-f0-9]{48}$').hasMatch(token) ||
                    (index != 0 && index != 1)) {
                  throw const FormatException('room');
                }
                code = room;
                _token = token;
                player = index;
                status = '친구와 준비해 주세요';
              case 'room':
                final players = message['players'] as List;
                if (players.length > 2) {
                  throw const FormatException('room');
                }
                participants = players.length;
                readyCount = players.where((p) => p['ready'] == true).length;
                if (players.any((p) => p['connected'] != true)) {
                  status = '친구 연결 대기 · 전투 일시정지';
                }
              case 'snapshot':
                final data = message['state'] as Map<String, dynamic>;
                final tick = data['tick'];
                if (tick is! int || tick < 0) {
                  throw const FormatException('tick');
                }
                if (tick > _tick) {
                  game = readSnapshot(data);
                  _tick = tick;
                  status = game!.phase == BattlePhase.paused
                      ? '연결 대기 · 전투 일시정지'
                      : '함께 전투 중';
                }
              case 'ended':
                status = switch (message['reason']) {
                  'won' => '협동 작전 완료',
                  'lost' => '협동 작전 실패',
                  'left' => '참가자가 나가 전투가 종료되었습니다',
                  _ => '재접속 시간이 지나 전투가 종료되었습니다',
                };
                _inputTimer?.cancel();
              case 'error':
                status = '요청을 처리하지 못했습니다. 방 상태와 초대 코드를 확인하세요.';
              default:
                throw const FormatException('type');
            }
            _notify();
          } catch (_) {
            status = '서버 응답 형식을 확인하지 못했습니다';
            _socket?.close();
            _notify();
          }
        },
        onDone: () {
          connected = false;
          _inputTimer?.cancel();
          status = code.isEmpty ? '연결이 종료되었습니다' : '연결 끊김 · 15초 안에 재접속해 주세요';
          _notify();
        },
        onError: (_) {
          status = '연결 오류 · 서버 상태를 확인하세요';
          _socket?.close();
          _notify();
        },
      );
      status = '방을 만들거나 초대 코드로 참가하세요';
      if (resume && code.isNotEmpty && _token.isNotEmpty) {
        _send('resume', {'code': code, 'token': _token});
      }
      _inputTimer?.cancel();
      _inputTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (connected && game?.phase == BattlePhase.playing) {
          _send('input', {
            'seq': _seq++,
            'dx': _dx.clamp(-18, 18),
            'dy': _dy.clamp(-18, 18),
            'skill': _skill,
          });
          _dx = 0;
          _dy = 0;
          _skill = false;
        }
      });
    } catch (_) {
      status = '서버에 연결하지 못했습니다. 인증서·네트워크·서버 준비를 확인하세요.';
    } finally {
      connecting = false;
      _notify();
    }
  }

  void _send(String type, [Map<String, Object> values = const {}]) {
    if (connected && _socket?.readyState == WebSocket.open) {
      _socket!.add(jsonEncode({'v': 1, 'type': type, ...values}));
    }
  }

  void create(int stage) => _send('create', {'stage': stage});
  void join(String input) {
    final normalized = input.trim().toUpperCase();
    if (!RegExp(r'^[A-Z2-9]{8}$').hasMatch(normalized)) {
      status = '초대 코드 8자리를 확인하세요';
      _notify();
      return;
    }
    _send('join', {'code': normalized});
  }

  void toggleReady() {
    ready = !ready;
    _send('ready', {'ready': ready});
    _notify();
  }

  void start() => _send('start');
  void move(double dx, double dy) {
    if (dx.isFinite && dy.isFinite) {
      _dx = (_dx + dx).clamp(-30, 30);
      _dy = (_dy + dy).clamp(-30, 30);
    }
  }

  void skill() {
    _skill = true;
  }

  Future<void> suspend() async {
    await _socket?.close();
  }

  Future<void> leave() async {
    _send('leave');
    await _socket?.close();
  }

  @override
  void dispose() {
    _disposed = true;
    _inputTimer?.cancel();
    _socket?.close();
    super.dispose();
  }
}
