import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';
import '../core/external_services.dart';
import '../core/readiness.dart';
import '../security/email_auth.dart';
import '../security/social_types.dart';
import 'email_actions.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});
  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _password = TextEditingController();
  bool _visible = false;
  String? _storeNotice;
  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  Future<void> _prepare(
    EmailAuthController a, [
    SocialProvider? provider,
  ]) async {
    final password = _password.text;
    _password.clear();
    TextInput.finishAutofillContext(shouldSave: false);
    await a.prepareDeletion(
      password: provider == null ? password : null,
      provider: provider,
    );
  }

  Future<void> _confirm(EmailAuthController a) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('테일윙에서 탈퇴할까요?'),
        content: const Text(
          '이 계정의 게임 기록·설정·로그인 연결을 삭제합니다. 복구할 수 없습니다. 게스트 원본과 다른 앱·공급자 자체 계정은 유지합니다. 스토어 구독 해지·환불은 별도입니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('confirmAccountDeletion'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('즉시 탈퇴 요청'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await a.commitDeletion();
    } else {
      await a.cancelDeletion();
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context), a = services.emailAuth;
    final store = storeManagementUrl(Theme.of(context).platform);
    return ListenableBuilder(
      listenable: a,
      builder: (_, _) => PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop && a.deletionPrepared) a.cancelDeletion();
        },
        child: AppPage(
          title: '회원 탈퇴',
          light: true,
          children: [
            const InfoPanel(
              title: '삭제할 범위와 남는 정보',
              body: '테일윙의 계정, 서버 진행·클리어·최고점수·개인 설정, 로그인 연결·세션, 이 계정의 기기 캐시와 이용권 표시를 삭제합니다. 삭제 후 복구할 수 없습니다. 무료 게스트 원본과 다른 계정·다른 앱의 데이터는 유지합니다.',
              icon: Icons.person_remove_outlined,
            ),
            const SizedBox(height: 16),
            const Text(
              '정상 연결 시 즉시 처리하며 오류가 나면 접수·완료를 구분하고 다시 확인합니다. 재시도용 요청 확인값과 접근 차단용 해시만 최대 7일 보관합니다. 미완료 삭제 작업은 완료될 때까지 보관합니다. 실제 구매 기록의 법정 보관은 결제 도입 전에 별도로 안내합니다.',
            ),
            const SizedBox(height: 12),
            const Text(
              '탈퇴는 구독 해지·자동 갱신 중지·환불이 아닙니다. 구독 중이어도 즉시 탈퇴를 선택할 수 있습니다. 카카오·Google·Apple 자체 계정은 삭제하지 않습니다. 공급자 앱 권한 해제는 공급자 계정 설정에서 별도로 확인해 주세요.',
            ),
            if (store != null)
              OutlinedButton(
                onPressed: () async {
                  var opened = false;
                  try {
                    if (services.contacts.permits(store)) {
                      opened = await services.external.open(store);
                    }
                  } catch (_) {
                    /* Safe fixed destination only. */
                  }
                  if (mounted) {
                    setState(
                      () => _storeNotice = opened
                          ? '스토어 구독 관리를 열었습니다.'
                          : '스토어를 열지 못했습니다. 해당 스토어의 계정 → 구독에서 확인해 주세요.',
                    );
                  }
                },
                child: const Text('스토어 구독 관리 열기'),
              ),
            if (_storeNotice != null) Text(_storeNotice!),
            const EmailNotice(),
            if (a.deletionPending) ...[
              const Text(
                '탈퇴 처리·기기 정리 완료를 아직 확인하지 못했습니다. 새 계정 로그인 전에 아래에서 확인해 주세요.',
              ),
              FilledButton(
                key: const Key('retryAccountDeletion'),
                onPressed: a.busy ? null : a.resumeDeletion,
                child: const Text('탈퇴 처리 확인·재시도'),
              ),
            ] else if (a.connection == null) ...[
              const Text('삭제할 계정을 먼저 확인해 주세요. 게스트 플레이와 원본 기록은 유지합니다.'),
              const RouteTile(title: '계정 로그인·상태 확인', route: AppRoutes.account),
            ] else if (a.deletionPrepared) ...[
              FilledButton(
                key: const Key('deleteAccountNow'),
                onPressed: a.busy ? null : () => _confirm(a),
                child: const Text('최종 확인 후 탈퇴'),
              ),
              OutlinedButton(
                key: const Key('cancelAccountDeletion'),
                onPressed: a.busy ? null : a.cancelDeletion,
                child: const Text('탈퇴 취소 · 기록 유지'),
              ),
            ] else ...[
              const Text(
                '연결된 로그인으로 다시 본인 확인한 뒤 최종 삭제를 선택합니다. 본인 확인만으로는 삭제하지 않습니다.',
              ),
              if (a.linkedProviders.contains('password'))
                AutofillGroup(
                  child: Column(
                    children: [
                      TextField(
                        key: const Key('deleteAccountPassword'),
                        controller: _password,
                        obscureText: !_visible,
                        enabled: !a.busy,
                        autofillHints: const [AutofillHints.password],
                        enableIMEPersonalizedLearning: false,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: '현재 계정 비밀번호',
                          suffixIcon: IconButton(
                            tooltip: _visible ? '비밀번호 숨기기' : '비밀번호 표시',
                            onPressed: () =>
                                setState(() => _visible = !_visible),
                            icon: Icon(
                              _visible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      FilledButton(
                        key: const Key('prepareAccountDeletion'),
                        onPressed: a.busy ? null : () => _prepare(a),
                        child: const Text('이메일 계정 본인 확인'),
                      ),
                    ],
                  ),
                ),
              for (final entry in const {
                SocialProvider.kakao: 'kakao',
                SocialProvider.google: 'google.com',
                SocialProvider.apple: 'apple.com',
              }.entries)
                if (a.linkedProviders.contains(entry.value))
                  OutlinedButton(
                    onPressed: a.busy ? null : () => _prepare(a, entry.key),
                    child: Text(
                      '${switch (entry.key) {
                        SocialProvider.kakao => '카카오',
                        SocialProvider.google => 'Google',
                        SocialProvider.apple => 'Apple',
                      }}로 다시 본인 확인',
                    ),
                  ),
            ],
            const SizedBox(height: 16),
            const RouteTile(title: '개인정보·삭제 범위', route: AppRoutes.privacy),
          ],
        ),
      ),
    );
  }
}
