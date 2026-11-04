import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/features/home.dart';
import 'package:raikeopeu2026/features/battle.dart';

import 'fixtures.dart';

Future<void> launch(WidgetTester tester, {ConnectionGateway? gateway}) async {
  await tester.pumpWidget(
    RaikeopeuApp(
      feedback: FixtureFeedback(),
      appInfo: FixtureAppInfo(),
      progress: FixtureProgress(),
      gateway: gateway ?? const UnconnectedGateway(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> open(
  WidgetTester tester,
  String route, {
  Object? arguments,
}) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  unawaited(navigator.pushNamed(route, arguments: arguments));
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 240);
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('free play starts once without a login or purchase gate', (
    tester,
  ) async {
    await tester.pumpWidget(
      RaikeopeuApp(
        feedback: FixtureFeedback(),
        appInfo: FixtureAppInfo(),
        progress: FixtureProgress(),
        assets: ImmediateAssets(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('startGame')));
    await tester.tap(find.byKey(const Key('startGame')));
    await tester.tap(find.byKey(const Key('startGame')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(BattleScreen), findsOneWidget);
    expect(find.byKey(const Key('useSkill')), findsOneWidget);
    expect(find.text('로그인 완료'), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
    'login validates, supports autofill and visibility, never authenticates',
    (tester) async {
      await launch(tester);
      await open(tester, AppRoutes.login);
      await press(tester, find.byKey(const Key('emailSubmit')));
      expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
      expect(find.text('비밀번호를 입력해 주세요.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('emailInput')),
        'pilot@example.invalid',
      );
      await tester.enterText(
        find.byKey(const Key('passwordInput')),
        'Fictional-Pass-2026',
      );
      final password = find.descendant(
        of: find.byKey(const Key('passwordInput')),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(password).obscureText, isTrue);
      expect(
        tester.widget<EditableText>(password).autofillHints,
        contains(AutofillHints.password),
      );
      await press(tester, find.byTooltip('비밀번호 표시'));
      expect(tester.widget<EditableText>(password).obscureText, isFalse);
      await press(tester, find.byKey(const Key('emailSubmit')));
      expect(find.text('이메일 로그인 연결 준비 중'), findsOneWidget);
      expect(tester.widget<EditableText>(password).controller.text, isEmpty);
      expect(find.text('로그인 완료'), findsNothing);
    },
  );

  testWidgets(
    'signup consents start unchecked and legal pages preserve the form',
    (tester) async {
      await launch(tester);
      await open(tester, AppRoutes.register);
      await tester.enterText(
        find.byKey(const Key('emailInput')),
        'pilot@example.invalid',
      );
      await tester.enterText(
        find.byKey(const Key('passwordInput')),
        'Fictional-Pass-2026',
      );
      await tester.enterText(
        find.byKey(const Key('confirmPasswordInput')),
        'Fictional-Pass-2026',
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('allConsent')))
            .value,
        isFalse,
      );
      await press(tester, find.byKey(const Key('emailSubmit')));
      expect(find.text('필수 안내를 확인하고 동의해 주세요.'), findsOneWidget);
      await press(tester, find.byTooltip('서비스 이용약관 (필수) 전문 보기'));
      expect(find.text('연결 전 안내 초안'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await press(tester, find.byKey(const Key('allConsent')));
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('allConsent')))
            .value,
        isTrue,
      );
      await press(tester, find.byKey(const Key('emailSubmit')));
      expect(find.text('이메일 회원가입 연결 준비 중'), findsOneWidget);
    },
  );

  testWidgets(
    'recovery reveals neither account existence nor the submitted address',
    (tester) async {
      await launch(tester);
      await open(tester, AppRoutes.recovery);
      for (final email in [
        'pilot@example.invalid',
        'unknown@example.invalid',
      ]) {
        await tester.enterText(find.byKey(const Key('recoveryEmail')), email);
        await press(tester, find.text('재설정 안내 확인'));
        expect(find.text('복구 연결 준비 중'), findsOneWidget);
        expect(find.textContaining('가입 여부와 관계없이 동일한 안내'), findsOneWidget);
      }
      expect(find.text('계정을 찾았습니다'), findsNothing);
    },
  );

  testWidgets('all approved screens open and invalid input is not reflected', (
    tester,
  ) async {
    await launch(tester);
    for (final route in AppRoutes.all.where(
      (route) => route != AppRoutes.home && route != AppRoutes.battle,
    )) {
      await open(tester, route);
      expect(find.byType(AppBar), findsOneWidget, reason: route);
      expect(tester.takeException(), isNull, reason: route);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
    }
    await open(tester, '/unknown?private=fictional');
    expect(find.text('올바르지 않은 경로입니다'), findsOneWidget);
    expect(find.textContaining('private=fictional'), findsNothing);
    await press(tester, find.text('첫 화면으로'));
    await open(tester, AppRoutes.login, arguments: {'unexpected': 'fictional'});
    expect(find.text('올바르지 않은 경로입니다'), findsOneWidget);
  });

  testWidgets('small screen, large text and keyboard keep forms reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await launch(tester);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is HomeMenu && widget.route == AppRoutes.cloud,
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await press(tester, find.byTooltip('조작 방법'));
    await tester.scrollUntilVisible(find.text('무료 보호막'), 220);
    expect(find.text('무료 보호막'), findsOneWidget);
    await press(tester, find.byType(BackButton));
    await press(tester, find.text('전투기·장비'));
    expect(tester.takeException(), isNull);
    await press(tester, find.byType(BackButton));
    await press(tester, find.text('환경설정'));
    await press(tester, find.text('구독 관리'));
    expect(find.text('기본 플레이는 무료'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await press(tester, find.byType(BackButton));
    await press(tester, find.text('기록 이어하기'));
    expect(find.text('기록 연결 준비 중'), findsOneWidget);
    await press(tester, find.byType(BackButton));
    await press(tester, find.byType(BackButton));
    await open(tester, AppRoutes.register);
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await press(tester, find.byKey(const Key('emailSubmit')));
    expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading blocks duplicate taps and errors stay private', (
    tester,
  ) async {
    final gateway = PendingGateway();
    await launch(tester, gateway: gateway);
    await open(tester, AppRoutes.cloud);
    await tester.tap(find.text('동기화 연결 확인'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
      isNull,
    );
    expect(gateway.calls, 1);
    gateway.result.completeError(StateError('fictional-sensitive-detail'));
    await tester.pumpAndSettle();
    expect(find.text('확인하지 못했습니다'), findsOneWidget);
    expect(find.textContaining('fictional-sensitive-detail'), findsNothing);
    expect(find.text('복원 완료'), findsNothing);
  });

  testWidgets('unconfigured store never grants or restores access', (
    tester,
  ) async {
    await launch(tester);
    await open(tester, AppRoutes.restore);
    await press(tester, find.text('구매 복원 연결 확인'));
    expect(find.text('연결 준비 중입니다'), findsOneWidget);
    expect(find.text('복원 완료'), findsNothing);
  });

  testWidgets('background privacy cover clears on resume', (tester) async {
    await launch(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byIcon(Icons.shield_outlined), findsNothing);
  });

  testWidgets('premium catalog details never equip or grant content', (
    tester,
  ) async {
    await launch(tester);
    await open(tester, AppRoutes.hangar);
    await press(tester, find.byKey(const Key('category-character')));
    await tester.scrollUntilVisible(find.byKey(const Key('catalog-tw_owl')), 240);
    expect(find.text('루노 · 부엉이'), findsOneWidget);
    await press(tester, find.byKey(const Key('catalog-tw_owl')));
    expect(find.textContaining('유효 이용권을 확인한 뒤에만'), findsOneWidget);
    await press(tester, find.text('환경설정에서 구독 보기'));
    expect(find.text('환경설정'), findsOneWidget);
    expect(find.text('구독 완료'), findsNothing);
  });

  testWidgets(
    'enhanced skills require a subscription and cannot activate from details',
    (tester) async {
      await launch(tester);
      await open(tester, AppRoutes.hangar);
      await press(tester, find.byKey(const Key('category-skill')));
      await press(tester, find.byKey(const Key('catalog-mecha')));
      expect(find.text('메카 전환'), findsWidgets);
      expect(find.textContaining('유효 이용권을 확인한 뒤에만'), findsOneWidget);
      expect(find.byKey(const Key('select-detail-mecha')), findsNothing);
      await press(tester, find.text('환경설정에서 구독 보기'));
      expect(find.text('환경설정'), findsOneWidget);
      expect(find.text('구독 완료'), findsNothing);
    },
  );

  testWidgets(
    'monthly and annual plans show total billing periods without subscribing',
    (tester) async {
      await launch(tester);
      await open(tester, AppRoutes.entitlement);
      final monthly = find.byKey(const Key('subscription-monthly'));
      final annual = find.byKey(const Key('subscription-annual'));
      await tester.scrollUntilVisible(monthly, 240);
      expect(tester.widget<ChoiceChip>(monthly).selected, isFalse);
      expect(tester.widget<ChoiceChip>(annual).selected, isFalse);
      await press(tester, monthly);
      expect(find.textContaining('1개월마다 갱신'), findsOneWidget);
      await press(tester, annual);
      expect(find.textContaining('연간 총 결제액'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(monthly).selected, isFalse);
      await press(tester, find.text('이용권 확인'));
      expect(find.text('연결 준비 중입니다'), findsOneWidget);
      expect(find.text('구독 완료'), findsNothing);
    },
  );

  testWidgets(
    'new catalog and battle concept tolerate large text on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await launch(tester);
      await open(tester, AppRoutes.hangar);
      await press(tester, find.byKey(const Key('category-equipment')));
      await press(tester, find.byKey(const Key('catalog-prism')));
      expect(find.text('프리즘 가드'), findsWidgets);
      expect(tester.takeException(), isNull);
      await press(tester, find.text('닫기'));
      await open(tester, AppRoutes.battlePreview);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'iOS offers Apple alongside Google and Kakao without simulated login',
    (tester) async {
      await launch(tester);
      await open(tester, AppRoutes.account);
      expect(find.byKey(const Key('googleLogin')), findsOneWidget);
      expect(find.byKey(const Key('kakaoLogin')), findsOneWidget);
      await press(tester, find.byKey(const Key('appleLogin')));
      expect(find.byKey(const Key('authNotice')), findsOneWidget);
      expect(find.text('로그인 완료'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('primary actions have accessible labels and touch targets', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await launch(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('startGame')), 240);
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await open(tester, AppRoutes.login);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}

class PendingGateway implements ConnectionGateway {
  final result = Completer<CheckOutcome>();
  int calls = 0;
  @override
  Future<CheckOutcome> check(ConnectionArea area) {
    calls++;
    return result.future;
  }
}
