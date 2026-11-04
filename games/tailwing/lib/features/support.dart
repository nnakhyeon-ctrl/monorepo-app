import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';
import '../core/readiness.dart';
import '../core/external_services.dart';

class ExternalLinkButton extends StatefulWidget {
  const ExternalLinkButton({required this.label, required this.uri, super.key});
  final String label;
  final Uri uri;
  @override
  State<ExternalLinkButton> createState() => _ExternalLinkButtonState();
}

class _ExternalLinkButtonState extends State<ExternalLinkButton> {
  bool _busy = false, _failed = false;
  Future<void> _open() async {
    if (_busy) {
      return;
    }
    final services = AppServices.of(context);
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      if (!services.contacts.permits(widget.uri) ||
          !await services.external
              .open(widget.uri)
              .timeout(const Duration(seconds: 8))) {
        throw StateError('open');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: _busy ? null : _open,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.open_in_new),
        label: Text(_busy ? '여는 중…' : widget.label),
      ),
      if (_failed)
        const Text(
          '열지 못했습니다. 연결 상태나 기본 브라우저·메일 앱을 확인하고 다시 눌러 주세요.',
          style: TextStyle(color: Palette.muted),
          semanticsLabel: '외부 연결 실패, 같은 버튼으로 다시 시도할 수 있습니다.',
        ),
    ],
  );
}

class AppVersionPanel extends StatefulWidget {
  const AppVersionPanel({super.key});
  @override
  State<AppVersionPanel> createState() => _AppVersionPanelState();
}

class _AppVersionPanelState extends State<AppVersionPanel> {
  Future<InstalledAppInfo>? _version;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _version ??= AppServices.of(context).appInfo
        .read()
        .timeout(const Duration(seconds: 5));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _version,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return SelectableText(
          '테일윙 · TAILWING · 앱 버전 ${snapshot.data!.label}',
          key: const Key('appVersion'),
        );
      }
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('앱 버전을 확인하지 못했습니다.'),
            TextButton(
              onPressed: () => setState(
                () =>
                    _version = AppServices.of(context).appInfo
                        .read()
                        .timeout(const Duration(seconds: 5)),
              ),
              child: const Text('앱 버전 다시 확인'),
            ),
          ],
        );
      }
      return const Text('앱 버전 확인 중…');
    },
  );
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final contacts = AppServices.of(context).contacts;
    return AppPage(
      title: '고객지원·앱 정보',
      children: [
        const AppVersionPanel(),
        const SectionTitle('문의하기'),
        if (contacts.support != null)
          ExternalLinkButton(label: '문의 페이지 열기', uri: contacts.support!),
        if (contacts.mail != null) ...[
          SelectableText(contacts.email),
          ExternalLinkButton(label: '이메일 앱으로 문의하기', uri: contacts.mail!),
        ],
        if (contacts.support == null && contacts.mail == null)
          const InfoPanel(
            title: '문의 경로 등록 대기',
            body: '운영자가 확인한 연락처를 아직 등록하지 않았습니다. 현재 문의를 전송할 수 없습니다. 아래에서 오류 신고 초안을 작성·복사할 수 있습니다.',
            icon: Icons.support_agent,
          ),
        const RouteTile(
          title: '오류 신고 초안 작성',
          subtitle: '내용 확인 후 직접 복사 · 자동 전송·로그 수집 없음',
          route: AppRoutes.report,
        ),
        const SectionTitle('도움말과 복구'),
        const RouteTile(title: '조작 방법', route: AppRoutes.controls),
        const RouteTile(title: '구독 구매 복원 안내', route: AppRoutes.restore),
        const RouteTile(title: '기록 이어하기', route: AppRoutes.cloud),
        const RouteTile(title: '계정 찾기 도움', route: AppRoutes.help),
        const SectionTitle('정책과 계정'),
        const RouteTile(title: '이용약관', route: AppRoutes.terms),
        const RouteTile(title: '개인정보처리방침', route: AppRoutes.privacy),
        if (contacts.terms != null)
          ExternalLinkButton(label: '공개 이용약관 열기', uri: contacts.terms!),
        if (contacts.privacy != null)
          ExternalLinkButton(label: '공개 개인정보처리방침 열기', uri: contacts.privacy!),
        if (contacts.terms == null || contacts.privacy == null)
          const Text('공개 정책 URL은 등록 대기입니다. 앱 내부 문안은 현재 개발용 초안입니다.'),
        const RouteTile(title: '회원 탈퇴·삭제 안내', route: AppRoutes.deleteAccount),
        const Text('계정 삭제·기록 불러오기·스토어 구매 복원은 별개입니다. 스토어 구독 해지는 구독 관리에서 확인하세요.'),
      ],
    );
  }
}

class ErrorReportScreen extends StatefulWidget {
  const ErrorReportScreen({super.key});
  @override
  State<ErrorReportScreen> createState() => _ErrorReportScreenState();
}

class _ErrorReportScreenState extends State<ErrorReportScreen> {
  final _form = GlobalKey<FormState>();
  final _steps = TextEditingController(), _problem = TextEditingController();
  InstalledAppInfo? _version;
  bool _loading = true, _failed = false, _copied = false;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final info = await AppServices.of(context).appInfo
          .read()
          .timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() => _version = info);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _steps.clear();
    _problem.clear();
    _steps.dispose();
    _problem.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    if (_version == null || !_form.currentState!.validate()) {
      return;
    }
    final report =
        '테일윙 · TAILWING 오류 신고 초안\n앱 버전: ${_version!.label}\n'
        '다시 발생시키는 순서:\n${_steps.text.trim()}\n문제 현상:\n${_problem.text.trim()}';
    try {
      await Clipboard.setData(ClipboardData(text: report));
      if (mounted) {
        setState(() => _copied = true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('복사하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: '오류 신고 초안',
    children: [
      const InfoPanel(
        title: '직접 확인한 내용만 복사합니다',
        body: '자동 전송하거나 원본 로그·이메일·토큰·구매 자료를 수집하지 않습니다. 비밀번호·개인정보·전체 영수증을 입력하지 마세요. 문의 경로가 등록되면 복사한 내용을 직접 전달할 수 있습니다.',
      ),
      if (_loading) const Text('앱 버전 확인 중…'),
      if (_failed) ...[
        const Text('앱 버전을 확인하지 못했습니다.'),
        TextButton(onPressed: _load, child: const Text('앱 버전 다시 확인')),
      ],
      if (_version != null) Text('앱 버전 ${_version!.label}'),
      const SizedBox(height: 16),
      Form(
        key: _form,
        child: Column(
          children: [
            TextFormField(
              key: const Key('reportSteps'),
              controller: _steps,
              minLines: 2,
              maxLines: 5,
              maxLength: 800,
              decoration: const InputDecoration(labelText: '문제가 발생한 순서'),
              validator: (s) =>
                  s == null || s.trim().isEmpty ? '발생 순서를 입력해 주세요.' : null,
            ),
            TextFormField(
              key: const Key('reportProblem'),
              controller: _problem,
              minLines: 2,
              maxLines: 5,
              maxLength: 800,
              decoration: const InputDecoration(labelText: '예상과 달랐던 현상'),
              validator: (s) =>
                  s == null || s.trim().isEmpty ? '문제 현상을 입력해 주세요.' : null,
            ),
          ],
        ),
      ),
      FilledButton(
        key: const Key('copyReport'),
        onPressed: !_loading && _version != null ? _copy : null,
        child: const Text('신고 초안 복사'),
      ),
      if (_copied)
        const Text(
          '초안을 복사했습니다. 문의가 전송된 것은 아닙니다.',
          semanticsLabel: '신고 초안 복사 완료, 문의 전송 안 됨',
        ),
    ],
  );
}
