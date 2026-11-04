import 'package:raikeopeu2026/game/assets.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/progress.dart';
import 'package:raikeopeu2026/core/game_feedback.dart';
import 'package:raikeopeu2026/core/external_services.dart';

class FixtureFeedback implements FeedbackBackend {
  final List<String> events = [];
  @override
  Future<void> music(bool playing, double volume) async {
    events.add('music:$playing:$volume');
  }

  @override
  Future<void> effect(FeedbackCue cue, double volume) async {
    events.add('effect:${cue.name}:$volume');
  }

  @override
  Future<void> vibrate() async {
    events.add('vibrate');
  }

  @override
  Future<void> dispose() async {}
}

class FixtureAppInfo implements AppInfoRepository {
  @override
  Future<InstalledAppInfo> read() async => const InstalledAppInfo('0.1.0', '1');
}

// Test-only adapters. There is no runtime mock flag or premium grant UI.
class FixtureProgress implements ProgressRepository {
  FixtureProgress({bool tutorialDone = true})
    : value = CampaignProgress(tutorialDone: tutorialDone);
  CampaignProgress value;
  bool failWrites = false;
  @override
  Future<ProgressRead> read() async =>
      ProgressRead(CampaignProgress.fromJson(value.toJson()));
  @override
  Future<void> write(CampaignProgress progress) async {
    if (failWrites) {
      throw StateError('fixture failure');
    }
    value = CampaignProgress.fromJson(progress.toJson());
  }
}

class ImmediateAssets extends BattleAssets {
  @override
  Future<void> prepare() async {}
  @override
  Future<void> preparePilot(String id) async {}
}

class FixtureEntitlements implements EntitlementRepository {
  FixtureEntitlements(this.result);
  SubscriptionAccess result;
  int reads = 0, restores = 0;
  @override
  Future<SubscriptionAccess> read() async {
    reads++;
    return result;
  }

  @override
  Future<SubscriptionAccess> restore() async {
    restores++;
    return result;
  }
}
