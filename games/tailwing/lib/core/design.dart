import 'package:flutter/material.dart';

import 'readiness.dart';

abstract final class Palette {
  static const navy = Color(0xFF09131E);
  static const panel = Color(0xFF132330);
  static const teal = Color(0xFF66E2D3);
  static const muted = Color(0xFFBAC9D3);
}

ThemeData appTheme({bool light = false}) {
  final colors = ColorScheme.fromSeed(
    seedColor: light ? Colors.black : Palette.teal,
    brightness: light ? Brightness.light : Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: light
        ? colors.copyWith(primary: Colors.black, onPrimary: Colors.white)
        : colors.copyWith(
            primary: Palette.teal,
            onPrimary: Palette.navy,
            surface: Palette.navy,
            onSurface: const Color(0xFFF1F6F9),
          ),
    scaffoldBackgroundColor: light ? Colors.white : Palette.navy,
    appBarTheme: AppBarTheme(
      backgroundColor: light ? Colors.white : Palette.navy,
      foregroundColor: light ? Colors.black : Colors.white,
      centerTitle: false,
      elevation: 0,
    ),
    textTheme:
        const TextTheme(
          headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(fontSize: 16, height: 1.55),
          bodyMedium: TextStyle(fontSize: 15, height: 1.5),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ).apply(
          bodyColor: light ? const Color(0xFF17191D) : const Color(0xFFF1F6F9),
          displayColor: light ? const Color(0xFF17191D) : Colors.white,
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: UnderlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(vertical: 16),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      errorMaxLines: 3,
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 16,
      contentPadding: EdgeInsets.symmetric(horizontal: 4),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 350),
    ),
  );
}

class AppPage extends StatelessWidget {
  const AppPage({
    required this.title,
    required this.children,
    this.light = false,
    this.footer,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final bool light;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Theme(
    data: appTheme(light: light),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        bottomNavigationBar: footer == null
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 632),
                      child: SizedBox(width: double.infinity, child: footer),
                    ),
                  ),
                ),
              ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                children: children,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({
    required this.title,
    required this.body,
    this.icon = Icons.info_outline,
    super.key,
  });
  final String title;
  final String body;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body),
        ],
      ),
    ),
  );
}

class RouteTile extends StatelessWidget {
  const RouteTile({
    required this.title,
    required this.route,
    this.subtitle,
    this.icon,
    super.key,
  });
  final String title;
  final String route;
  final String? subtitle;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: icon == null ? null : Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).pushNamed(route),
  );
}

class ConnectionAction extends StatefulWidget {
  const ConnectionAction({required this.label, required this.area, super.key});
  final String label;
  final ConnectionArea area;
  @override
  State<ConnectionAction> createState() => _ConnectionActionState();
}

class _ConnectionActionState extends State<ConnectionAction> {
  bool _busy = false;
  CheckOutcome? _result;
  Future<void> _check() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    CheckOutcome result;
    try {
      result = await AppServices.of(context).gateway
          .check(widget.area)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Do not render exception contents, credentials or request payloads.
      result = CheckOutcome.failed;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton(
        onPressed: _busy ? null : _check,
        child: _busy
            ? const Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  Text('연결 상태 확인 중'),
                ],
              )
            : Text(widget.label),
      ),
      if (_result != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Semantics(
            liveRegion: true,
            child: InfoPanel(
              title: _result == CheckOutcome.failed
                  ? '확인하지 못했습니다'
                  : '연결 준비 중입니다',
              body: _result == CheckOutcome.failed
                  ? '처리가 완료되지 않았습니다. 잠시 후 다시 확인해 주세요.'
                  : '아직 서비스가 연결되지 않아 이 작업을 진행할 수 없습니다. 계정이나 구매 상태는 변경되지 않았습니다.',
            ),
          ),
        ),
    ],
  );
}

Future<void> showPreparation(BuildContext context, String feature) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$feature 연결 준비 중'),
        content: const Text(
          '아직 연결되지 않아 작업을 진행하지 않았습니다. 입력 정보가 전송되거나 저장되지 않았습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
