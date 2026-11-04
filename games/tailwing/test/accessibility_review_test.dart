import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';

import 'basic_screens_test.dart' show open;
import 'fixtures.dart';

void main() {
  testWidgets(
    'login stays reachable with a small screen, large text and keyboard; autofill/paste are retained',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          RaikeopeuApp(
            progress: FixtureProgress(),
            feedback: FixtureFeedback(),
          ),
        );
        await tester.pumpAndSettle();
        await open(tester, AppRoutes.login);
        final mail = find.byKey(const Key('emailInput'));
        final password = find.byKey(const Key('passwordInput'));
        await tester.ensureVisible(password);
        await tester.pumpAndSettle();
        await tester.tap(password);
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.enterText(mail, 'developer@example.test');
        await tester.enterText(password, 'FICTIONAL pasted password');
        expect(
          tester
              .widget<TextField>(
                find.descendant(of: mail, matching: find.byType(TextField)),
              )
              .autofillHints,
          contains(AutofillHints.email),
        );
        expect(
          tester
              .widget<TextField>(
                find.descendant(of: password, matching: find.byType(TextField)),
              )
              .autofillHints,
          contains(AutofillHints.password),
        );
        await tester.ensureVisible(find.byKey(const Key('emailSubmit')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<TextFormField>(password).controller!.text,
          'FICTIONAL pasted password',
        );
        expect(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(tester, meetsGuideline(androidTapTargetGuideline));
        expect(tester, meetsGuideline(textContrastGuideline));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'background privacy cover removes account form semantics and restores them on resume',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          RaikeopeuApp(
            progress: FixtureProgress(),
            feedback: FixtureFeedback(),
          ),
        );
        await tester.pumpAndSettle();
        await open(tester, AppRoutes.login);
        String visibleSemantics() => tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!
            .toStringDeep();
        expect(visibleSemantics(), contains('이메일'));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pumpAndSettle();
        expect(visibleSemantics(), isNot(contains('이메일')));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(visibleSemantics(), contains('이메일'));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        semantics.dispose();
      }
    },
  );
}
