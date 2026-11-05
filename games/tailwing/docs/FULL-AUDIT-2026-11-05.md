# 테일윙 전체 회귀 검사·오류 수정

2026-11-05 사용자 추가 검증 요청을 GitHub `main` 기준 `188de1a3d5a7d938bcbe65c4ae11571fa081cb3c`에서 이어 수행했다. 대상은 테일윙 앱과 관련 서버/검증 도구이며 모노레포 공통 검사도 실행했다. 이미 충족된 캐릭터/스킬/아이템과 기존 기록·계정·12종/무료3종·구독 검증 경계·앱 ID/저장 namespace를 유지했다. 이번에는 화면/원화·전투 수치를 바꾸지 않았다.

## 재현 후 수정한 오류 3건

| 재현 조건 | 수정 전 | 수정 후 |
|---|---|---|
| 기본 보호막 사용 중 펄스로 보스를 즉시 격파 | 결과 화면에서 다음 프레임이 없어 보호막/대기 상태가 남음 | 즉시 스킬/프레임 종료 경로를 같은 정리 함수로 연결. 협동 양쪽 조종사의 효과와 대기 상태도 정리 |
| 협동에서 주 조종사 HP0, 동료 생존 | 적 유도탄이 쓰러진 주 조종사를 추적 | 살아 있는 조종사를 목표로 선택. 모두 쓰러지면 기존 진행 속도를 유지하며 종료 정리 |
| 돌진 적이 옆/위로 전장 이탈 | 아래쪽 이탈만 정리해 적이 계속 누적되고 협동 스냅샷의 좌표 검증도 실패 가능 | 돌진이 시작된 기체의 옆/위 이탈도 제거. 생성 대기 위치는 보존하고 이탈에 격추 점수를 주지 않음 |

`test/regression_audit_test.dart`의 세 검사가 수정 전 모두 실패하는 것을 확인한 후 수정했다. 첫 검사는 양쪽 보호막을 켠 상태에서 추가 프레임 없이 승리 정리를 확인한다. 마지막 검사는 화면 가장자리에서 실제 이동시켜 이탈 정리 후 스냅샷 읽기까지 검사한다. 사격 속도·선회 속도·피격 범위·보호막 수치·보스 HP는 변경하지 않았다.

## 검사 결과

| 대상/방법 | 결과 | 근거/한계 |
|---|---|---|
| Flutter 전체 합성/위젯/엔진 회귀 | 240 통과, 실패0 | [검사별 결과](local-verification/AUDIT-2026-11-05.json). 기록/계정 분리·잠금/만료·홈/선택/전투·작은 화면/큰 글씨·무료15탄 모의 실행 포함 |
| Dart 형식·Flutter 정적 분석 | 변경 필요0·문제 없음 | 수정3파일 형식 검사, `analyze --no-pub` |
| TypeScript 빌드·서버 단위 검사 | 빌드 성공·21 통과 | 기존 서버 소스/의존성 그대로 실행 |
| 가상 Auth/Firestore/Functions 통합 | 44 통과, 실패0 | 실제 계정/결제/삭제 없이 demo 데이터만 사용. 요청 Node22와 PC Node24 차이 경고가 남음 |
| 루트 CI/도구·문서·민감 패턴 검사 | 통과 | JS/Bash 구문, 생성기/로컬/출시 도구, 문서 링크/추적 제외 규칙 검사. 무결함/유출 없음 판정은 아님 |
| 공식 npm 잠금 파일 감사 | 경고 있음 | 최종 조회 전체 moderate14, production6. high/critical0. [현재 보고서](local-verification/DEPENDENCIES-2026-11-05.json) |

[검증 범위·소스 SHA-256](local-verification/AUDIT-EVIDENCE-2026-11-05.json)에 기준 소스와 검사 대상/방법/결과/미실행 사유를 함께 기록했다. 이전 화면 비교는 [홈·선택·장비·스킬 갤러리](character-item-pass-2026-11-05/index.html)를 보존한다. 이번 논리 수정으로 새 스크린샷이나 제출용 빌드를 만들지는 않았다.

## 의존성 경고와 검사 개선

공식 npm 레지스트리만 사용해 잠금 파일 사본을 자격증명 없는 별도 디렉터리에서 감사했다. 설치 스크립트·실서비스·배포 명령은 실행하지 않았다. `glob`의 취소 후 탐색 지속과 `minimatch`의 패턴 증폭 경고가 포함된다. 공개 근거: [glob GHSA](https://github.com/advisories/GHSA-3g3m-2fjr-6pw4), [minimatch GHSA](https://github.com/advisories/GHSA-g3hv-75wg-m249).

`audit fix --package-lock-only --ignore-scripts`를 **사본에만** 시험했으나 일부 Google 전이 의존성을 5.0.8→5.0.4 등으로 낮추고 전체 moderate13도 남겼다. 이 결과는 호환성과 보안 수정 완료의 근거가 아니므로 실제 package/lock/node_modules는 변경하지 않았다. Firebase CLI에 제시된 주 버전 변경/다운그레이드나 전이 패키지 강제 override도 적용하지 않았다. 상위 SDK가 허용하는 수정 버전 검토와 서버 재검증이 필요한 미해결 항목이다.

현재 날짜용 감사 옵션 `--current`를 추가해 11월4일 제출 준비 증거를 덮어쓰지 않도록 했다. 현재 감사 명령은 보고서 저장 후 경고가 있으면 종료1, 조회 자체가 불가능하면 종료2를 반환한다. 경고가 있는 검사를 성공적인 출시 게이트로 오인하지 않도록 했다. 전체 Flutter 검사도 별도 `audit` 결과 파일로 보존한다.

같은 잠금 파일의 최초 조회는 전체16/production6, 최종 조회는 전체14/production6이었다. 레지스트리 감사 응답은 갱신될 수 있으므로 수치 감소를 코드 수정 성과로 세지 않는다. 근거에는 최종 조회 결과와 변경하지 않은 잠금 파일 해시를 남긴다.

## 재현 명령·남은 작업

루트 PowerShell:

```powershell
node games/tailwing/tool/check_combat_pass.mjs audit
node games/tailwing/tool/audit_release_dependencies.mjs --current
node scripts/ci.mjs
```

두 번째 명령의 현재 기대 종료 코드는 경고 때문에1이다. 서버는 `games/tailwing/server/firebase`에서 `npm.cmd run build`, `npm.cmd test`, Android Studio JBR를 `JAVA_HOME`으로 지정한 뒤 `npm.cmd run test:emulator`로 재현한다. 실행 환경 설정·실제 비밀 파일은 자동 로드하지 않는다.

Android SDK/테스트 기기를 준비한 뒤 `games/tailwing`에서 `..\..\flutter\bin\flutter.bat --suppress-analytics devices`, `..\..\flutter\bin\flutter.bat --suppress-analytics run -d '<기기 ID>'`로 실제 앱을 실행한다. 데이터 삭제나 재설치를 검사 전제로 삼지 않는다.

**미검증**: Android/iOS 실기기·GPU FPS/GC/발열, 실제 두 기기 협동, 서명 AAB/Archive/IPA 실행, 운영 Node22, 실제 로그인 callback·스토어 결제/복원·운영 서버·공식 스토어 테스트. 협동 공개 메뉴는 기존대로 숨겨져 있다. 합성 통과를 공식 출시 준비 완료로 표시하지 않는다. 과거12단계 자료/빌드는 이번 소스의 제출 파일이 아니다.

검토된 코드/문서/검사 결과를 로컬과 사용자 GitHub에 저장한다. 다음 편집은 변경 기능 → 관련 검사 → 11단계 회귀 → 12단계 소스/서명/자료 검증 순서다. 서버·페이지·스토어 등록/배포 없이 이번 검증 단위를 마치고 사용자 다음 요청을 기다린다.
