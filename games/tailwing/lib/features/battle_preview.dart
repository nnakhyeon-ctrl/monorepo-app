import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/readiness.dart';
import 'concept_art.dart';

class BattlePreviewScreen extends StatelessWidget {
  const BattlePreviewScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: '전투 화면 미리보기',
    children: [
      const Text(
        '기본 플레이 무료',
        style: TextStyle(color: Palette.teal, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      const Text('전투 화면 구성안입니다. 실제 전투·조작·점수·아이템 지급은 아직 연결되지 않았습니다.'),
      const SizedBox(height: 20),
      Semantics(
        image: true,
        label:
            '오리지널 공중 요새와 따뜻한 색의 부채꼴 적탄, 청록색 아군탄, 중앙의 작은 판정 표시를 배치한 정적 전투 구성안',
        child: ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: .7,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: BattleConceptPainter()),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Palette.navy.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AURORA / 작전 구성안',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 8),
                            Text('중앙 판정 · 공격 예고 · 부위별 약점'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 16,
                    right: 16,
                    bottom: 18,
                    child: Text(
                      'STATIC CONCEPT · 플레이 화면 아님',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Palette.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SectionTitle('한눈에 구분되는 전장'),
      const InfoPanel(
        title: '탄환은 색과 형태로 함께 구분',
        body: '아군은 청록색의 긴 탄환, 적은 따뜻한 색의 원형 탄환으로 표현합니다. 위험 구간은 점선으로 먼저 알리고, 작은 중심 판정과 화면 아래 조작 공간을 확보합니다.',
      ),
      const SizedBox(height: 16),
      const InfoPanel(
        title: '무료 기본 출격과 선택형 구독',
        body: '기본 기체·기본 무장·일반 스테이지·진행/점수 기록은 무료 제공 범위입니다. 추가 기체·스킬·캐릭터·아이템/강화 효과는 구독 전용으로 구분합니다. 현재는 구성안이며 실제 플레이는 준비 중입니다.',
      ),
      const RouteTile(title: '전투기·장비 보기', route: AppRoutes.hangar),
      const RouteTile(title: '구독 관리·혜택 안내', route: AppRoutes.entitlement),
    ],
  );
}
