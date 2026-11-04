import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';
import '../core/readiness.dart';
import '../security/email_auth.dart';
import 'account.dart' show validateEmail;

class EmailNotice extends StatelessWidget {
  const EmailNotice({super.key});
  @override
  Widget build(BuildContext context) {
    final a = AppServices.of(context).emailAuth;
    return ListenableBuilder(
      listenable: a,
      builder: (_, _) => a.message == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(a.message!, key: const Key('authNotice')),
              ),
            ),
    );
  }
}

class AccountStatusPanel extends StatefulWidget {
  const AccountStatusPanel({this.details = false, super.key});
  final bool details;
  @override
  State<AccountStatusPanel> createState() => _AccountStatusPanelState();
}

class _AccountStatusPanelState extends State<AccountStatusPanel> {
  bool _restored = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.details && !_restored) {
      _restored = true;
      final a = AppServices.of(context).emailAuth;
      Future.microtask(a.restore);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = AppServices.of(context).emailAuth,
        c = AppServices.of(context).campaign;
    final accountGame = AppServices.of(context).accountGame;
    return ListenableBuilder(
      listenable: Listenable.merge([a, c]),
      builder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoPanel(
            title: switch (a.phase) {
              EmailPhase.guest => '게스트 플레이 · 기기 기록 유지',
              EmailPhase.verificationPending => '이메일 확인 대기',
              EmailPhase.serverPending => '계정 인증됨 · 기록 서버 재연결 필요',
              EmailPhase.connected => '계정 연결됨',
            },
            body: a.phase == EmailPhase.connected
                ? '계정에 보관된 작전 기록 ${a.serverRecordCount}개. 이 계정 전용 기기 기록·선택 구성을 사용합니다. 게스트 원본은 유지하며 전체 자동 동기화는 준비 중입니다. 유료 이용권은 별도로 검증합니다.'
                : '기본 플레이와 기기의 진행 기록·설정은 그대로 사용할 수 있습니다. 계정 확인과 기록 가져오기는 별도로 처리합니다.',
            icon: Icons.person_outline,
          ),
          const EmailNotice(),
          if (a.connection != null)
            for (final entry in const {
              'password': '이메일',
              'kakao': '카카오',
              'google.com': 'Google',
              'apple.com': 'Apple',
            }.entries)
              Text(
                '${entry.value}: ${a.linkedProviders.contains(entry.key) ? '연결됨' : '미연결'}',
                key: Key('provider-${entry.key}'),
              ),
          if (a.deletionPending)
            const RouteTile(
              title: '탈퇴 처리 확인·재시도',
              route: AppRoutes.deleteAccount,
            ),
          if (widget.details && a.phase == EmailPhase.connected) ...[
            if (!a.canImport || c.progress.records.isNotEmpty)
              const Text('기존 계정 기록을 보존합니다. 기기 기록과 자동 합산하거나 덮어쓰지 않습니다.'),
            if (a.canImport && c.progress.records.isEmpty)
              OutlinedButton(
                key: const Key('importGuest'),
                onPressed: a.busy || !c.loaded || c.writeBlocked
                    ? null
                    : () async {
                        final ownerKey = a.connection?.key;
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialog) => AlertDialog(
                            title: const Text('빈 계정에 기기 기록 보관'),
                            content: const Text(
                              '클리어·최고점수·시도 수만 처음 보관합니다. 기기의 원본과 설정은 유지하며 기존 계정 기록이 있으면 덮어쓰지 않습니다. 이후 전투가 자동 동기화되는 기능은 아직 연결 전입니다.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialog, false),
                                child: const Text('취소'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(dialog, true),
                                child: const Text('기록 보관 동의'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && mounted) {
                          try {
                            final guest = await accountGame.guestSnapshot();
                            if (mounted && ownerKey != null) {
                              await a.importGuest(
                                guest,
                                expectedScopeKey: ownerKey,
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '게스트 기록을 읽지 못했습니다. 원본을 보존했으며 서버에 가져오지 않았습니다. 저장 상태를 확인해 주세요.',
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                child: const Text('기기 기록 최초 보관'),
              ),
          ],
          if (widget.details && a.hasIdentity)
            OutlinedButton(
              onPressed: a.busy ? null : a.refreshVerification,
              child: const Text('계정·기록 상태 다시 확인'),
            ),
          if (widget.details && a.hasIdentity) ...[
            OutlinedButton(
              key: const Key('switchAccount'),
              onPressed: a.busy || a.deletionPending
                  ? null
                  : () async {
                      await a.logout();
                      if (context.mounted && !a.hasIdentity) {
                        Navigator.pushNamed(context, AppRoutes.account);
                      }
                    },
              child: const Text('로그아웃 후 다른 계정으로 전환'),
            ),
            const RouteTile(title: '회원 탈퇴', route: AppRoutes.deleteAccount),
          ],
        ],
      ),
    );
  }
}

class EmailActionScreen extends StatefulWidget {
  const EmailActionScreen({super.key});
  @override
  State<EmailActionScreen> createState() => _EmailActionScreenState();
}

class _EmailActionScreenState extends State<EmailActionScreen> {
  final _link = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController();
  final _form = GlobalKey<FormState>();
  EmailAuthController? _auth;
  bool _visible = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth = AppServices.of(context).emailAuth;
  }

  @override
  void dispose() {
    _auth?.discardLink();
    for (final c in [_link, _password, _confirmation]) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = AppServices.of(context).emailAuth;
    return ListenableBuilder(
      listenable: a,
      builder: (_, _) => AppPage(
        title: '이메일 링크 확인',
        light: true,
        children: [
          const Text(
            '직접 요청해 받은 메일의 전체 링크를 붙여넣어 주세요. 링크를 지원 문의나 다른 사람에게 보내지 마세요. 자동으로 클립보드를 읽지 않습니다.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('emailActionLink'),
            controller: _link,
            obscureText: true,
            enabled: !a.busy,
            enableIMEPersonalizedLearning: false,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: '확인·재설정 링크'),
            keyboardType: TextInputType.url,
          ),
          FilledButton(
            key: const Key('inspectEmailLink'),
            onPressed: a.busy
                ? null
                : () async {
                    final raw = _link.text;
                    _link.clear();
                    await a.inspectLink(raw);
                  },
            child: const Text('링크 확인'),
          ),
          const EmailNotice(),
          if (a.pendingAction != null)
            AutofillGroup(
              onDisposeAction: AutofillContextAction.cancel,
              child: Form(
                key: _form,
                child: Column(
                  children: [
                    if (a.pendingAction!.mode == 'resetPassword') ...[
                      TextFormField(
                        key: const Key('newPassword'),
                        enabled: !a.busy,
                        enableIMEPersonalizedLearning: false,
                        controller: _password,
                        obscureText: !_visible,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        keyboardType: TextInputType.visiblePassword,
                        decoration: InputDecoration(
                          labelText: '새 비밀번호',
                          helperText: '15자 이상 · 문자 조합 강제 없음',
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
                        validator: (v) =>
                            v != null &&
                                v.runes.length >= 15 &&
                                v.length <= 4096
                            ? null
                            : '15자 이상 4096자 이내로 입력해 주세요.',
                      ),
                      TextFormField(
                        key: const Key('newPasswordConfirmation'),
                        enabled: !a.busy,
                        enableIMEPersonalizedLearning: false,
                        controller: _confirmation,
                        obscureText: !_visible,
                        autofillHints: const [AutofillHints.newPassword],
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: '새 비밀번호 확인',
                        ),
                        validator: (v) =>
                            v == _password.text ? null : '비밀번호가 일치하는지 확인해 주세요.',
                      ),
                    ],
                    FilledButton(
                      key: const Key('confirmEmailAction'),
                      onPressed: a.busy
                          ? null
                          : () async {
                              if (!_form.currentState!.validate()) return;
                              final value = _password.text;
                              final success = await a.confirmLink(value);
                              if (!mounted) return;
                              if (success) {
                                TextInput.finishAutofillContext(
                                  shouldSave: true,
                                );
                              }
                              _password.clear();
                              _confirmation.clear();
                            },
                      child: Text(
                        a.pendingAction!.mode == 'resetPassword'
                            ? '새 비밀번호로 재설정'
                            : '이메일 확인 완료',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const RouteTile(title: '이메일로 로그인', route: AppRoutes.login),
          const RouteTile(title: '새 재설정 메일 요청', route: AppRoutes.recovery),
          const RouteTile(title: '확인 메일 재요청', route: AppRoutes.verify),
        ],
      ),
    );
  }
}

class EmailChangeScreen extends StatefulWidget {
  const EmailChangeScreen({super.key});
  @override
  State<EmailChangeScreen> createState() => _EmailChangeScreenState();
}

class _EmailChangeScreenState extends State<EmailChangeScreen> {
  final _email = TextEditingController(), _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _visible = false;
  @override
  void dispose() {
    _email.dispose();
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = AppServices.of(context).emailAuth;
    return ListenableBuilder(
      listenable: a,
      builder: (_, _) => AppPage(
        title: '이메일 변경',
        light: true,
        children: [
          const Text(
            '현재 이메일 계정의 비밀번호로 다시 인증한 뒤 새 주소의 소유를 확인합니다. 확인 전에는 기존 주소를 유지합니다. 소셜 계정에 비밀번호를 추가하는 기능은 제공하지 않습니다.',
          ),
          const SizedBox(height: 16),
          AutofillGroup(
            onDisposeAction: AutofillContextAction.cancel,
            child: Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('changeEmailInput'),
                    controller: _email,
                    decoration: const InputDecoration(labelText: '새 이메일'),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.email],
                    validator: validateEmail,
                  ),
                  TextFormField(
                    key: const Key('reauthPassword'),
                    enabled: !a.busy,
                    enableIMEPersonalizedLearning: false,
                    controller: _password,
                    obscureText: !_visible,
                    keyboardType: TextInputType.visiblePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: '현재 비밀번호',
                      suffixIcon: IconButton(
                        tooltip: _visible ? '비밀번호 숨기기' : '비밀번호 표시',
                        onPressed: () => setState(() => _visible = !_visible),
                        icon: Icon(
                          _visible ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        v?.isNotEmpty == true ? null : '비밀번호를 입력해 주세요.',
                  ),
                  FilledButton(
                    key: const Key('changeEmailSubmit'),
                    onPressed: a.busy || !a.hasIdentity
                        ? null
                        : () async {
                            if (!_form.currentState!.validate()) return;
                            final password = _password.text;
                            _password.clear();
                            await a.changeEmail(_email.text, password);
                          },
                    child: const Text('재인증 후 새 주소 확인 요청'),
                  ),
                ],
              ),
            ),
          ),
          const EmailNotice(),
          const RouteTile(title: '메일 링크 확인', route: AppRoutes.emailAction),
          const RouteTile(title: '이메일로 로그인', route: AppRoutes.login),
        ],
      ),
    );
  }
}

class EmailLogoutScreen extends StatelessWidget {
  const EmailLogoutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final a = AppServices.of(context).emailAuth;
    return ListenableBuilder(
      listenable: a,
      builder: (_, _) => AppPage(
        title: '로그아웃',
        light: true,
        children: [
          const Text('이 기기의 계정 세션을 정리합니다. 기기 게임 기록·설정과 계정 기록은 삭제하지 않습니다.'),
          const EmailNotice(),
          OutlinedButton(
            key: const Key('emailLogout'),
            onPressed: a.busy ? null : a.logout,
            child: const Text('이 기기에서 로그아웃'),
          ),
          const RouteTile(title: '계정 연결', route: AppRoutes.account),
        ],
      ),
    );
  }
}
