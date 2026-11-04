import 'package:flutter/widgets.dart';

import '../game/catalog.dart';
import '../game/assets.dart';
import '../game/progress.dart';
import 'game_feedback.dart';
import 'external_services.dart';
import 'store_catalog.dart';
import '../security/email_auth.dart';
import '../security/account_game.dart';
import '../security/billing.dart';

enum ConnectionArea { authentication, account, store, cloud }

enum CheckOutcome { notConnected, failed }

/// No credentials, network requests, authentication or entitlements in stage 4.
abstract interface class ConnectionGateway {
  Future<CheckOutcome> check(ConnectionArea area);
}

final class UnconnectedGateway implements ConnectionGateway {
  const UnconnectedGateway();

  @override
  Future<CheckOutcome> check(ConnectionArea area) async =>
      CheckOutcome.notConnected;
}

class AppPreferences extends ChangeNotifier {
  AppPreferences(this.campaign) {
    campaign.addListener(notifyListeners);
  }
  final CampaignController campaign;
  bool get reduceMotion => campaign.progress.options.reduceMotion;

  void setReduceMotion(bool value) {
    campaign.setOptions(
      campaign.progress.options.copyWith(reduceMotion: value),
    );
  }

  @override
  void dispose() {
    campaign.removeListener(notifyListeners);
    super.dispose();
  }
}

class AppServices extends InheritedWidget {
  const AppServices({
    required this.gateway,
    required this.preferences,
    required this.loadout,
    required this.battleAssets,
    required this.campaign,
    required this.feedback,
    required this.storeCatalog,
    required this.contacts,
    required this.external,
    required this.appInfo,
    required this.emailAuth,
    required this.accountGame,
    required this.billing,
    required super.child,
    super.key,
  });

  final ConnectionGateway gateway;
  final AppPreferences preferences;
  final LoadoutController loadout;
  final BattleAssets battleAssets;
  final CampaignController campaign;
  final FeedbackController feedback;
  final StoreCatalogController storeCatalog;
  final PublicContacts contacts;
  final ExternalNavigator external;
  final AppInfoRepository appInfo;
  final EmailAuthController emailAuth;
  final AccountGameCoordinator accountGame;
  final BillingController billing;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppServices>()!;

  @override
  bool updateShouldNotify(AppServices oldWidget) =>
      gateway != oldWidget.gateway ||
      preferences != oldWidget.preferences ||
      loadout != oldWidget.loadout ||
      battleAssets != oldWidget.battleAssets ||
      campaign != oldWidget.campaign ||
      feedback != oldWidget.feedback ||
      storeCatalog != oldWidget.storeCatalog ||
      contacts != oldWidget.contacts ||
      external != oldWidget.external ||
      appInfo != oldWidget.appInfo ||
      emailAuth != oldWidget.emailAuth;
}

abstract final class AppRoutes {
  static const home = '/';
  static const hangar = '/hangar';
  static const battlePreview = '/battle-preview';
  static const battle = '/battle';
  static const controls = '/controls';
  static const stages = '/stages';
  static const coop = '/coop';
  static const account = '/account';
  static const login = '/account/email';
  static const register = '/account/register';
  static const verify = '/account/verify';
  static const recovery = '/account/recovery';
  static const emailAction = '/account/email-action';
  static const emailChange = '/account/email-change';
  static const socialLink = '/account/social-link';
  static const help = '/account/help';
  static const logout = '/account/logout';
  static const deleteAccount = '/account/delete';
  static const entitlement = '/entitlement';
  static const restore = '/entitlement/restore';
  static const cloud = '/records';
  static const settings = '/settings';
  static const support = '/support';
  static const report = '/support/report';
  static const terms = '/legal/terms';
  static const privacy = '/legal/privacy';
  static const paymentTerms = '/legal/payment';
  static const all = <String>{
    home,
    hangar,
    battlePreview,
    battle,
    controls,
    stages,
    account,
    login,
    register,
    verify,
    recovery,
    emailAction,
    emailChange,
    socialLink,
    help,
    logout,
    deleteAccount,
    entitlement,
    restore,
    cloud,
    settings,
    support,
    report,
    terms,
    privacy,
    paymentTerms,
  };
}
