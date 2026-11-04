# 테일윙 실제 앱 후속 확인 — 저장 후 중단

2026-10-30 재개 후 주석: 아래는 중단 당시 이력이다. 이후 [후속 결과](TAILWING-FOLLOWUP-RESULTS.md)·[직접 실행/준비 순서](TAILWING-RUN-GUIDE.md)·[현재 파일/증거 대조](tailwing/FOLLOWUP-LOCAL-CHECKS.json)로 당시 남은 독립 APK 시작 검사·release 재생성·표/안내/갤러리 갱신을 정리했다. 아래 ‘재개 전 중단’과 미실행은 그 시점 상태이며 현재 결과와 구분한다.

2026-10-30 KST. 사용자가 “하던 작업 저장하고 중단, 추후 재개”를 요청했다. 파일 저장 후 실행 중이던 빌드/분석의 종료를 확인하고 소유한 Android 가상 기기를 종료했다. **재개 요청 전 추가 개발·검사·설정·배포를 진행하지 않는다.** 후속 요청 1~7 전체 완료가 아니다.

## 이번에 저장한 수정과 확인

- 구성/판매 범위는 변경하지 않았다. 토끼 루미·여우 세라·거북이 도미는 무료, 나머지 9종 선택과 모든 종의 고유 기술은 검증된 월/연 구독 범위다. 곰 모루·수달 누비의 해적 탐험가 모습은 **해당 캐릭터의 기본 디자인**이며 별도 캐릭터/스킨 상품·선택 ID가 아니다.
- 실제 버그 수정: 승리/패배/시간 초과 후 시뮬레이션이 멈추면서 남던 기술 상태·설치물·수집탄·표식/잔상·적 둔화/면역 상태를 결과 진입 시 정리한다. 자연 종료된 갑판의 내구 값과 교란 대상 참조도 제거한다. 일시정지 중에는 기술 시간이 흐르지 않고, 장착 전환 시 정리 규칙·기본 조작/점수/저장/계정/결제 경계는 유지했다. `lib/game/engine.dart`, `lib/game/animal_combat.dart`.
- 새 `test/animal_lifecycle_test.dart`의 종료/전환/재도전 검사. 최초 17개 중 2통과/15실패로 상태 잔류를 확인했다. 곰 표본 1건은 일반탄을 수집하는 정상 기능 때문에 패배하지 않은 시험 입력 문제여서 차단 불가 탄으로 정정했다. 수정 후 **관련 5파일 64개 통과**: lifecycle/roster/campaign/battle_engine/battle_flow. 중간 실행 48통과와 존재하지 않는 `engine_test.dart` 경로 1건의 실행 오류도 있었으며 올바른 파일명으로 다시 검사한 결과가 64통과다.
- 전체 `flutter analyze --no-pub`: **No issues found, 35.5초**. 이후 연구소 검사 스크롤 보완/카탈로그 export를 대상으로 `dart analyze integration_test/tailwing_followup_test.dart tool/export_tailwing_roster.dart`도 문제 없음. 전체 검사를 새로 모두 실행했다고 표시하지 않는다.
- `tool/export_tailwing_roster.dart`가 실제 `animal_roster.dart`의 12종 이름/기술/무료 구분·24개 자산 참조를 `tailwing/ROSTER-CATALOG.json`으로 내보낸다. HTML 생성기는 이 출력으로 이름/기술/무료 표기를 구성하도록 변경했다. 기존 27개 자산/14장 갤러리 링크 검사 누락0. HTML은 정적 검토 자료이고 게임/권한 부여 프로그램이 아니다.
- Android 새 실제 앱 검사 `integration_test/tailwing_followup_test.dart`: 일반 무료 구성으로 **1탄 초기 생성→보스→승리 기록→재도전** 통과. 273.483초 게임 진행,5469회 UI 프레임 pump, 약422.7초 실제 검사,체력2/점수3700. 적·체력·점수/스테이지 시간을 주입하지 않았고 자동 steering을 사용했다. 사람/실기기 성능 통과가 아니다. [결과](tailwing/NATIVE-FOLLOWUP.json), `tailwing/followup-screenshots/boss.png`, `result.png`, `retry.png`.
- 같은 native 첫 실행은 연구소 검사에서 lazy ListView 바깥의 버튼을 찾지 못해 **총1통과/1실패**였다. 화면 밖 위젯을 스크롤로 만든 뒤 탭하도록 검사 코드를 수정하고 연구소만 재검사하여 **1개 통과(27초)**. 연구소 12종 선택/기체 디코드/기술 버튼/가속 모델 종료/재시작, 정상 premium=false·기록0 확인. [재검사](tailwing/NATIVE-LAB-RECHECK.json), `lab-turtle.png`, `lab-squirrel.png`, `lab-frog.png`. 통과한 긴 1탄은 반복하지 않았다.
- 최초 native 설치에서 **별도 가상 `.integration` 시험 앱**의 서명 불일치가 발생해 Flutter가 그 시험 패키지를 재설치했다. 가상 fixture만 대상으로 했고 일반 `.dev` 앱/실사용자 데이터는 삭제·수정하지 않았다. 이 이력을 숨기지 않는다. 이후 동일 환경의 연구소 재검사 설치는 성공했다. 사용자 직접 설치 안내는 자동 제거 없이 `adb install -r`로 실패 시 멈추는 방식을 준비할 예정이다.
- 보안 재감사: **전체 moderate5/high0/critical0, production0** 유지. [공개 메타데이터/감사/호환 dry-run](tailwing/SECURITY-RECHECK.json). 패키지는 pubsub5.3.1/core1.30.1/uuid9.0.1/gaxios6.7.1/firebase-tools15.34.0. 최신 CLI는15.34.2로 확인했지만 pubsub `^5.2.0`·gaxios `^6.7.0`을 유지한다. 호환 audit fix dry-run 추가/제거/변경0. 강제 override/major 교체·downgrade 없이 기존5개 경고를 유지했다. 상세 보안 문서의 최신 버전/대응 갱신은 아직 남았다.

## 빌드·실행 상태를 구분

- 수정 후 일반 `lib/main.dart`의 새 debug 개발 APK 빌드 성공(42.1초): `build/tailwing-preview/tailwing-preview-debug.apk`, ID `com.example.raikeopeu2026.dev.integration`,버전0.1.0+1. **이 새 일반 APK의 설치/독립 시작 지연 검사는 아직 하지 않았다.** native 검사는 별도 integration_test 실행 바이너리의 결과다.
- 새 파일 해시/소스 지문은 [BUILDS.json](tailwing/BUILDS.json)의 preview. 이전 preview/실행 이력은 [BUILD-HISTORY.json](tailwing/BUILD-HISTORY.json)으로 보존했다. old release-inspection 항목은 아직 10월29일 소스이며 이번 종료 처리 수정 후 다시 만들지 않았다.
- `tailwing/FINAL-LOCAL-CHECKS.json`, 옛 릴리즈 정적 검사·SHA는 해당 검사 시점의 이력이다. **현재 수정 소스의 새 release 검사 완료로 해석하지 않는다.** 제출용 AAB/IPA·새 스토어 자료는 미생성/미갱신.
- 소유 VM API37/2048MB/4core/GPU host/no snapshot: 종료 요청 성공. [환경 기록](tailwing/EMULATOR-ENVIRONMENT.json). 호스트 총 약16GB, 시작 전 가용 약3.38GB, native 중 약0.77~1.00GB 관찰. 자원 압박 가능성은 있지만 이전 PID 소실/시작 timeout의 원인으로 확정하지 않았다. 새 일반 APK의 반복 cold/warm/장기 생존·제한된 crash/ANR/exit reason 조사는 미실행. 실기기 연결0, 실기기 성능/발열/입력 통과 아님.

## 재개 후 남은 순서

1. 이 체크포인트와 실제 소스/Git 상태부터 읽고 위 통과/실패 기록 보존. 새 일반 preview APK의 단독 실행을 전용 VM에서 검사하여 이전 종료 원인·현재 재현/환경 영향을 구분. 종료/서명 불일치 시 일반 앱을 지우는 우회 금지.
2. 12종 이름·기체 외형·고유 기술·무료/구독·구현/검사 범위 표와 해적 기본 디자인 설명을 최종 후속 문서로 정리. 기존 aircraft 프레임 ID와 종별 탑승 PNG 외형을 별도 판매 기체로 오해시키지 않는다. 신규 상품/가격/ID 확정 안 함.
3. 직접 실행 안내: 별도 debug APK/연구소 12종 무기록·무구매, USB 개발자 옵션/ADB·기기 선택·안전한 `install -r`·실행·관찰 목록. 가상 앱과 실제 Flutter/HTML·종료의 가속 모델 검사를 구분. profile 모드에서 기존 일반 ID로 덮어쓰지 않도록 별도 빌드/서명 경계 검토가 선행.
4. 보안 문서에 최신 CLI15.34.2·5개 패키지별 권고/영향/호환 수정 불가 근거·대응 기록. 운영0을 전체 안전 선언으로 쓰지 않는다. 의존성 자체 변경은 없으므로 기존 서버21개를 불필요하게 반복하지 않는다.
5. 실제 로그인/서버/스토어·공개 삭제 웹·Apple/iOS·실기기 우선순위와 사용자 첫 작업을 구체화. 기존 Firebase/Google/카카오 등록 재사용. Functions 배포 Blaze 조건 때문에 무료 유지에서 대기; 요금제/배포 전환 안 함. Mac/Xcode가 있으면 Personal Team 기본 시험 가능성을 고급 capability와 구분하고 유료 가입을 대신 진행하지 않는다.
6. 변경 영향 11단계와 새 debug/미서명 release·SHA/소스 지문·정적 검사·갤러리/새 6장 캡처·소개/아이콘의12단계 갱신 범위를 문서에 반영. 정적/가상/실연동/실기기를 구분하고 최종 통과·제출 준비 완료로 표시하지 않는다.

실제 로그인·서버·스토어·공식 알림/환불·공개 삭제 페이지·Apple/iOS·실기기·장기 균형/성능·상품 ID7개/URL4개 대기는 그대로다. 구매 잠금·보유 권한 검증을 유지한다. 과금 전환·실제 청구·운영/페이지/스토어 배포/등록·실사용자 삭제·자동 commit/push는 하지 않았다. **사용자 재개 요청까지 중단.**
