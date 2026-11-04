import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../game/catalog.dart';
import '../game/progress.dart';
import 'email_auth.dart';

typedef AccountCacheFactory = ProgressRepository Function(
  String verifiedScopeKey,
);

String accountCacheFolder(String key) {
  final split = key.lastIndexOf(':');
  final generation = int.parse(key.substring(split + 1));
  if (generation < 0 || generation > 2147483647) {
    throw const FormatException('generation');
  }
  return 'airzero_account_${sha256.convert(utf8.encode(key.substring(0, split)))}_g$generation';
}

/// A verified server connection is the only entry into an account cache.
/// Guest records are neither uploaded nor used to seed a new account implicitly.
class AccountGameCoordinator {
  AccountGameCoordinator(
    this.auth,
    this.campaign,
    this.loadout, {
    AccountCacheFactory? cacheFactory,
    Future<void> Function(String key)? eraseCache,
  }) : _guest = campaign.repository,
       _factory =
           cacheFactory ??
           ((key) => FileProgressRepository(folder: accountCacheFolder(key))),
       _erase =
           eraseCache ??
           ((key) =>
               FileProgressRepository(folder: accountCacheFolder(key))
                   .eraseAccountFamily()) {
    auth.addListener(_changed);
    auth.onAccountDeleted = _deleted;
    auth.beforeGuestImport = () async {
      await settled;
      if (_key != auth.connection?.key ||
          !campaign.loaded ||
          campaign.writeBlocked ||
          campaign.progress.records.isNotEmpty) {
        throw const EmailFailure('conflict_keep_both');
      }
    };
    auth.onGuestImported = (connection) async {
      if (_key == connection.key) {
        await campaign.acceptInitialServerRecords(
          connection.records,
          expectedScopeEpoch: campaign.scopeEpoch,
        );
      }
    };
    _changed();
  }
  final EmailAuthController auth;
  final CampaignController campaign;
  final LoadoutController loadout;
  final ProgressRepository _guest;
  final AccountCacheFactory _factory;
  final Future<void> Function(String) _erase;
  final Map<String, ProgressRepository> _accounts = {};
  String? _key;
  bool _disposed = false;
  Future<void> settled = Future.value();

  void _changed() {
    final connection = auth.connection;
    if (_disposed || connection?.key == _key) return;
    _key = connection?.key;
    final source = connection == null
        ? _guest
        : _accounts.putIfAbsent(connection.key, () => _factory(connection.key));
    CampaignProgress? seed;
    if (connection != null) {
      seed = CampaignProgress(
        records: {
          for (final value in connection.records)
            value['stage'] as int: StageRecord.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
        },
      );
    }
    settled = campaign.activateRepository(source, seed: seed);
    loadout
        .accountChanged(); // Invalidates pending entitlement reads immediately.
  }

  Future<CampaignProgress> guestSnapshot() async {
    await settled;
    CampaignProgress progress;
    if (_key == null) {
      if (!campaign.loaded || campaign.writeBlocked) {
        throw const EmailFailure('storage');
      }
      progress = campaign.progress;
    } else {
      final saved = await _guest.read();
      if (saved.writeBlocked) throw const EmailFailure('storage');
      progress = saved.progress;
    }
    return CampaignProgress.fromJson(jsonDecode(jsonEncode(progress.toJson())));
  }

  Future<void> _deleted(String key) async {
    if (_key == key) {
      _key = null;
      settled = campaign.activateRepository(_guest);
      loadout.accountChanged();
    }
    await settled; // Drain writes before removing only the deleted account cache.
    await _erase(key);
    final owner = key.substring(0, key.lastIndexOf(':') + 1);
    _accounts.removeWhere((k, _) => k.startsWith(owner));
  }

  void dispose() {
    _disposed = true;
    auth.removeListener(_changed);
    auth.onAccountDeleted = null;
    auth.beforeGuestImport = null;
    auth.onGuestImported = null;
  }
}
