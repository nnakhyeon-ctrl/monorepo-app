# 12단계 제출·출시 자료 준비 결과

## 2026-10-30 두 캐릭터/홈·선택/전투·음악 변경 후

[로컬 전후13장·새 음악](tailwing/design-pass-01/index.html)과 [결과/범위](TAILWING-DESIGN-PASS-RESULTS.md),[새 개발용 preview APK](tailwing/BUILDS.json)만 갱신했다. preview는0.1.0+1/별도 `.integration` ID이며 설치/제한 시작 확인까지다. 기존 release-inspection과 APK-INSPECTION·20장 갤러리/기존 소개는 **이전 소스의 보존 이력**이고 이번 앱의 최종 제출 증거가 아니다. 새 서명 제출 파일·스토어 캡처/아이콘/소개·정책·실서비스/실기기/iOS/보안 대기가 남는다. 제출 파일을 확정하거나 재배포/스토어 등록하지 않았다.

## 2026-10-30 후속 수정 후 파일·자료 대조

[현재 빌드/소스 지문/SHA](tailwing/BUILDS.json)의 debug preview는 독립 시작 제한 검사까지,일반 release는 종료 처리 수정 포함 빌드161.9초·[458항목 제한 정적 검사](tailwing/APK-INSPECTION.json)까지 확인했다. **release는 미서명·설치/제출 불가**다. 두 빌드의 제한 소스 지문이 현재 소스와 일치하며 이전 [빌드](tailwing/BUILD-HISTORY.json)·[정적 검사](tailwing/APK-INSPECTION-HISTORY.json)는 보존했다. [실제20장/자산27개 갤러리](tailwing/index.html)·[파일 대조](tailwing/FOLLOWUP-LOCAL-CHECKS.json)·[직접 실행](TAILWING-RUN-GUIDE.md)을 갱신했다.

남은 갱신: 테일윙 아이콘/native 시작 화면·최종 스토어 RGB 캡처/소개/정책·운영자/연락처/HTTPS 주소·심사 접근 방법·서명 AAB/Archive/IPA와 공식 테스트. 기존 AIRZERO 아이콘/홍보/정책 HTML은 이력이며 현 출시본으로 제출하지 않는다. 실제 로그인/서버/스토어/삭제 웹·Apple/iOS·실기기 성능/16KB 실행·보안 경고5개가 남아 **최종 제출 준비 완료가 아니다**. 과금/배포/스토어 등록·공개는 실행하지 않았다. 아래10월29일 파일 수치·‘현재’ 표현은 당시 이력이다.

## 테일윙 리뉴얼 이후의 현재 상태 — 2026-10-29

새 브랜드의 [12종/실제 홈·전투·카드 14장](tailwing/index.html)·[자산 출처](tailwing/ASSET-SOURCES.md)·[개발 APK/미서명 검사 APK·해시/소스 지문](tailwing/BUILDS.json)·[릴리즈 제한 정적 검사](tailwing/APK-INSPECTION.json)를 확보했다. 디버그 개발 APK는 기존 앱과 다른 `.integration` ID이며 제출 파일이 아니다. 새 일반 release 검사 APK도 **미서명·설치/제출 불가**다. 새 AAB/Archive/IPA는 만들지 않았다.

아래 AIRZERO 아이콘/배너/소개/정책 HTML/4장 캡처와 해시는 **리뉴얼 전 이력**이다. `build/app/outputs/flutter-apk/app-release.apk` 공통 출력은 새 빌드로 교체됐으므로 아래 옛 SHA/크기를 현재 파일 증거로 사용하지 않는다. 새 고정 검사 사본은 `build/tailwing-preview/tailwing-inspection-unsigned.apk`다. 새 브랜드 아이콘/native 시작 화면·스토어용 RGB 캡처·소개/정책/접근 방법을 실제 출시 구성과 다시 맞춰야 한다. 장비/서명·공개 주소/운영자·실인증/서버/스토어/삭제 웹·Apple/iOS/실기기·보안 경고 5개가 남아 있어 **최종 제출 준비 완료가 아니다**. 과금·배포·스토어 등록·실제 삭제는 실행하지 않았다.

2026-10-29 재개 후 현재 가능한 로컬 준비를 정리했다. **11단계 최종 검증과 최종 제출 준비는 미완료**다. 서명 제출 파일·공식 스토어 테스트·심사/공개를 완료로 표시하지 않는다. 비용/배포/실사용자 삭제·자동 commit/push는 하지 않았다.

## 결과와 파일

| 구분 | 확보/검사 | 남은 조건 |
|---|---|---|
| Android 검사 APK | `build/app/outputs/flutter-apk/app-release.apk`,79,881,957B. 일반 `lib/main.dart` release 로컬 빌드 exit0(84.6초) | **미서명**, 설치/제출 불가. 이 APK 실행·로그인 콜백 미실행 |
| Android 제출 AAB | **생성하지 않음** | 기존 업로드 키/스토어 앱 연속성·release signing 미준비 |
| iOS Archive/IPA | **생성하지 않음** | Mac/Xcode·유료 멤버십/Team·인증서/프로비저닝·실제 iPhone 미준비 |
| 아이콘/브랜드 | Android5파일·iOS15파일(Contents.json19슬롯) 기본 Flutter 아이콘 교체. Play512·배너1024×500·iOS1024 준비 | 실제 런처 마스크/테마·Xcode/상표/권리 최종 검토 대기. 배너는 생성 그림 |
| 실제 게임 캡처 | 가상 Android 별도 앱의 홈/1탄/무료 보호막/이동4장,RGB1080×1920. 촬영 검사1개 통과(26초) | 실기기/iOS 원본·출시 빌드 UI 대조 대기. 성능/업데이트 검사 아님 |
| 정책 자료 | 지원·개인정보·탈퇴·약관 Markdown 정정, 로컬 HTML4개·검토 목록1개 | **미공개 초안**, 접수 폼 없음. 운영자/연락처/보관/지역/HTTPS URL·실제 웹 삭제 구현 필요 |
| 소개/직접 등록 | [소개 후보](release-prep/STORE-COPY.md)·[직접 등록표](release-prep/STORE-CHECKLIST.md) | 소유자 콘솔 설정·서명·공식 테스트·개인정보 공개/등급·심사 접근 방법 준비 |

[로컬 검토 목록](release-prep/local-pages/index.html), [출처·사용 조건](release-prep/ASSET-REVIEW.md), [생성 프롬프트](release-prep/ASSET-PROMPTS.md)를 보관한다. HTML은 파일로 검토하는 자료이며 공개 호스팅/접수 경로가 아니다. 외부 스크립트/폰트/분석·인증/삭제 폼이 없다. 메타 CSP만으로 서버 보안 헤더까지 적용됐다고 하지 않는다. 브라우저/스크린리더 최종 검토는 별도다.

## APK·소스·해시 근거

- 앱 ID/Bundle ID **`com.example.raikeopeu2026.dev`**, 버전 **`0.1.0+1`** 유지. Android min24/target36/compile36. iOS source target15.0, 실제 SDK 빌드 미실행. 기존 Firebase/Google/카카오 개발 등록과 실제 스토어/출시 ID 확정은 별개이며 자동 변경하지 않았다.
- 최신 APK SHA-256: `6a95455f0a26049d7c18f03ff3f6a3218e59b1f587532b163dcc6a5bf9c0147c`.
- [APK 검사 JSON](release-prep/APK-INSPECTION.json): aapt2 ID/버전/SDK/manifest 확인, apksigner에서 **서명 없음** 확인, 공식 zipalign `-c -P 16 -v 4` 통과.64비트 native8개 PT_LOAD 정렬≥16384·offset/address 합동 확인. **실제16KB 기기 실행 통과가 아니다.**
- allowBackup/fullBackupContent/cleartext false, debuggable 없음, 생체 권한 없음. 병합 권한은 INTERNET·NETWORK_STATE·BILLING·SDK READ_GSERVICES·앱 내부 signature 권한5개. 실제 SDK 전송/로그와 개인정보 문구는 연결 후 대조해야 한다.
- ZIP431개·해제81,429,199B의 제한 검사. 지정한 개인키/service-account JSON/Bearer·refresh token/메일 action 값/isolated test 표식6종 발견0. 모든 인코딩·SDK 자동 수집·런타임 로그·비밀 부재를 보증하지 않는다. 비밀값/원문 매치는 출력하지 않았다.
- 이 APK에는 공개 인증/상품/정책 설정을 주입하지 않았다. 기존 `kDebugMode` 에뮬레이터 보호·release 통합시험 플래그 거부와 시험 코드 격리를 유지했다. 실제 SDK 포함을 인증/결제 완료로 표시하지 않으며 임시 해금을 추가하지 않았다.
- [자료별 SHA/규격](release-prep/ASSET-INVENTORY.json), [모바일 소스108파일 지문](release-prep/SOURCE-SNAPSHOT.json)은 빌드 후 허용 목록 스냅샷이다. commit 기반 재현/서명 provenance 보장이 아니며 server·tests·문서·도구·비밀/로컬 설정/캐시는 제외한다. 현재 접근한 저장소 HEAD 없음·앱 untracked이므로 새 Git 이력 검사 통과를 주장하지 않는다. 이전11단계 제한 이력 검사는 당시 기록으로 보존한다.
- Stage11 이전 APK 해시 `0d8a23243273d9927466ddba9f3af9391d01c87307662f3ade40113aee5c547f`는 아이콘 변경 전 이력이다. 동일 경로의 최신 파일과 혼동하지 않는다. `WORK-IN-PROGRESS.json`도 중단 당시 이력이며 최신 자료/검사는 위 JSON이다.

## 이번 검증과 한계

아이콘·자료/도구·정책 초안 외 게임 규칙/인증/결제/서명 설정은 변경하지 않았다. 기존 Flutter130·서버 단위21/demo43·Android 전투/설정8·인증2·가상 저장 교체2단계 통과를 유지하고 전체 반복은 하지 않았다. 새 촬영 Dart 분석 문제 없음(146.1초), 캡처1개·아이콘 APK 빌드·패키지 정적 검사와 자료 규격/해시/링크·구매 잠금 점검을 수행했다. [자료 검사16/16 통과](release-prep/MATERIAL-CHECKS.json), 문서31개/HTML17개 로컬 링크 누락0, 신규3개 도구 Node 문법 검사 통과. [11단계 결과](STAGE11-RESULTS.md)·[보안 경고5개](STAGE11-SECURITY-FOLLOWUP.md)는 최종 미완료다.

재현 도구는 앱 폴더에서 `node tool/inspect_release_apk.mjs`(저장된 APK 검사), `node tool/prepare_release_review.mjs`(정책 HTML/허용 소스 지문/자료 해시 갱신), `node tool/check_release_preparation.mjs`(규격/해시/링크·잠금 검사) 순서다. 환경의 고정 Windows SDK 경로를 확인하고 승인된 로컬 자료에만 실행한다. `prepare_release_images.mjs`는 원본 규격 변환이며 이미 완료해 반복하지 않았다. 이 도구들은 서명/설치/업로드/결제/서버 공개를 하지 않는다.

촬영 당시 가상 `.integration` debug 서명 불일치로 Flutter가 그 시험 패키지를 제거 후 설치했다. 정상 `.dev` 앱/실사용자 자료는 대상이 아니었다. 이를 업데이트/기록 보존 시험으로 표시하지 않는다. PowerShell 정책을 변경하지 않고 .NET 이미지 변환을 사용했다. 미서명 검사 APK는 설치/실행하지 않았다. 저장 지점의 iOS23개 표기는 재개 후 Contents.json 대조에서 **15파일/19슬롯**으로 바로잡았다. 검사 도구의 이전 개수 가정도 수정하고 규격/파일을 다시 확인했다.

## Android 서명 AAB 직접 준비 절차 — 현재 미실행

1. [기존 Play 앱/서명/버전](release-prep/STORE-CHECKLIST.md)을 대조하고 기존 업로드 키를 저장소 밖 사용자 보안 위치에 준비한다. 키/암호를 읽거나 새로 생성/교체하지 않았다. 실제 값 대신 경로/설정 여부만 관리한다.
2. 현재 `android/app/build.gradle.kts`의 release signing은 비어 있다. 사용자 준비 후 [공식 Flutter 서명 절차](https://docs.flutter.dev/deployment/android)에 따라 **저장소 밖** 비밀 속성 파일을 가리키는 로컬 환경 변수/보호 경로로 연결한다. storeFile/keyAlias/storePassword/keyPassword를 하드코딩·로그 출력하지 않고 debug signing fallback을 넣지 않는다. 이 연결 작업은 아직 안 했다. 클라우드 빌드는 선택하지 않았다.
3. 실제 서버/상품/정책 검증과 관련 기능→11단계 재검증 뒤 앱 폴더에서 `flutter build appbundle --release --target lib/main.dart`를 실행한다. 필요한 공개값만 검토된 `--dart-define-from-file`로 주입하고 서버 비밀/통합시험/emulator 플래그를 넣지 않는다. 이 SDK에서는 플러그인 정상 재생성을 위해 `--no-pub`를 붙이지 않는다. 이번 검사 APK 명령은 `flutter build apk --release --target lib/main.dart`였다.
4. 예상 `build/app/outputs/bundle/release/app.aab`는 현재 미생성이다. 생성 후 JAR 서명/지문·Bundle manifest/버전·해시·생성 APK의16KB/실기기·콜백/계정/결제를 검증한다. APK용 검사 도구를 AAB에 그대로 적용하지 않는다. 업로드 키와 Play 기기 배포 앱 서명을 구분한다. 파일 생성은 업로드가 아니다.
5. 테스트 트랙/라이선스 테스터·테스트 결제수단 확인은 사용자 직접이다. 일반 카드/실제 금액이면 진행하지 않는다. 미서명 AAB·debug APK는 제출 대체품이 아니다.

## iOS 직접 준비 절차 — 현재 미실행

Mac·Xcode/SDK·사용자 서명/프로비저닝이 필요하다. 제출에는 Apple Developer Program 조건이 필요하지만 **유료 가입 금지에 따라 가입하지 않는다.** 계정 사이트 로그인만 완료이며 Apple 로그인·Archive/IPA/Sandbox는 대기다. [Flutter 공식 iOS 절차](https://docs.flutter.dev/deployment/ios).

사용자 조건 준비 후 `flutter doctor -v`로 iOS 도구 확인 → `ios/Runner.xcworkspace`에서 기존 Bundle/Team·target·Sign in with Apple·URL scheme/entitlement/Privacy Manifest 대조 → 가상/실제 iPhone 테스트와 iOS 원본 촬영 → 승인된 공개 설정으로 `flutter build ipa --release --target lib/main.dart` 순서다. 예상 Archive는 `build/ios/archive/`, IPA는 `build/ios/ipa/`이며 서명/실행/SHA/내보내기를 별도 확인한다. Windows/Android 통과를 iOS로 대체하거나 Xcode 업로드/클라우드 빌드를 실행하지 않는다.

## 공식 요구 대조 — 2026-10-29

- 일반 Play 신규/업데이트는2026-08-31부터 target API36+다. 검사 APK36은 심사 통과가 아니다. [공식 target SDK](https://developer.android.com/google/play/requirements/target-sdk).
- 현재16KB 문서는64비트 native 지원과 업데이트 차단 시점2027-02-01을 안내한다. 정적 검사 외16KB 환경 실행은 별도다. [공식 페이지 크기](https://developer.android.com/guide/practices/page-sizes).
- Play 아이콘512²/32bit PNG/≤1024KB, 배너1024×500 RGB, 스크린샷 최소2장·게임 권장3장9:16/16:9 기준을 대조했다. 현재4장1080×1920 RGB. [공식 그래픽](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).
- Apple은 Xcode26+/iOS26 SDK(2026-04-28부터), target iOS13+(2026-09-09부터) 요구다. 소스 target15.0과 실제 Xcode 빌드는 별개다. [공식 현재 요구](https://developer.apple.com/news/upcoming-requirements/). [iOS 실제 화면 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)에 따라 촬영하고 Android 이미지를 바꾸지 않는다.

## 남은 조건과 소유자 첫 작업

상품 ID7개·공개 URL4개/가격/국가 미정·구매 잠금 유지. 실제 이메일/Google/카카오/Apple·서버/규칙/App Check/메일/세션·스토어 API/공식 알림·복원/만료/환불·공개 웹 삭제·전체 동기화/구매 복구 정책·실기기/성능·iOS·보안 경고가 남는다. 모의 검사로 대체하지 않았다.

첫 작업은 [Firebase 기존 일반 설정](https://console.firebase.google.com/project/airzero-strike-dev/settings/general)에서 프로젝트ID `airzero-strike-dev`·Android/iOS ID·기존 개발 지문·Spark를 **대조만** 하는 것이다. 새 프로젝트/키/결제 계정을 만들지 않는다. 이후 [설정 순서](EXTERNAL-SETUP-ORDER.md)·[직접 확인표](release-prep/STORE-CHECKLIST.md)를 따른다. 준비 후 해당 기능 단계→11→12 순서로 변경 영향만 재검증한다. 이번 결과를 저장하고 배포/후속 단계로 자동 이동하지 않는다.
