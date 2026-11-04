# 테일윙 이름 변경·GitHub 저장 완료

2026-11-04 KST. 대상은 기존 게임 한 앱이며 바탕화면 모노레포 원본을 유지했다.

## 이름과 경로

- 현재 게임 이름: **테일윙 · TAILWING**.
- 앱 폴더: `games/tailwing`.
- VS Code 작업공간: 루트 `tailwing-codex.code-workspace`.
- F5 구성·실행 명령·문서 링크·검사 도구의 이전 경로 27개 파일을 수정했다. 서버 npm 패키지 표시명도 `tailwing-auth-backend`로 맞췄다.
- 이전 폴더/작업공간 파일은 이동으로 대체했다. 복제 앱/중첩 Git을 새로 만들지 않았다. 옛 이름은 과거 작업 이력에만 남길 수 있다.
- Android/iOS 앱 ID·Dart package·기존 저장 namespace·인증/결제 설정 키는 기존 데이터/연결 호환을 위해 유지했다. Android Gradle/manifest·iOS Info.plist·기록/선택 저장 코드가 이전 커밋과 같음을 줄바꿈 차이를 제외하고 확인했다.

## 실제 저장 확인

기존 [nnakhyeon-ctrl/monorepo-app의 main](https://github.com/nnakhyeon-ctrl/monorepo-app/tree/main)에 소스·자산·문서·검사를 직접 저장했다. 첫 전체 스냅샷은 [0cee59d](https://github.com/nnakhyeon-ctrl/monorepo-app/commit/0cee59d1529b73e6defaba055c4747e6177d44ee)이며 **583개 파일의 전체 Git 트리 SHA가 로컬과 동일**하다: `86b8059197aa5b4fa3c24ed1ffbfb8a3a338242f`. 이 결과 문서/최신 안내는 후속 커밋으로 함께 반영한다.

PC Git push의 인증 대기 대신 연결된 GitHub 도구를 사용했다. 바이너리 자산은 SHA를 대조했고, 큰 소스 요청의 시간 초과는 작은 묶음·폴더 단위 트리로 나누어 해결했다. SDK/캐시/빌드·비밀/실제 계정 데이터는 업로드하지 않았다. 원격을 새로 만들거나 기존 사용자 파일/원본을 삭제하지 않았다. 로컬의 이전 커밋 이력도 별도 브랜치로 보존하고 main은 원격 main을 추적하도록 정리한다.

## 이름 변경 후 재검증

| 검사 | 결과 |
|---|---|
| Flutter 전체 | 185개 통과 |
| Flutter 정적 분석 | 문제 없음, 11.1초 |
| 서버 TypeScript 빌드/단위 | 빌드 통과·21개 통과 |
| 가상 인증/기록/계정/결제 통합 | 43개 통과, 약 50초. 실계정/실결제 아님 |
| 루트 CI | 문서·민감정보·69개 JS/16개 Bash·Terraform fmt·안전 9개/도구 1개 통과 |
| 실제 Android/iOS 실행·성능 | 현재 PC SDK/장비 준비 전으로 미검증 |

이름 변경 직후 루트 CI는 아직 Git 인덱스에 남은 옛 경로를 민감 경로로 감지했다. 실제 이동을 Git 인덱스에 반영한 뒤 같은 검사가 통과했다. 검사 예외를 넓히거나 오류를 무시하지 않았다.

첫 GitHub Linux CI에서는 의도적으로 업로드하지 않은 개인 `.claude/settings.json`을 테스트가 필수 파일처럼 읽는 문제가 발견됐다. 해당 파일이 있을 때 JSON 문법 검사를 유지하고, 깨끗한 체크아웃에서는 파일이 없어도 실행하도록 수정했다. 대신 개인 설정/SDK/Flutter 상태가 반드시 Git에서 제외되는 검증을 추가했다. 실제 권한 설정을 수정하거나 개인 설정 파일을 공개하지 않았다.

## 바로 이어갈 방법

VS Code에서 `tailwing-codex.code-workspace`를 열거나 PowerShell에서 다음을 실행한다.

```powershell
Set-Location -LiteralPath 'C:\Users\nnakh\OneDrive\Desktop\App\monorepo\games\tailwing'
& ..\..\flutter\bin\flutter.bat --suppress-analytics test --no-pub
& ..\..\flutter\bin\flutter.bat devices
& ..\..\flutter\bin\flutter.bat run --debug --dart-define=AIRZERO_INTEGRATION=true -t lib/main.dart
```

현재 PC의 Android SDK/기기 준비 후 실행 명령을 사용한다. 다음 단위는 실제 기기/가상 기기에서 홈·선택·방패/전투 입력과 profile/release 프레임·발열 확인이다. 나머지 10종 디자인은 현재 [전후 비교](tailwing/design-pass-01/index.html)를 확인한 뒤 결정한다. 기존 기록·보유 권한·구매 잠금·무료/유료 수치를 유지했고 스토어/서버 배포·실과금·실사용자 삭제는 하지 않았다.
