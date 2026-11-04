import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/branding.dart';
import 'core/design.dart';
import 'core/readiness.dart';
import 'features/account.dart';
import 'features/home.dart';
import 'features/hangar.dart';
import 'features/battle_preview.dart';
import 'features/services.dart';
import 'features/battle.dart';
import 'game/catalog.dart';
import 'game/assets.dart';
import 'game/progress.dart';
import 'features/stages.dart';
import 'core/game_feedback.dart';
import 'core/external_services.dart';
import 'core/store_catalog.dart';
import 'features/support.dart';
import 'features/settings.dart';
import 'security/email_auth.dart';
import 'security/firebase_email.dart';
import 'security/account_game.dart';
import 'features/email_actions.dart';
import 'security/billing.dart';
import 'security/native_billing.dart';

class RaikeopeuApp extends StatefulWidget {
  const RaikeopeuApp({
    this.gateway = const UnconnectedGateway(),
    this.entitlements,
    this.assets,
    this.progress,
    this.feedback,
    this.contacts = const PublicContacts.fromEnvironment(),
    this.external = const SystemExternalNavigator(),
    this.appInfo = const PlatformAppInfo(),
    this.storeCatalog,
    this.billingStore,
    this.emailAuth,
    this.accountCacheFactory,
    this.eraseAccountCache,
    super.key,
  });
  final ConnectionGateway gateway;
  final EntitlementRepository? entitlements;
  final BattleAssets? assets;
  final ProgressRepository? progress;
  final FeedbackBackend? feedback;
  final PublicContacts contacts;
  final ExternalNavigator external;
  final AppInfoRepository appInfo;
  final StoreCatalogRepository? storeCatalog;
  final BillingStore? billingStore;
  final EmailAuthController? emailAuth;
  final AccountCacheFactory? accountCacheFactory;
  final Future<void> Function(String)? eraseAccountCache;
  @override
  State<RaikeopeuApp> createState() => _RaikeopeuAppState();
}

class _RaikeopeuAppState extends State<RaikeopeuApp>
    with WidgetsBindingObserver {
  late final AppPreferences _preferences;
  late final LoadoutController _loadout;
  late final BattleAssets _assets;
  late final CampaignController _campaign;
  late final FeedbackController _feedback;
  late final StoreCatalogController _storeCatalog;
  late final EmailAuthController _emailAuth;
  late final AccountGameCoordinator _accountGame;
  late final BillingController _billing;
  bool _private = false;
  @override
  void initState() {
    super.initState();
    _assets = widget.assets ?? BattleAssets();
    _campaign = CampaignController(widget.progress ?? FileProgressRepository());
    _emailAuth =
        widget.emailAuth ??
        EmailAuthController(initialize: createFirebaseEmailRuntime);
    _billing = BillingController(
      AccountBillingSession(_emailAuth),
      widget.billingStore ?? NativeBillingStore(),
    );
    _loadout = LoadoutController(
      repository: widget.entitlements ?? BillingEntitlements(_billing),
      campaign: _campaign,
    );
    _preferences = AppPreferences(_campaign);
    _feedback = FeedbackController(
      _campaign,
      widget.feedback ?? LocalFeedbackBackend(),
    );
    _storeCatalog = StoreCatalogController(
      widget.storeCatalog ?? BillingCatalog(_billing),
    );
    _billing.onRightsChanged = () {
      _loadout.refresh();
    };
    _emailAuth.addListener(_activateBilling);
    _accountGame = AccountGameCoordinator(
      _emailAuth,
      _campaign,
      _loadout,
      cacheFactory: widget.accountCacheFactory,
      eraseCache: widget.eraseAccountCache,
    );
    Future.microtask(_emailAuth.restore);
    WidgetsBinding.instance.addObserver(this);
  }

  void _activateBilling() {
    if (!_emailAuth.busy && _emailAuth.connection != null) _billing.activate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hide = state != AppLifecycleState.resumed;
    _feedback.foreground(!hide);
    if (!hide && _emailAuth.hasRuntime && !_emailAuth.busy) {
      _emailAuth.restore();
    }
    if (hide != _private && mounted) setState(() => _private = hide);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailAuth.removeListener(_activateBilling);
    _preferences.dispose();
    _feedback.dispose();
    _storeCatalog.dispose();
    _billing.dispose();
    _accountGame.dispose();
    if (widget.emailAuth == null) _emailAuth.dispose();
    _loadout.dispose();
    _assets.dispose();
    _campaign.dispose();
    super.dispose();
  }

  Widget _screen(String? route) => switch (route) {
    AppRoutes.home => const HomeScreen(),
    AppRoutes.hangar => const HangarScreen(),
    AppRoutes.battlePreview => const BattlePreviewScreen(),
    AppRoutes.battle => const BattleScreen(),
    AppRoutes.controls => const ControlsScreen(),
    AppRoutes.stages => const StageSelectScreen(),
    AppRoutes.account => const AccountScreen(),
    AppRoutes.login => const EmailScreen(),
    AppRoutes.register => const EmailScreen(register: true),
    AppRoutes.verify => const VerificationScreen(),
    AppRoutes.recovery => const RecoveryScreen(),
    AppRoutes.emailAction => const EmailActionScreen(),
    AppRoutes.emailChange => const EmailChangeScreen(),
    AppRoutes.socialLink => const SocialLinkScreen(),
    AppRoutes.help => const AccountHelpScreen(),
    AppRoutes.logout => const EmailLogoutScreen(),
    AppRoutes.deleteAccount => const AccountDeletionInfoScreen(),
    AppRoutes.entitlement => const EntitlementScreen(),
    AppRoutes.restore => const RestoreScreen(),
    AppRoutes.cloud => const RecordsScreen(),
    AppRoutes.settings => const SettingsScreen(),
    AppRoutes.support => const SupportScreen(),
    AppRoutes.report => const ErrorReportScreen(),
    AppRoutes.terms => const LegalScreen(kind: LegalKind.terms),
    AppRoutes.privacy => const LegalScreen(kind: LegalKind.privacy),
    AppRoutes.paymentTerms => const LegalScreen(kind: LegalKind.payment),
    _ => const InvalidRouteScreen(),
  };

  Route<void> _route(RouteSettings settings) {
    final valid =
        AppRoutes.all.contains(settings.name) && settings.arguments == null;
    final reduced =
        _preferences.reduceMotion ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
    return PageRouteBuilder<void>(
      settings: valid ? settings : const RouteSettings(name: '/invalid'),
      transitionDuration: reduced
          ? Duration.zero
          : const Duration(milliseconds: 180),
      reverseTransitionDuration: reduced
          ? Duration.zero
          : const Duration(milliseconds: 150),
      pageBuilder: (_, animation, secondaryAnimation) =>
          _screen(valid ? settings.name : null),
      transitionsBuilder: (_, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  Widget build(BuildContext context) => AppServices(
    gateway: widget.gateway,
    preferences: _preferences,
    loadout: _loadout,
    battleAssets: _assets,
    campaign: _campaign,
    feedback: _feedback,
    storeCatalog: _storeCatalog,
    contacts: widget.contacts,
    external: widget.external,
    appInfo: widget.appInfo,
    emailAuth: _emailAuth,
    accountGame: _accountGame,
    billing: _billing,
    child: MaterialApp(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: AppRoutes.home,
      onGenerateInitialRoutes: (_) => [
        _route(const RouteSettings(name: AppRoutes.home)),
      ],
      onGenerateRoute: _route,
      builder: (context, child) => Stack(
        children: [
          if (child != null)
            ExcludeSemantics(excluding: _private, child: child),
          if (_private)
            const Positioned.fill(
              child: ColoredBox(
                color: Palette.navy,
                child: Center(
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.shield_outlined,
                      color: Palette.teal,
                      size: 56,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
