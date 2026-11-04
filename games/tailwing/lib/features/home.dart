import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/branding.dart';
import '../core/design.dart';
import '../core/readiness.dart';
import '../game/stages.dart';
import '../game/catalog.dart';
import '../game/assets.dart';

import 'package:flutter/foundation.dart';

import 'animal_preview.dart';
import '../game/animal_roster.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _starting = false;
  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final services = AppServices.of(context);
      await Future.wait([
        services.battleAssets.prepare(),
        services.campaign.ready,
        services.loadout.ready,
      ]);
      if (!mounted) return;
      await Navigator.pushNamed(context, AppRoutes.battle);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전투를 준비하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 596),
              child: SizedBox(width: double.infinity, child: _launchButton()),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: LayoutBuilder(
              builder: (context, bounds) => SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: bounds.maxWidth > 500 ? 36 : 22,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.flight,
                                color: Palette.teal,
                                size: 20,
                              ),
                              const SizedBox(width: 9),
                              const Expanded(
                                child: Text(
                                  AppBrand.genreLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 3,
                                    color: Palette.muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '조작 방법',
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.controls,
                                ),
                                icon: const Icon(Icons.help_outline, size: 22),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppBrand.homeTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: bounds.maxWidth < 360 ? 32 : 44,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            AppBrand.tagline,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Palette.muted,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const FlightArtwork(),
                          const SizedBox(height: 12),
                          const FreePilotChoices(),
                          const SizedBox(height: 18),
                          ListenableBuilder(
                            listenable: AppServices.of(context).campaign,
                            builder: (context, _) {
                              final c = AppServices.of(context).campaign;
                              return TextButton.icon(
                                key: const Key('chooseStage'),
                                onPressed: c.loaded
                                    ? () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.stages,
                                      )
                                    : null,
                                icon: const Icon(Icons.map_outlined),
                                label: Text(
                                  '작전 ${c.selectedStage.toString().padLeft(2, '0')} · ${stageByNumber(c.selectedStage).name}  ›',
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '토끼·여우·거북이와 사격·보호막 무료\n전체 캐릭터·고유 기술은 월·연 구독',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFF1F6F9),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (kDebugMode)
                            TextButton.icon(
                              key: const Key('animalLab'),
                              icon: const Icon(Icons.science_outlined),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const AnimalPreviewScreen(),
                                ),
                              ),
                              label: const Text('개발 연구소 · 캐릭터 전투 미리보기'),
                            ),
                          const HomeMenuGrid(),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 18, bottom: 4),
                        child: Text(
                          AppBrand.footer,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Palette.muted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _launchButton() => FilledButton.icon(
    key: const Key('startGame'),
    onPressed: _starting ? null : _start,
    icon: _starting
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.flight_takeoff_rounded, size: 28),
    label: Text(
      _starting ? '전투 준비 중' : '출격',
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
    ),
    style: FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 62),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

class FlightArtwork extends StatelessWidget {
  const FlightArtwork({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppServices.of(context).loadout;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final entry = catalogEntry(
          c.effectiveSelected(CatalogCategory.aircraft),
        );
        final pilot = c.pilot;
        return Semantics(
          image: true,
          label: '${pilot.species} ${pilot.name}, 선택 기체 ${entry.name}',
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1.25,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          BattleAssets.coastPath,
                          cacheWidth: 720,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) =>
                              const ColoredBox(color: Palette.panel),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x5509131E),
                                Color(0x0009131E),
                                Color(0xDD09131E),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            pilot.hero,
                            key: ValueKey('home-mounted-${pilot.id}'),
                            cacheWidth:
                                (MediaQuery.sizeOf(context).width *
                                        MediaQuery.devicePixelRatioOf(context))
                                    .ceil()
                                    .clamp(512, 1024),
                            filterQuality: FilterQuality.medium,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    key: const Key('homePilotCaption'),
                    color: Palette.panel,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${pilot.name} · ${pilot.species}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          '${pilot.role} · ${entry.name} 프레임',
                          style: const TextStyle(
                            color: Palette.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FreePilotChoices extends StatelessWidget {
  const FreePilotChoices({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppServices.of(context).loadout;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Row(
        children: [
          for (final p in animalPilots.where((p) => p.free))
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton(
                  key: Key('home-pilot-${p.id}'),
                  onPressed: c.selectionsLoaded
                      ? () => c.select(catalogEntry(p.id))
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(
                      color: c.pilot.id == p.id
                          ? Color(p.color)
                          : Palette.muted.withValues(alpha: .25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        p.portrait,
                        cacheWidth: 128,
                        height: 64,
                        fit: BoxFit.contain,
                      ),
                      Text(
                        '${p.species} ${p.name}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        c.pilot.id == p.id ? '선택됨' : '무료',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HomeMenuGrid extends StatelessWidget {
  const HomeMenuGrid({super.key});

  static const _menus = [
    HomeMenu(
      title: '전투기·장비',
      subtitle: '전투기, 스킬, 캐릭터와 아이템 보기',
      icon: Icons.flight_takeoff,
      route: AppRoutes.hangar,
    ),
    HomeMenu(
      title: '환경설정',
      subtitle: '계정, 기록 이어하기와 화면 설정',
      icon: Icons.tune,
      route: AppRoutes.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final single =
          constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(16) > 23;
      return Material(
        color: Palette.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Palette.muted.withValues(alpha: .12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: single
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _menus.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 18, endIndent: 18),
                    HomeMenu(
                      title: _menus[i].title,
                      subtitle: _menus[i].subtitle,
                      icon: _menus[i].icon,
                      route: _menus[i].route,
                      compact: true,
                    ),
                  ],
                ],
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _menus.length; i++) ...[
                      if (i > 0)
                        const VerticalDivider(
                          width: 1,
                          indent: 18,
                          endIndent: 18,
                        ),
                      Expanded(child: _menus[i]),
                    ],
                  ],
                ),
              ),
      );
    },
  );
}

class HomeMenu extends StatelessWidget {
  const HomeMenu({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.compact = false,
    super.key,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    hint: subtitle,
    child: InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 18 : 6,
            vertical: 16,
          ),
          child: compact
              ? Row(
                  children: [
                    Icon(icon, color: Palette.teal, size: 25),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.chevron_right,
                      color: Palette.muted,
                      size: 20,
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Palette.teal, size: 25),
                    const SizedBox(height: 9),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}
