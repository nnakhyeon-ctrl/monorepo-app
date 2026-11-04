import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicContacts {
  const PublicContacts({
    this.email = '',
    this.supportUrl = '',
    this.privacyUrl = '',
    this.termsUrl = '',
  });
  const PublicContacts.fromEnvironment()
    : email = const String.fromEnvironment('AIRZERO_SUPPORT_EMAIL'),
      supportUrl = const String.fromEnvironment('AIRZERO_SUPPORT_URL'),
      privacyUrl = const String.fromEnvironment('AIRZERO_PRIVACY_URL'),
      termsUrl = const String.fromEnvironment('AIRZERO_TERMS_URL');
  // Only owner-confirmed public addresses belong here. No invented defaults.
  final String email, supportUrl, privacyUrl, termsUrl;
  Uri? https(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.hasPort && uri.port != 443) {
      return null;
    }
    return uri;
  }

  Uri? get support => https(supportUrl);
  Uri? get privacy => https(privacyUrl);
  Uri? get terms => https(termsUrl);
  Uri? get mail {
    if (email.length > 254 ||
        !RegExp(
          r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
        ).hasMatch(email)) {
      return null;
    }
    return Uri(scheme: 'mailto', path: email);
  }

  bool permits(Uri uri) =>
      [support, privacy, terms, mail].whereType<Uri>().contains(uri) ||
      uri.toString() == 'https://play.google.com/store/account/subscriptions' ||
      uri.toString() == 'https://apps.apple.com/account/subscriptions';
}

abstract interface class ExternalNavigator {
  Future<bool> open(Uri uri);
}

class SystemExternalNavigator implements ExternalNavigator {
  const SystemExternalNavigator();
  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

class InstalledAppInfo {
  const InstalledAppInfo(this.version, this.build);
  final String version, build;
  String get label => '$version ($build)';
}

abstract interface class AppInfoRepository {
  Future<InstalledAppInfo> read();
}

class PlatformAppInfo implements AppInfoRepository {
  const PlatformAppInfo();
  @override
  Future<InstalledAppInfo> read() async {
    final info = await PackageInfo.fromPlatform();
    return InstalledAppInfo(info.version, info.buildNumber);
  }
}

Uri? storeManagementUrl(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => Uri.parse(
    'https://play.google.com/store/account/subscriptions',
  ),
  TargetPlatform.iOS => Uri.parse(
    'https://apps.apple.com/account/subscriptions',
  ),
  _ => null,
};
