import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/readiness.dart';
import '../game/stages.dart';

class StageSelectScreen extends StatelessWidget {
  const StageSelectScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final campaign = AppServices.of(context).campaign;
    return ListenableBuilder(
      listenable: campaign,
      builder: (context, _) => AppPage(
        title: '작전 선택',
        children: [
          const Text(
            '클리어하면 다음 작전이 열립니다. 기본 캐릭터와 보호막으로 모든 작전에 도전할 수 있습니다. 목표 시간은 작전당 약 3~5분입니다.',
          ),
          if (!campaign.loaded)
            const Center(child: CircularProgressIndicator()),
          if (campaign.saveFailed || campaign.writeBlocked)
            const InfoPanel(
              title: '기기 기록 저장 상태를 확인해 주세요',
              body:
                  '읽기나 저장에 실패한 기록을 완료로 표시하지 않습니다. 환경설정의 기록 이어하기에서 확인할 수 있습니다.',
            ),
          for (final stage in stages) ...[
            const SizedBox(height: 12),
            ListTile(
              key: Key('stage-${stage.number}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              tileColor: Palette.panel,
              leading: Icon(
                stage.number > campaign.progress.unlocked
                    ? Icons.lock_outline
                    : campaign.progress.records[stage.number]?.cleared == true
                    ? Icons.check_circle_outline
                    : Icons.flight_takeoff,
                color: stage.number > campaign.progress.unlocked
                    ? Palette.muted
                    : Palette.teal,
              ),
              title: Text(
                '${stage.number.toString().padLeft(2, '0')} · ${stage.name}',
              ),
              subtitle: Text(
                '${stage.number > campaign.progress.unlocked
                    ? '이전 작전을 클리어하면 해금'
                    : campaign.progress.records[stage.number]?.cleared == true
                    ? '클리어 완료'
                    : '도전 가능'}\n${stage.briefing}\n보스: ${stage.bossName}\n최고 ${campaign.progress.records[stage.number]?.best ?? 0}점 · 도전 ${campaign.progress.records[stage.number]?.attempts ?? 0}회',
              ),
              trailing: campaign.selectedStage == stage.number
                  ? const Icon(Icons.radio_button_checked, color: Palette.teal)
                  : null,
              enabled:
                  campaign.loaded && stage.number <= campaign.progress.unlocked,
              onTap: () {
                if (campaign.selectStage(stage.number)) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
