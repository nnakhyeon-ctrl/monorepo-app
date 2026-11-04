import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:raikeopeu2026/core/device_options.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/progress.dart';
import 'package:raikeopeu2026/game/saved_loadout.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'isolated debug APK replacement preserves records and settings without restoring paid rights',
    (tester) async {
      expect(const bool.fromEnvironment('AIRZERO_INTEGRATION'), true);
      expect(
        (await PackageInfo.fromPlatform()).packageName,
        'com.example.raikeopeu2026.dev.integration',
      );
      const phase = String.fromEnvironment('AIRZERO_PERSISTENCE_PHASE');
      expect(['seed', 'verify'], contains(phase));
      final root = await getApplicationSupportDirectory();
      final directory = Directory(
        '${root.path}/airzero_stage10_update_fixture_v1',
      );
      final repository = FileProgressRepository(
        directory: () async => directory,
      );
      final expected = CampaignProgress(
        tutorialDone: true,
        lastStage: 2,
        sensitivity: 1.25,
        records: {1: const StageRecord(cleared: true, best: 1234, attempts: 2)},
        options: const DeviceOptions(
          music: false,
          musicVolume: .13,
          reduceMotion: true,
        ),
        loadout: const SavedLoadout().select(
          CatalogCategory.aircraft,
          'vector',
        ),
      );
      final read = await repository.read();
      expect(read.writeBlocked, false);
      if (phase == 'seed') {
        // Only this named fixture inside the integration package is written.
        await repository.write(expected);
      } else {
        expect(read.fresh, false);
        expect(read.progress.toJson(), expected.toJson());
      }
      final campaign = CampaignController(repository);
      await campaign.ready;
      final loadout = LoadoutController(campaign: campaign);
      await loadout.ready;
      await loadout.refresh();
      expect(campaign.progress.toJson(), expected.toJson());
      expect(loadout.effectiveSelected(CatalogCategory.aircraft), 'aurora');
      loadout.dispose();
      campaign.dispose();
      binding.reportData = {
        'persistence': {
          'phase': phase,
          'scope': 'isolated_debug_apk_replacement',
          'storeVerification': 'NOT_RUN',
        },
      };
    },
  );
}
