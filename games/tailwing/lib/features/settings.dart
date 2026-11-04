import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/readiness.dart';
import '../core/game_feedback.dart';
import 'email_actions.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: '환경설정',
    children: [
      const SectionTitle('소리·진동·조작'),
      const DeviceSettingsPanel(),
      const SectionTitle('게임 기록과 구독'),
      const LocalSaveStatus(),
      const RouteTile(
        title: '기록 이어하기',
        subtitle: '기기 저장 상태 · 계정 동기화 준비 상태',
        route: AppRoutes.cloud,
        icon: Icons.save_outlined,
      ),
      const RouteTile(
        title: '구독 관리',
        subtitle: '혜택·기간·구매 복원·스토어 관리',
        route: AppRoutes.entitlement,
        icon: Icons.verified_user_outlined,
      ),
      const SectionTitle('계정'),
      const AccountStatusPanel(),
      const RouteTile(title: '로그인·회원가입', route: AppRoutes.account),
      const RouteTile(title: '이메일 확인', route: AppRoutes.verify),
      const RouteTile(title: '이메일 변경', route: AppRoutes.emailChange),
      const RouteTile(title: '계정 찾기 도움', route: AppRoutes.help),
      const RouteTile(
        title: '로그아웃',
        subtitle: '기기 인증 정리 · 게임 기록 보존',
        route: AppRoutes.logout,
      ),
      const RouteTile(
        title: '회원 탈퇴',
        subtitle: '삭제 범위 · 본인 확인 · 처리 확인',
        route: AppRoutes.deleteAccount,
      ),
      const SectionTitle('도움말·고객지원'),
      const RouteTile(
        title: '조작 방법',
        route: AppRoutes.controls,
        icon: Icons.help_outline,
      ),
      const RouteTile(title: '고객지원·앱 정보', route: AppRoutes.support),
      const RouteTile(title: '이용약관', route: AppRoutes.terms),
      const RouteTile(title: '개인정보처리방침', route: AppRoutes.privacy),
      const SectionTitle('선택적 통계'),
      ListenableBuilder(
        listenable: AppServices.of(context).campaign,
        builder: (context, _) {
          final c = AppServices.of(context).campaign;
          return SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('기기 내 플레이 통계 기록 (선택)'),
            subtitle: const Text(
              '첫 전투 완료·실패·재도전·재방문 횟수만 기기에 저장합니다. 외부 전송은 없고 끄면 집계도 삭제합니다.',
            ),
            value: c.progress.analyticsConsent,
            onChanged: c.loaded && !c.writeBlocked ? c.setAnalytics : null,
          );
        },
      ),
    ],
  );
}

class LocalSaveStatus extends StatelessWidget {
  const LocalSaveStatus({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppServices.of(context).campaign;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            !c.loaded
                ? '기기 기록 읽는 중…'
                : c.writeBlocked
                ? '기록 보호 모드 · 기존 파일을 보존하고 있습니다'
                : c.saving
                ? '기기 설정·기록 저장 중…'
                : c.saveFailed
                ? '기기 저장 실패 · 다시 시도해 주세요'
                : '기기 설정·기록 저장 가능',
            key: const Key('localSaveStatus'),
            style: const TextStyle(color: Palette.muted, fontSize: 15),
          ),
          if (c.writeBlocked || c.saveFailed)
            TextButton(
              onPressed: c.saving || !c.loaded ? null : c.retryStorage,
              child: const Text('기기 저장 다시 시도'),
            ),
        ],
      ),
    );
  }
}

class DeviceSettingsPanel extends StatefulWidget {
  const DeviceSettingsPanel({super.key});
  @override
  State<DeviceSettingsPanel> createState() => _DeviceSettingsPanelState();
}

class _DeviceSettingsPanelState extends State<DeviceSettingsPanel> {
  double? _musicDraft, _effectsDraft;
  late VoidCallback _stop;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stop = AppServices.of(context).feedback.stopPreview;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context),
        c = services.campaign,
        feedback = services.feedback;
    return ListenableBuilder(
      listenable: Listenable.merge([c, feedback]),
      builder: (context, _) {
        final o = c.progress.options, enabled = c.loaded && !c.writeBlocked;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: const Key('musicToggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('배경음'),
              subtitle: const Text('전투 중 재생 · 일시정지나 앱을 벗어나면 멈춤'),
              value: o.music,
              onChanged: enabled
                  ? (v) => c.setOptions(o.copyWith(music: v))
                  : null,
            ),
            Text('배경음 음량 ${((_musicDraft ?? o.musicVolume) * 100).round()}%'),
            Slider(
              key: const Key('musicVolume'),
              value: _musicDraft ?? o.musicVolume,
              divisions: 20,
              label: '${((_musicDraft ?? o.musicVolume) * 100).round()}%',
              onChanged: enabled && o.music
                  ? (v) => setState(() => _musicDraft = v)
                  : null,
              onChangeEnd: (v) {
                c.setOptions(c.progress.options.copyWith(musicVolume: v));
                setState(() => _musicDraft = null);
              },
            ),
            OutlinedButton(
              onPressed: enabled && o.music && o.musicVolume > 0
                  ? feedback.previewMusic
                  : null,
              child: const Text('배경음 2초 미리 듣기'),
            ),
            SwitchListTile(
              key: const Key('effectsToggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('효과음'),
              subtitle: const Text('사격·피격·스킬·클리어 소리'),
              value: o.effects,
              onChanged: enabled
                  ? (v) => c.setOptions(o.copyWith(effects: v))
                  : null,
            ),
            Text(
              '효과음 음량 ${((_effectsDraft ?? o.effectsVolume) * 100).round()}%',
            ),
            Slider(
              key: const Key('effectsVolume'),
              value: _effectsDraft ?? o.effectsVolume,
              divisions: 20,
              label: '${((_effectsDraft ?? o.effectsVolume) * 100).round()}%',
              onChanged: enabled && o.effects
                  ? (v) => setState(() => _effectsDraft = v)
                  : null,
              onChangeEnd: (v) {
                c.setOptions(c.progress.options.copyWith(effectsVolume: v));
                setState(() => _effectsDraft = null);
              },
            ),
            OutlinedButton(
              onPressed: enabled && o.effects && o.effectsVolume > 0
                  ? () => feedback.cue(FeedbackCue.skill, preview: true)
                  : null,
              child: const Text('효과음 확인'),
            ),
            SwitchListTile(
              key: const Key('vibrationToggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('진동'),
              subtitle: const Text('피격·스킬 사용 시 짧은 진동 · 기기 설정에 따라 지원'),
              value: o.vibration,
              onChanged: enabled
                  ? (v) => c.setOptions(o.copyWith(vibration: v))
                  : null,
            ),
            OutlinedButton(
              onPressed: enabled && o.vibration
                  ? feedback.previewVibration
                  : null,
              child: const Text('진동 확인'),
            ),
            if (feedback.failed)
              const InfoPanel(
                title: '소리 또는 진동을 재생하지 못했습니다',
                body: '기기 음량·무음 설정을 확인하고 미리 듣기를 다시 눌러 주세요. 게임 진행과 저장은 계속 사용할 수 있습니다.',
              ),
            const SectionTitle('조작 감도'),
            Wrap(
              spacing: 8,
              children: [
                for (final value in [.75, 1.0, 1.25])
                  ChoiceChip(
                    key: Key('sensitivity-$value'),
                    label: Text(
                      value == 1
                          ? '기본'
                          : value < 1
                          ? '정밀'
                          : '빠르게',
                    ),
                    selected: c.progress.sensitivity == value,
                    onSelected: enabled ? (_) => c.setSensitivity(value) : null,
                  ),
              ],
            ),
            const Text('손가락을 기체에 올리지 않아도 빈 곳에서 드래그할 수 있습니다.'),
            SwitchListTile(
              key: const Key('motionToggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('화면 전환 효과 줄이기'),
              subtitle: const Text('이 기기에 저장됩니다.'),
              value: o.reduceMotion,
              onChanged: enabled
                  ? (v) => c.setOptions(o.copyWith(reduceMotion: v))
                  : null,
            ),
            const Text(
              '음량은 슬라이더에서 손을 떼면 저장·적용됩니다. 기기 음량과 무음 설정도 확인해 주세요.',
              style: TextStyle(fontSize: 14, color: Palette.muted),
            ),
          ],
        );
      },
    );
  }
}
