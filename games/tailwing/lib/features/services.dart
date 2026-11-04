import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/readiness.dart';
import 'subscription_plans.dart';
import '../game/catalog.dart';
import '../core/external_services.dart';
import 'support.dart';
import 'settings.dart' show LocalSaveStatus;

class EntitlementScreen extends StatelessWidget {
  const EntitlementScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: '구독 관리',
    children: [
      InfoPanel(
        title: '기본 플레이는 무료',
        body: '기본 기체·기본 캐릭터·기본 사격·보호막은 무료입니다. 현재 전투에서는 이동·자동 사격·2초 보호막을 바로 이용할 수 있습니다. 구독이나 결제 수단 등록이 필요하지 않습니다.',
        icon: Icons.flight_takeoff,
      ),
      SectionTitle('프리미엄 구독'),
      InfoPanel(
        title: '추가 콘텐츠로 나만의 구성',
        body: '추가 기체·스킬·캐릭터·아이템/강화 효과를 구독 유효기간 동안 이용하는 방식입니다. 가입만으로 혜택이 활성화되지 않으며 스토어와 서버에서 이용권을 확인해야 합니다.',
        icon: Icons.verified_user_outlined,
      ),
      SectionTitle('이용권 상태'),
      const SubscriptionStatusPanel(),
      SizedBox(height: 12),
      SubscriptionPlans(),
      SizedBox(height: 20),
      const AccessCheckAction(label: '이용권 확인'),
      SizedBox(height: 12),
      const SectionTitle('구독에 포함된 능력'),
      for (final entry in catalogEntries.where((e) => e.premium))
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '${entry.name}\n${entry.detail}\n월간·연간 구독의 동일 혜택에 포함 · 개별 판매 없음',
          ),
        ),
      const RouteTile(title: '무료·유료 구성 선택', route: AppRoutes.hangar),
      RouteTile(
        title: '구독 구매 복원',
        subtitle: '이전에 결제한 구독 다시 확인 · 새 결제 없음',
        route: AppRoutes.restore,
        icon: Icons.restore,
      ),
      RouteTile(
        title: '계정 연결',
        subtitle: '다른 휴대폰에서 기록 이어하기',
        route: AppRoutes.account,
      ),
      SectionTitle('해지와 만료'),
      Text(
        '자동 갱신을 중단해도 공식 만료 시각 또는 적용되는 유예기간까지 혜택을 유지합니다. 만료되면 구독 전용 콘텐츠만 잠기며 무료 기본 플레이·성장 기록은 유지합니다.',
      ),
      SizedBox(height: 16),
      if (storeManagementUrl(Theme.of(context).platform) case final uri?)
        ExternalLinkButton(
          key: const Key('storeManagement'),
          label: '스토어에서 구독 관리',
          uri: uri,
        ),
      const Text('구매한 스토어 계정의 공식 구독 목록을 엽니다. 앱 계정 로그인·기록 동기화·새 구매와는 별개입니다.'),
      RouteTile(title: '구독·해지·환불 안내', route: AppRoutes.paymentTerms),
      RouteTile(title: '이용약관', route: AppRoutes.terms),
      RouteTile(title: '개인정보 안내', route: AppRoutes.privacy),
    ],
  );
}

class RestoreScreen extends StatelessWidget {
  const RestoreScreen({super.key});
  @override
  Widget build(BuildContext context) => const AppPage(
    title: '구독 구매 복원',
    children: [
      InfoPanel(
        title: '구매한 스토어 계정으로 확인하세요',
        body: '같은 스토어 계정과 같은 앱 계정의 구독을 다시 검증합니다. 새 결제를 시작하지 않으며 게임 기록 불러오기와 별개입니다. 서버 연결 전이나 다른 계정의 구매는 해금하지 않습니다.',
        icon: Icons.restore,
      ),
      SizedBox(height: 24),
      AccessCheckAction(label: '구매 복원 연결 확인', restore: true),
      PurchaseActions(restoreOnly: true),
      RouteTile(title: '기록 이어하기', route: AppRoutes.cloud),
      RouteTile(title: '구독·해지·환불 안내', route: AppRoutes.paymentTerms),
    ],
  );
}

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: '기록 이어하기',
    children: [
      InfoPanel(
        title: '기록 연결 준비 중',
        body: '이메일 계정 메뉴에서 본인 서버 기록 확인과 빈 계정의 최초 기록 보관을 사용할 수 있습니다. 일반 전투 결과·성장·재화의 자동 동기화와 다른 휴대폰에서 플레이 이어하기는 아직 연결 전입니다.',
        icon: Icons.cloud_outlined,
      ),
      SectionTitle('다른 휴대폰에서 이어하려면'),
      Text(
        '현재 기기의 서버 저장 완료를 확인한 뒤 다른 휴대폰에서 같은 계정으로 로그인합니다. 동기화 대기·실패·충돌 상태는 저장 완료가 아닙니다.',
      ),
      SizedBox(height: 20),
      ConnectionAction(label: '동기화 연결 확인', area: ConnectionArea.cloud),
      RouteTile(title: '계정 연결', route: AppRoutes.account),
      const SectionTitle('이 기기의 게임 기록'),
      ListenableBuilder(
        listenable: AppServices.of(context).campaign,
        builder: (context, _) {
          final c = AppServices.of(context).campaign;
          return InfoPanel(
            title: !c.loaded
                ? '기록 읽는 중'
                : c.writeBlocked
                ? '기록 보호 모드'
                : c.saveFailed
                ? '저장 재시도 필요'
                : '기기 저장 사용 중',
            body:
                '해금: 작전 ${c.progress.unlocked}\n클리어: ${c.progress.records.values.where((r) => r.cleared).length}개\n'
                '${c.recovered ? '손상된 사본 대신 정상 기록을 복구했습니다.\n' : ''}'
                '${c.writeBlocked ? '읽을 수 없거나 더 최신인 파일을 보존했습니다. 기존 파일을 덮어쓰지 않습니다.\n' : ''}'
                '앱을 닫아도 유지됩니다. 앱 삭제·데이터 지우기는 기기 기록을 삭제합니다. 서버 동기화는 아직 연결되지 않았습니다.',
            icon: Icons.save_outlined,
          );
        },
      ),
      const RouteTile(title: '작전별 최고 기록', route: AppRoutes.stages),
      const LocalSaveStatus(),
    ],
  );
}

enum LegalKind { terms, privacy, payment }

class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.kind, super.key});
  final LegalKind kind;
  @override
  Widget build(BuildContext context) {
    final title = switch (kind) {
      LegalKind.terms => '이용약관',
      LegalKind.privacy => '개인정보처리방침',
      LegalKind.payment => '구독·해지·환불 안내',
    };
    final sections = switch (kind) {
      LegalKind.terms => <(String, String)>[
        (
          '이용 범위',
          '기본 기체·캐릭터·사격·보호막과 일반 스테이지는 무료 제공 범위입니다. 추가 기체·스킬·캐릭터·아이템/강화 효과는 유효한 구독으로 이용하는 계획입니다. 기본 무료 이용은 자동 유료 전환 체험이 아니며 결제 수단을 요구하지 않습니다.',
        ),
        (
          '게임 기록',
          '진행·최고점수·선택과 설정은 기기에 저장합니다. 계정 확인 뒤 동의한 최초 기록 보관과 계정별 캐시 분리를 준비했습니다. 모든 전투 기록의 자동 동기화와 다른 기기 이어하기는 실제 연결 검증 전이며 충돌 기록을 자동 합산하지 않습니다.',
        ),
        (
          '구매와 지원',
          '가격·출시 국가·운영자·지원 연락처·실제 서비스 조건은 확정 전입니다. 결제와 서비스를 연결한 뒤 조건을 확정해야 하며 현재 이 화면으로 계약이나 구매가 체결되지 않습니다.',
        ),
      ],
      LegalKind.privacy => <(String, String)>[
        (
          '현재 앱에서 처리하는 정보',
          '클리어·최고점수·선택과 소리·진동·조작 설정, 선택적 통계는 기기에 저장합니다. 인증 연결 설정이 있으면 앱 시작 때 이전 로그인 상태를 확인하며 Firebase 인증·앱 무결성 서비스가 연결될 수 있습니다. 이메일 가입·확인·복구와 소셜 로그인은 필요한 인증 정보를 처리합니다. 비밀번호·인증 토큰은 게임 기록 파일이나 앱 관리 로그에 저장하지 않으며 인증 SDK의 세션 보관은 별도입니다. 계정 확인 뒤 동의한 최초 기록만 업로드하고 모든 전투를 자동 업로드하지 않습니다.',
        ),
        (
          '오류 신고 초안',
          '직접 입력한 재현 순서·문제 현상과 앱 버전만 요청할 때 클립보드로 복사합니다. 자동 문의 전송·원본 로그 수집은 하지 않으며 화면을 닫으면 작성 내용을 메모리에서 정리합니다. 복사한 내용은 사용자가 기기 클립보드에서 관리합니다.',
        ),
        (
          '연결 이후 처리 계획',
          '이메일·카카오·Google·Apple 인증과 스토어 SDK가 처리하는 식별자·세션·보안 메타데이터를 공개 고지와 대조해야 합니다. 구독 구매·복원은 확인된 앱 계정과 스토어 거래를 서버에서 검증한 뒤 반영하며 현재 실제 연결은 미완료입니다. 전화번호·신분증·카드·연락처를 추가 요구하지 않습니다.',
        ),
        (
          '삭제와 권리',
          '계정 삭제와 계정 게임 기록 초기화·이 기기 캐시 삭제·스토어 환불은 다른 동작입니다. 삭제 후 오래된 기기의 기록 재업로드를 막는 절차와 보관 예외를 공개 전 확정합니다.',
        ),
        (
          '확정 전 항목',
          '운영자·연락처·처리 지역·실제 SDK 동작·보관 기간·국외 이전·외부 삭제 요청 경로는 아직 미정입니다. 이 안내는 기본 화면용 초안입니다.',
        ),
      ],
      LegalKind.payment => <(String, String)>[
        (
          '선택형 구독',
          '기본 플레이는 무료이고 프리미엄 콘텐츠만 구독 대상입니다. 월간·연간 구독을 제공하며 가격은 관리자 최종 검토 후 스토어에서 설정합니다. 각 주기의 총 결제액·자동 갱신 조건과 해지 방법을 구매 전에 표시합니다. 현재 실제 결제는 발생하지 않습니다.',
        ),
        (
          '해지·만료·유예',
          '자동 갱신 중단은 즉시 만료가 아닙니다. 공식 유효기간과 적용되는 유예기간까지 혜택을 유지하며, 만료·계정 보류·환불/철회는 공식 상태에 따라 구독 콘텐츠만 제한합니다. 기본 플레이와 기존 게임 기록은 유지합니다.',
        ),
        (
          '복원과 환불',
          '구매가 귀속된 앱 계정과 결제한 스토어 계정으로 복원하고 서버에서 검증합니다. 이메일이 같다는 이유로 다른 계정이나 OS/스토어에 구매를 자동 이전하지 않습니다. 복원은 새 구독을 만들지 않습니다. 계정 삭제와 자동 갱신 중단·환불은 별개입니다.',
        ),
        (
          '기록 이어하기',
          '구매 복원과 게임 기록 복구는 별개이며 저장된 기체·스킬 선택만으로 이용권이 발급되지 않습니다. 탈퇴 후 재가입 구매 복구는 본인 확인과 별도 지원 정책 검증이 필요하고 자동 처리하지 않습니다.',
        ),
      ],
    };
    return AppPage(
      title: title,
      light: true,
      children: [
        const InfoPanel(
          title: '연결 전 안내 초안',
          body: '정식 서비스 조건과 공개 페이지가 확정되면 실제 처리 내용에 맞춰 안내합니다.',
        ),
        for (final section in sections) ...[
          SectionTitle(section.$1),
          Text(section.$2),
        ],
        if (kind == LegalKind.privacy)
          const RouteTile(title: '회원 탈퇴 안내', route: AppRoutes.deleteAccount),
        const SizedBox(height: 24),
      ],
    );
  }
}

class InvalidRouteScreen extends StatelessWidget {
  const InvalidRouteScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: '화면을 열 수 없습니다',
    children: [
      const InfoPanel(
        title: '올바르지 않은 경로입니다',
        body: '지원하지 않는 링크나 입력으로 화면을 열지 않습니다. 첫 화면에서 다시 선택해 주세요.',
        icon: Icons.error_outline,
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () =>
            Navigator.of(context)
                .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false),
        child: const Text('첫 화면으로'),
      ),
    ],
  );
}

class AccessCheckAction extends StatefulWidget {
  const AccessCheckAction({
    required this.label,
    this.restore = false,
    super.key,
  });
  final String label;
  final bool restore;
  @override
  State<AccessCheckAction> createState() => _AccessCheckActionState();
}

class _AccessCheckActionState extends State<AccessCheckAction> {
  bool _checked = false;
  Future<void> _check() async {
    final loadout = AppServices.of(context).loadout;
    if (loadout.busy) return;
    await loadout.refresh(restore: widget.restore);
    if (mounted) setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    final loadout = AppServices.of(context).loadout;
    return ListenableBuilder(
      listenable: loadout,
      builder: (context, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: loadout.busy ? null : _check,
            child: loadout.busy
                ? const Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      Text('이용권 확인 중'),
                    ],
                  )
                : Text(widget.label),
          ),
          if (_checked)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(
                liveRegion: true,
                child: InfoPanel(
                  title: loadout.lastCheckFailed
                      ? '이용권 확인 실패 · 다시 시도해 주세요'
                      : loadout.premiumActive
                      ? '구독 이용권 확인됨'
                      : loadout.access.status == AccessStatus.unverified
                      ? '연결 준비 중입니다'
                      : '유효 이용권이 없습니다',
                  body: loadout.lastCheckFailed
                      ? '연결 상태를 확인한 뒤 같은 버튼으로 다시 시도하세요. 확인 실패를 구매 성공이나 새 권한으로 처리하지 않습니다.'
                      : loadout.premiumActive
                      ? '검증된 유효기간 동안 구독 콘텐츠를 선택할 수 있습니다.'
                      : loadout.access.status == AccessStatus.unverified
                      ? '스토어와 서버가 연결되지 않아 구매·복원을 확인하지 못했습니다. 유료 권한을 부여하지 않았습니다. 기본 무료 구성은 계속 사용할 수 있습니다.'
                      : '구독 콘텐츠를 사용할 수 없습니다. 무료 캐릭터·사격·보호막은 계속 이용할 수 있습니다.',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SubscriptionStatusPanel extends StatelessWidget {
  const SubscriptionStatusPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppServices.of(context).loadout;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final access = c.access;
        final until = access.validUntil?.toLocal();
        final period = until == null
            ? '유효기간 미확인'
            : '${MaterialLocalizations.of(context).formatFullDate(until)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(until), alwaysUse24HourFormat: true)}까지';
        return InfoPanel(
          title: c.busy
              ? '이용권 확인 중'
              : c.premiumActive
              ? '구독 이용 중'
              : c.lastCheckFailed
              ? '이용권 확인 실패'
              : access.status == AccessStatus.unverified
              ? '스토어 연결 준비 중 · 구독 여부 미확인'
              : '유효한 구독 이용권 없음',
          body: c.premiumActive
              ? '${access.storeLabel ?? '검증된 스토어'} · ${access.periodLabel ?? '기간 종류 미확인'}\n$period\n'
                    '${access.inGrace
                        ? '공식 유예기간 적용 중'
                        : access.autoRenew == false
                        ? '자동 갱신 중단 · 남은 기간 이용 가능'
                        : access.autoRenew == true
                        ? '자동 갱신 사용 중'
                        : '자동 갱신 상태 미확인'}'
                    '${c.lastCheckFailed ? '\n최신 조회 실패 · 기존 검증된 유효기간까지만 유지합니다.' : ''}'
              : '$period\n기본 플레이는 계속 무료입니다. 구매 복원과 기록 동기화는 별개이며 미확인 상태에서 새 유료 권한을 부여하지 않습니다.',
          icon: Icons.verified_user_outlined,
        );
      },
    );
  }
}
