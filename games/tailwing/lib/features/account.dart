import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/design.dart';
import '../core/readiness.dart';
import '../security/email_auth.dart';
import '../security/social_types.dart';
import 'email_actions.dart';
import 'account_management.dart';

String? validateEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '이메일을 입력해 주세요.';
  if (text.length > 254 ||
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
    return '이메일 형식을 확인해 주세요.';
  }
  return null;
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: '계정 연결',
    light: true,
    children: [
      const SizedBox(height: 16),
      Text(
        '같은 계정으로\n다음 출격도 이어서',
        style: appTheme(light: true).textTheme.headlineMedium,
      ),
      const SizedBox(height: 14),
      const Text(
        '계정 연결과 기기 기록 최초 보관을 이용할 수 있습니다. 다른 휴대폰으로 전체 기록을 자동 동기화하는 기능은 연결 준비 중입니다.',
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
        child: const Text('이메일로 로그인'),
      ),
      TextButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
        child: const Text('이메일로 회원가입'),
      ),
      const Divider(height: 32),
      const Text('소셜 계정으로 로그인', textAlign: TextAlign.center),
      const Text('처음 로그인하면 계정이 만들어집니다. 기기 기록은 자동으로 옮기지 않습니다.'),
      const SizedBox(height: 16),
      const SocialButtons(),
      const SizedBox(height: 20),
      const AccountStatusPanel(details: true),
      const RouteTile(title: '이메일 링크 확인', route: AppRoutes.emailAction),
      const RouteTile(title: '이메일 변경', route: AppRoutes.emailChange),
      const RouteTile(
        title: '기존 이메일 계정에 소셜 로그인 연결',
        route: AppRoutes.socialLink,
      ),
      const RouteTile(title: '계정 찾기 도움', route: AppRoutes.help),
      const RouteTile(title: '이용권만 먼저 확인', route: AppRoutes.entitlement),
    ],
  );
}

class SocialButtons extends StatelessWidget {
  const SocialButtons({
    this.link = false,
    this.password,
    this.allowed = true,
    super.key,
  });
  final bool link, allowed;
  final String Function()? password;
  Future<void> _login(
    BuildContext context,
    SocialProvider provider, {
    bool browser = false,
  }) async {
    final a = AppServices.of(context).emailAuth;
    final ok = await a.socialSignIn(
      provider,
      link: link,
      currentPassword: password?.call(),
      kakaoAccountOnly: browser,
    );
    if (!context.mounted) return;
    if (ok && a.phase == EmailPhase.connected) {
      // Return through any account/login forms to the screen that opened them.
      Navigator.popUntil(
        context,
        (route) =>
            route.isFirst ||
            !{
              AppRoutes.account,
              AppRoutes.login,
              AppRoutes.register,
              AppRoutes.socialLink,
            }.contains(route.settings.name),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = AppServices.of(context).emailAuth;
    return ListenableBuilder(
      listenable: a,
      builder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            key: const Key('googleLogin'),
            onPressed: a.busy || !allowed
                ? null
                : () => _login(context, SocialProvider.google),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1F1F1F),
              side: const BorderSide(color: Color(0xFF747775)),
            ),
            icon: Image.asset(
              'assets/brand/google_g.png',
              width: 20,
              height: 20,
            ),
            label: const Text('Google로 계속하기'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('kakaoLogin'),
            onPressed: a.busy || !allowed
                ? null
                : () => _login(context, SocialProvider.kakao),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFEE500),
              foregroundColor: const Color(0xFF191919),
            ),
            icon: const ExcludeSemantics(
              child: CustomPaint(size: Size(20, 20), painter: KakaoSymbol()),
            ),
            label: const Text('카카오 로그인'),
          ),
          TextButton(
            key: const Key('kakaoAccountLogin'),
            onPressed: a.busy || !allowed
                ? null
                : () => _login(context, SocialProvider.kakao, browser: true),
            child: const Text('카카오계정으로 로그인 · 브라우저'),
          ),
          if (defaultTargetPlatform == TargetPlatform.iOS) ...[
            const SizedBox(height: 12),
            SignInWithAppleButton(
              key: const Key('appleLogin'),
              onPressed: a.busy || !allowed
                  ? null
                  : () => _login(context, SocialProvider.apple),
              text: 'Apple로 계속하기',
            ),
          ],
        ],
      ),
    );
  }
}

class SocialLinkScreen extends StatefulWidget {
  const SocialLinkScreen({super.key});
  @override
  State<SocialLinkScreen> createState() => _SocialLinkScreenState();
}

class _SocialLinkScreenState extends State<SocialLinkScreen> {
  final _password = TextEditingController();
  bool _consent = false, _visible = false;
  @override
  void dispose() {
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
        title: '로그인 방법 연결',
        light: true,
        children: [
          const Text(
            '먼저 기존 이메일 계정으로 로그인해 주세요. 그 계정의 현재 비밀번호와 연결할 소셜 계정의 인증을 모두 확인합니다. 소셜 계정의 비밀번호는 이 앱에 입력하지 않습니다.',
          ),
          const SizedBox(height: 16),
          const Text(
            '이메일이 같아도 자동으로 합치지 않습니다. 이미 다른 게임 계정에 연결됐다면 두 기록을 보존하고 연결을 중단합니다.',
          ),
          const EmailNotice(),
          if (!a.canLinkSocial)
            const RouteTile(title: '이메일로 로그인', route: AppRoutes.login),
          AutofillGroup(
            onDisposeAction: AutofillContextAction.cancel,
            child: TextField(
              key: const Key('socialLinkPassword'),
              controller: _password,
              enabled: !a.busy && a.canLinkSocial,
              obscureText: !_visible,
              keyboardType: TextInputType.visiblePassword,
              autofillHints: const [AutofillHints.password],
              enableIMEPersonalizedLearning: false,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: '현재 이메일 계정 비밀번호',
                suffixIcon: IconButton(
                  tooltip: _visible ? '비밀번호 숨기기' : '비밀번호 표시',
                  onPressed: () => setState(() => _visible = !_visible),
                  icon: Icon(
                    _visible ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
          ),
          CheckboxListTile(
            key: const Key('socialLinkConsent'),
            value: _consent,
            onChanged: a.busy || !a.canLinkSocial
                ? null
                : (v) => setState(() => _consent = v ?? false),
            title: const Text('현재 이메일 계정에 선택한 로그인 방법을 연결합니다.'),
          ),
          SocialButtons(
            link: true,
            allowed: _consent && a.canLinkSocial,
            password: () => _password.text,
          ),
        ],
      ),
    );
  }
}

/// Exact symbol geometry from Kakao's official SVG (not a generic chat icon).
class KakaoSymbol extends CustomPainter {
  const KakaoSymbol();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 13, size.height / 13);
    canvas.translate(-61.5, -16.5);
    final p = Path()
      ..moveTo(68.001, 16.5225)
      ..cubicTo(64.4222, 16.5225, 61.5225, 19.0037, 61.5225, 22.0641)
      ..cubicTo(61.5225, 24.0312, 62.7219, 25.7596, 64.5292, 26.7423)
      ..lineTo(63.9181, 29.2113)
      ..cubicTo(63.8954, 29.285, 63.9132, 29.364, 63.9619, 29.4184)
      ..cubicTo(63.9975, 29.457, 64.0461, 29.478, 64.0931, 29.478)
      ..cubicTo(64.1337, 29.478, 64.1742, 29.464, 64.2082, 29.4341)
      ..lineTo(66.834, 27.5144)
      ..cubicTo(67.2117, 27.5723, 67.6007, 27.6039, 67.9994, 27.6039)
      ..cubicTo(71.5767, 27.6039, 74.478, 25.1226, 74.478, 22.0623)
      ..cubicTo(74.478, 19.002, 71.5783, 16.5225, 68.001, 16.5225)
      ..close();
    canvas.drawPath(p, Paint()..color = const Color(0xFF191919));
  }

  @override
  bool shouldRepaint(KakaoSymbol oldDelegate) => false;
}

class EmailScreen extends StatefulWidget {
  const EmailScreen({this.register = false, super.key});
  final bool register;
  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _visible = false;
  bool _terms = false;
  bool _privacy = false;
  bool _consentError = false;
  @override
  void dispose() {
    _email.dispose();
    _password.clear();
    _password.dispose();
    _confirmation.clear();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final a = AppServices.of(context).emailAuth;
    if (a.busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final valid = _form.currentState!.validate();
    final consent = !widget.register || (_terms && _privacy);
    setState(() => _consentError = !consent);
    if (!valid || !consent) return;
    final password = _password.text;
    setState(() => _visible = false);
    final ok = widget.register
        ? await a.register(_email.text, password)
        : await a.login(_email.text, password);
    if (!mounted) return;
    TextInput.finishAutofillContext(
      shouldSave: ok && !widget.register && a.hasIdentity,
    );
    _password.clear();
    _confirmation.clear();
    if (a.setupMissing) {
      await showPreparation(context, widget.register ? '이메일 회원가입' : '이메일 로그인');
    } else if (ok) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        a.phase == EmailPhase.connected ? AppRoutes.account : AppRoutes.verify,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = AppServices.of(context).emailAuth;
    return ListenableBuilder(
      listenable: a,
      builder: (_, _) => AppPage(
        title: widget.register ? '이메일 회원가입' : '이메일 로그인',
        light: true,
        children: [
          const SizedBox(height: 10),
          const Text('이메일을 계정 ID로 사용합니다. 전화번호는 받지 않습니다.'),
          const SizedBox(height: 12),
          const Text(
            '이메일과 비밀번호만 사용합니다. 연결된 인증 서비스에서 처리하며 비밀번호를 게임 기록이나 로그에 저장하지 않습니다.',
          ),
          const EmailNotice(),
          const SizedBox(height: 24),
          AutofillGroup(
            onDisposeAction: AutofillContextAction.cancel,
            child: Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('emailInput'),
                    enabled: !a.busy,
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      hintText: '이메일 주소',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    autocorrect: false,
                    enableSuggestions: false,
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    key: const Key('passwordInput'),
                    enabled: !a.busy,
                    enableIMEPersonalizedLearning: false,
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      suffixIcon: IconButton(
                        tooltip: _visible ? '비밀번호 숨기기' : '비밀번호 표시',
                        onPressed: () => setState(() => _visible = !_visible),
                        icon: Icon(
                          _visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    obscureText: !_visible,
                    keyboardType: TextInputType.visiblePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: [
                      widget.register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    textInputAction: widget.register
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onFieldSubmitted: widget.register ? null : (_) => _submit(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해 주세요.';
                      }
                      if (widget.register &&
                          (value.runes.length < 15 || value.length > 4096)) {
                        return '15자 이상 4096자 이내로 입력해 주세요.';
                      }
                      return null;
                    },
                  ),
                  if (widget.register) ...[
                    const SizedBox(height: 22),
                    TextFormField(
                      key: const Key('confirmPasswordInput'),
                      enabled: !a.busy,
                      enableIMEPersonalizedLearning: false,
                      controller: _confirmation,
                      decoration: const InputDecoration(labelText: '비밀번호 확인'),
                      obscureText: !_visible,
                      keyboardType: TextInputType.visiblePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) =>
                          value == _password.text && value?.isNotEmpty == true
                          ? null
                          : '비밀번호가 일치하는지 확인해 주세요.',
                    ),
                    const SizedBox(height: 24),
                    CheckboxListTile(
                      key: const Key('allConsent'),
                      value: _terms && _privacy,
                      onChanged: (value) => setState(() {
                        _terms = value ?? false;
                        _privacy = value ?? false;
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('필수 항목 전체 동의'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    ConsentRow(
                      label: '서비스 이용약관 (필수)',
                      route: AppRoutes.terms,
                      value: _terms,
                      onChanged: (value) => setState(() => _terms = value),
                    ),
                    ConsentRow(
                      label: '계정·기록 처리 안내 (필수)',
                      route: AppRoutes.privacy,
                      value: _privacy,
                      onChanged: (value) => setState(() => _privacy = value),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '현재 요청하는 선택 동의는 없습니다. 광고·마케팅 수신 동의를 추가하지 않습니다.',
                      ),
                    ),
                    if (_consentError)
                      Semantics(
                        liveRegion: true,
                        child: const Text(
                          '필수 안내를 확인하고 동의해 주세요.',
                          style: TextStyle(color: Color(0xFFB3261E)),
                        ),
                      ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ListenableBuilder(
                      listenable: AppServices.of(context).emailAuth,
                      builder: (_, _) => FilledButton(
                        key: const Key('emailSubmit'),
                        onPressed: AppServices.of(context).emailAuth.busy
                            ? null
                            : _submit,
                        child: Text(
                          AppServices.of(context).emailAuth.busy
                              ? '처리 중…'
                              : widget.register
                              ? '가입 요청'
                              : '로그인',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.register)
            const RouteTile(title: '이메일 확인 안내', route: AppRoutes.verify),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  widget.register ? AppRoutes.login : AppRoutes.register,
                ),
                child: Text(widget.register ? '이미 계정이 있나요? 로그인' : '회원가입'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.recovery),
                child: const Text('비밀번호 재설정'),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.help),
                child: const Text('계정 찾기 도움'),
              ),
            ],
          ),
          const Divider(height: 30),
          const SocialButtons(),
        ],
      ),
    );
  }
}

class ConsentRow extends StatelessWidget {
  const ConsentRow({
    required this.label,
    required this.route,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final String label;
  final String route;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: CheckboxListTile(
          value: value,
          onChanged: (value) => onChanged(value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(label),
        ),
      ),
      IconButton(
        tooltip: '$label 전문 보기',
        onPressed: () => Navigator.pushNamed(context, route),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final a = AppServices.of(context).emailAuth;
    return ListenableBuilder(
      listenable: a,
      builder: (_, _) => AppPage(
        title: '이메일 확인',
        light: true,
        children: [
          const InfoPanel(
            title: '내 이메일의 확인 링크를 열어 주세요',
            body: '가입을 요청했다면 메일과 스팸함을 확인한 뒤 이메일로 로그인해 주세요. 미확인 상태로 로그인한 경우 여기서 확인 메일을 다시 요청할 수 있습니다. 주소를 잘못 입력했다면 로그인 후 이메일 변경을 이용하세요.',
            icon: Icons.mark_email_read_outlined,
          ),
          const EmailNotice(),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('refreshEmailVerification'),
            onPressed: a.busy || !a.hasIdentity ? null : a.refreshVerification,
            child: const Text('확인 상태 다시 확인'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('resendEmailVerification'),
            onPressed: a.busy || !a.hasIdentity ? null : a.resend,
            child: const Text('확인 메일 재전송'),
          ),
          const RouteTile(title: '이메일로 로그인', route: AppRoutes.login),
          const RouteTile(title: '메일 링크 확인', route: AppRoutes.emailAction),
          const RouteTile(title: '이메일 변경', route: AppRoutes.emailChange),
          const RouteTile(title: '계정 찾기 도움', route: AppRoutes.help),
        ],
      ),
    );
  }
}

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _requested = false;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: '비밀번호 재설정',
    light: true,
    children: [
      const Text('가입할 때 사용한 이메일을 입력해 주세요. 계정의 존재 여부는 안내하지 않습니다.'),
      const SizedBox(height: 24),
      Form(
        key: _form,
        child: TextFormField(
          controller: _email,
          key: const Key('recoveryEmail'),
          decoration: const InputDecoration(labelText: '이메일'),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          validator: validateEmail,
        ),
      ),
      const SizedBox(height: 24),
      ListenableBuilder(
        listenable: AppServices.of(context).emailAuth,
        builder: (_, _) => FilledButton(
          key: const Key('sendResetEmail'),
          onPressed: AppServices.of(context).emailAuth.busy
              ? null
              : () async {
                  if (_form.currentState!.validate()) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    await AppServices.of(context).emailAuth
                        .requestReset(_email.text);
                    if (!mounted) return;
                    setState(() => _requested = true);
                  }
                },
          child: const Text('재설정 안내 확인'),
        ),
      ),
      const EmailNotice(),
      const RouteTile(title: '재설정 메일 링크 확인', route: AppRoutes.emailAction),
      if (_requested)
        Padding(
          padding: EdgeInsets.only(top: 20),
          child: Semantics(
            liveRegion: true,
            child: InfoPanel(
              title: AppServices.of(context).emailAuth.setupMissing
                  ? '복구 연결 준비 중'
                  : '재설정 요청 안내',
              body: AppServices.of(context).emailAuth.setupMissing
                  ? '현재 연결 설정이 없어 메일을 발송하지 않았습니다. 가입 여부와 관계없이 동일한 안내를 제공합니다.'
                  : '요청 결과는 위 안내를 확인해 주세요. 재설정 후에는 자동 로그인하지 않습니다. 새 비밀번호로 다시 로그인해 주세요.',
            ),
          ),
        ),
      const RouteTile(title: '계정 찾기 도움', route: AppRoutes.help),
    ],
  );
}

class AccountHelpScreen extends StatelessWidget {
  const AccountHelpScreen({super.key});
  @override
  Widget build(BuildContext context) => const AppPage(
    title: '계정 찾기 도움',
    light: true,
    children: [
      InfoPanel(
        title: '이메일 또는 연결한 소셜 계정을 확인해 주세요',
        body: '별도 아이디나 전화번호는 사용하지 않습니다. 이메일 가입을 선택했다면 본인이 소유한 주소로 복구를 요청하고, 소셜 가입을 선택했다면 같은 공급자로 로그인해 주세요. 타인의 이메일이나 계정 존재 여부는 조회하지 않습니다.',
      ),
      RouteTile(title: '비밀번호 재설정', route: AppRoutes.recovery),
      RouteTile(title: '이메일·소셜 선택', route: AppRoutes.account),
      RouteTile(title: '지원 안내', route: AppRoutes.support),
    ],
  );
}

class AccountDeletionInfoScreen extends StatelessWidget {
  const AccountDeletionInfoScreen({super.key});
  @override
  Widget build(BuildContext context) => const AccountDeletionScreen();
}
