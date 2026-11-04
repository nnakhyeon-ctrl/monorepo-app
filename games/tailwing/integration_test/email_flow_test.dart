import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/game/progress.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/security/email_auth.dart';
import 'package:raikeopeu2026/security/firebase_email.dart';

import '../test/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    expect(const bool.fromEnvironment('AIRZERO_AUTH_EMULATOR'), true);
    expect(const bool.fromEnvironment('AIRZERO_INTEGRATION'), true);
    final runtime = await createFirebaseEmailRuntime();
    await runtime.identity.signOut();
    await runtime.vault.clear();
    await runtime.vault.clearDeletion(); // Isolated demo test app only.
  });
  testWidgets(
    'native custom-token SDK exchange alone cannot bypass the app social grant',
    (tester) async {
      expect(const bool.fromEnvironment('AIRZERO_AUTH_EMULATOR'), true);
      expect(const bool.fromEnvironment('AIRZERO_INTEGRATION'), true);
      final runtime = await createFirebaseEmailRuntime();
      addTearDown(() async {
        await runtime.identity.signOut();
        await runtime.vault.clear();
      });
      // Auth Emulator accepts the same unsigned local custom-token format as its
      // Admin SDK. This fixture is confined to integration_test; no runtime fake
      // provider or cloud acceptance switch exists. Never print its output.
      String encode(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final token =
          '${encode({'alg': 'none', 'typ': 'JWT'})}.${encode({'iss': 'firebase-auth-emulator@example.com', 'sub': 'firebase-auth-emulator@example.com', 'aud': 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit', 'iat': now, 'exp': now + 3600, 'uid': 'fictional_native_unbound'})}.';
      await runtime.identity.signInCustomToken(token);
      expect(runtime.identity.uid, 'fictional_native_unbound');
      await expectLater(
        runtime.backend.call(
          '/v1/session/start',
          body: {},
          authenticated: true,
        ),
        throwsA(isA<EmailFailure>()),
      );
      expect(await runtime.vault.load(), isNull);
    },
  );
  testWidgets(
    'native email SDK verifies/imports/resets then isolates A/B and confirms/cancels/deletes only A',
    (tester) async {
      expect(const bool.fromEnvironment('AIRZERO_AUTH_EMULATOR'), true);
      expect(const bool.fromEnvironment('AIRZERO_INTEGRATION'), true);
      final email =
          'native_email_${DateTime.now().millisecondsSinceEpoch}@example.test';
      const password = 'Synthetic native email passphrase 2026';
      const replacement = 'Replacement native email passphrase 2026';
      final a = EmailAuthController(initialize: createFirebaseEmailRuntime);
      addTearDown(() async {
        await a.logout();
        a.dispose();
      });
      final repository = FixtureProgress()
        ..value = CampaignProgress(
          records: {
            1: const StageRecord(cleared: true, best: 777, attempts: 2),
          },
          sensitivity: 1.25,
          tutorialDone: true,
        );
      final snapshot = jsonEncode(repository.value.toJson());
      await tester.pumpWidget(
        RaikeopeuApp(
          emailAuth: a,
          progress: repository,
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> open(String route) async {
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .pushNamed(route);
        await tester.pumpAndSettle();
      }

      Future<void> press(Finder f) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pumpAndSettle();
        if (f.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            f,
            220,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        expect(
          f.hitTestable(),
          findsOneWidget,
          reason: 'action must be visible above the keyboard',
        );
        await tester.tap(f);
        for (var i = 0; i < 240; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 16));
          if (!a.busy) break;
        }
        await tester.pumpAndSettle();
        expect(a.busy, false);
      }

      Future<String> link(String type, {String? forEmail}) async =>
          (await tester.runAsync(() async {
            final client = HttpClient();
            try {
              // Test-only fixed emulator endpoint, exact fictional address; never logs mail or tokens.
              final r = await (await client.getUrl(
                Uri.parse(
                  'http://10.0.2.2:9299/emulator/v1/projects/demo-airzero-strike/oobCodes',
                ),
              )).close();
              final data = jsonDecode(
                await utf8.decodeStream(r),
              ) as Map<String, dynamic>;
              final values = (data['oobCodes'] as List)
                  .cast<Map<String, dynamic>>()
                  .where(
                    (v) =>
                        v['email'] == (forEmail ?? email) &&
                        v['requestType'] == type,
                  )
                  .toList();
              expect(
                values.isNotEmpty,
                true,
                reason: 'fictional local mail capture',
              );
              return values.last['oobLink'] as String;
            } finally {
              client.close(force: true);
            }
          }))!;
      await open(AppRoutes.settings);
      await press(find.text('로그인·회원가입'));
      await press(find.text('이메일로 회원가입'));
      await tester.enterText(find.byKey(const Key('emailInput')), email);
      await tester.enterText(find.byKey(const Key('passwordInput')), password);
      await tester.enterText(
        find.byKey(const Key('confirmPasswordInput')),
        password,
      );
      await press(find.byKey(const Key('allConsent')));
      await press(find.byKey(const Key('emailSubmit')));
      final firstRegistrationAt = DateTime.now();
      expect(a.phase, EmailPhase.verificationPending);
      expect(a.hasIdentity, false);
      await open(AppRoutes.login);
      await tester.enterText(find.byKey(const Key('emailInput')), email);
      await tester.enterText(find.byKey(const Key('passwordInput')), password);
      await press(find.byKey(const Key('emailSubmit')));
      expect(a.phase, EmailPhase.verificationPending);
      expect(a.hasIdentity, true);
      await open(AppRoutes.emailAction);
      final verify = await link('VERIFY_EMAIL');
      await tester.enterText(find.byKey(const Key('emailActionLink')), verify);
      await press(find.byKey(const Key('inspectEmailLink')));
      expect(a.pendingAction != null, true, reason: a.message);
      await press(find.byKey(const Key('confirmEmailAction')));
      expect(a.phase, EmailPhase.connected);
      expect(a.canImport, true);
      final services = AppServices.of(
        tester.element(find.byKey(const Key('authNotice'))),
      );
      // Exercise the real app HTTP allowlist, SDK ID token and session headers.
      // Default demo billing remains closed; this is not a store purchase test.
      final billingStatus = await tester.runAsync(
        () => a.billingRequest('status'),
      );
      expect(billingStatus?['ready'], false);
      expect(billingStatus?['verified'], false);
      expect(billingStatus?['owned'], isEmpty);
      final campaign = services.campaign;
      final initialOwner = a.connection!.key;
      final guest = await tester.runAsync(services.accountGame.guestSnapshot);
      expect(
        await tester.runAsync(
          () => a.importGuest(guest!, expectedScopeKey: initialOwner),
        ),
        true,
      );
      await tester.pumpAndSettle();
      expect(a.canImport, false);
      expect(jsonEncode(repository.value.toJson()), snapshot);
      await tester.runAsync(a.logout);
      await tester.pumpAndSettle();
      await open(AppRoutes.recovery);
      await tester.enterText(find.byKey(const Key('recoveryEmail')), email);
      await press(find.byKey(const Key('sendResetEmail')));
      final reset = await link('PASSWORD_RESET');
      await open(AppRoutes.emailAction);
      await tester.enterText(find.byKey(const Key('emailActionLink')), reset);
      await press(find.byKey(const Key('inspectEmailLink')));
      expect(a.pendingAction?.mode, 'resetPassword');
      await tester.enterText(find.byKey(const Key('newPassword')), replacement);
      await tester.enterText(
        find.byKey(const Key('newPasswordConfirmation')),
        replacement,
      );
      await press(find.byKey(const Key('confirmEmailAction')));
      expect(a.phase, EmailPhase.guest);
      expect(a.hasIdentity, false);
      expect(await tester.runAsync(() => a.login(email, password)), false);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 3100)),
      );
      expect(await tester.runAsync(() => a.login(email, replacement)), true);
      expect(a.phase, EmailPhase.connected);
      expect(a.serverRecordCount, 1);
      expect(jsonEncode(repository.value.toJson()), snapshot);

      Future<void> accountSettled() async {
        await tester.runAsync(() async {
          await services.accountGame.settled;
          await services.loadout.ready;
        });
        await tester.pumpAndSettle();
      }

      await accountSettled();
      expect(campaign.progress.records[1]?.best, 777);
      await tester.runAsync(
        () => campaign.setSelection(CatalogCategory.aircraft, 'vector'),
      );
      final aKey = a.connection!.key;
      final runtime = await tester.runAsync(createFirebaseEmailRuntime);
      await tester.runAsync(a.logout);
      await accountSettled();
      expect(campaign.progress.sensitivity, 1.25);

      // Exercise the real device cooldown rather than bypassing it with a new
      // controller or weakening server/source limits for this second signup.
      final registrationWait = firstRegistrationAt
          .add(const Duration(seconds: 61))
          .difference(DateTime.now());
      if (registrationWait > Duration.zero) {
        await tester.runAsync(() => Future<void>.delayed(registrationWait));
      }

      final bEmail =
          'native_account_b_${DateTime.now().millisecondsSinceEpoch}@example.test';
      expect(
        await tester.runAsync(() => a.register(bEmail, password)),
        true,
        reason: a.message,
      );
      expect(await tester.runAsync(() => a.login(bEmail, password)), true);
      final bVerify = await link('VERIFY_EMAIL', forEmail: bEmail);
      expect(await tester.runAsync(() => a.inspectLink(bVerify)), true);
      expect(await tester.runAsync(a.confirmLink), true);
      await accountSettled();
      expect(a.connection!.key == aKey, false);
      expect(campaign.progress.records, isEmpty);
      expect(
        campaign.progress.loadout.selected(CatalogCategory.aircraft),
        'aurora',
      );
      expect(services.loadout.premiumActive, false);
      await tester.runAsync(
        () => campaign.finish(
          runId: 'native_account_b_result',
          stage: 1,
          won: false,
          score: 400,
        ),
      );
      await tester.runAsync(a.logout);
      expect(await tester.runAsync(() => a.login(email, replacement)), true);
      await accountSettled();
      expect(a.connection!.key, aKey);
      expect(campaign.progress.records[1]?.best, 777);
      expect(
        campaign.progress.loadout.selected(CatalogCategory.aircraft),
        'vector',
      );
      expect(
        services.loadout.effectiveSelected(CatalogCategory.aircraft),
        'aurora',
      );

      expect(
        await tester.runAsync(
          () => a.prepareDeletion(password: 'synthetic incorrect password'),
        ),
        false,
      );
      expect(a.connection!.key, aKey);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 3100)),
      );
      expect(
        await tester.runAsync(() => a.prepareDeletion(password: replacement)),
        true,
      );
      expect(a.deletionPrepared, true);
      await tester.runAsync(a.cancelDeletion);
      expect(
        await tester.runAsync(() => runtime!.vault.loadDeletion()),
        isNull,
      );
      expect(a.connection!.key, aKey);
      expect(
        await tester.runAsync(() => a.prepareDeletion(password: replacement)),
        true,
      );
      expect(await tester.runAsync(a.commitDeletion), true);
      await accountSettled();
      expect(a.deletionPending, false);
      expect(a.hasIdentity, false);
      expect(
        await tester.runAsync(() => runtime!.vault.loadDeletion()),
        isNull,
      );
      expect(campaign.progress.records[1]?.best, 777);
      expect(campaign.progress.sensitivity, 1.25);
      expect(jsonEncode(repository.value.toJson()), snapshot);
      expect(await tester.runAsync(() => a.login(email, replacement)), false);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 3100)),
      );
      expect(await tester.runAsync(() => a.login(bEmail, password)), true);
      await accountSettled();
      expect(campaign.progress.records[1]?.best, 400);
      expect(a.serverRecordCount, 0);
      expect(jsonEncode(repository.value.toJson()), snapshot);
      await tester.runAsync(a.logout);
      await accountSettled();
      expect(a.hasIdentity, false);
      expect(a.connection, isNull);
      expect(await tester.runAsync(() => runtime!.vault.load()), isNull);
      expect(jsonEncode(repository.value.toJson()), snapshot);
      expect(tester.takeException(), isNull);
    },
  );
}
