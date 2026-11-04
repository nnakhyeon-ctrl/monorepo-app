# 11단계 잔여·12단계 준비 저장 지점

## 최신 재개 결과 — 2026-10-29

사용자가 재개를 요청해 아래 남은 로컬 준비를 진행했다. 최신 상태는 [12단계 준비 결과](STAGE12-PREPARATION.md)다. 이전 중단 기록은 이력으로 유지하며 지금 미완성 목록으로 혼동하지 않는다.

- 최신 APK431개/81,429,199B 제한 검사, aapt2 ID/버전/SDK/권한·backup/cleartext/debug 확인, unsigned 확인, ZIP/64비트 ELF8개16KB 정렬 정적 통과. 이 파일은 설치/제출용이 아니며 실제16KB/실기기 실행 미검증. SHA `6a95455f0a26049d7c18f03ff3f6a3218e59b1f587532b163dcc6a5bf9c0147c`.
- 아이콘·배너/4장 실제 캡처의 출처/규격/형식과 Android5파일·iOS15파일/19슬롯 크기를 정리했다. 이전 iOS23개 표기는 개수 오기로 정정했다. 전체 기체/게임 화면을 육안 확인했고 실제 런처 마스크/Xcode는 대기다.
- 지원/약관의 전체 동기화·실제 삭제 제공 표현을 정정했다. 미공개 HTML4개+목록1개, 소개 후보·스토어 직접 확인표·빌드/서명/장비/설정 절차를 작성했다. 공개 URL/가격/상품을 임의 확정하거나 폼/배포를 추가하지 않았다.
- `inspect_release_apk.mjs`, `prepare_release_review.mjs`, `check_release_preparation.mjs`로 로컬 검사·자료 생성/지문·규격/해시/링크 검증을 실행했다. [자료 검사16/16 통과](release-prep/MATERIAL-CHECKS.json), 문서31/HTML17 링크 누락0·신규3도구 문법 통과다. 소스108파일은 허용 목록 지문이며 전체 감사/commit 증거가 아니다. 현재 HEAD가 없어 새 이력 검사를 통과했다고 하지 않는다.
- 게임/인증/결제/서명 설정은 그대로다. 전체130/21/43 등을 불필요하게 반복하지 않았다. 실제 서버/스토어/공개 삭제·iOS/실기기·서명 파일·보안 경고5개/구매 잠금은 유지했다. 과금/운영·스토어 공개·실사용자 삭제·commit/push는 하지 않았다.

다음은 소유자가 [외부 설정 순서](EXTERNAL-SETUP-ORDER.md)에 따라 기존 Firebase/개발 서명부터 확인하고 서버 방식·서명/장비·법적 정보/URL·테스트 상품을 준비하는 단계다. 관련 기능→11단계 영향 검사→12단계 재생성 순서로 돌아온다. 현재 가능한 자료를 저장한 뒤 멈추며 자동 작업은 남기지 않는다.

## 이전 사용자 중단 당시 기록

2026-10-29. 사용자가 “진행 중인 거 저장하고 작업 중단, 오늘 저녁에 이어서”를 요청했다. **현재 사용자 요청으로 중단**한다. 자동 재개/추가 검사·작업을 하지 않는다. 실제 대상은 `C:\Users\user\Desktop\App\monorepo\games\tailwing`다.

## 저장한 결과

- [11단계 잔여 보안 결과](STAGE11-SECURITY-FOLLOWUP.md): 현재 npm 전체 moderate5·production0. 직접 GHSA/CVE2건과 상위 전파3개를 패키지/버전/영향/대응으로 구분했다. audit fix dry-run 변경0, 같은-major 최신도 취약 범위를 요구하며 강제 downgrade/override·경고 숨김을 하지 않았다. dependency/lockfile은 이번에 변경하지 않았다.
- 공개 준비 점검11개 통과, 인증 공개 대조 PASS·실제 연결 NOT_RUN, 결제 PENDING·EXAMPLE_ONLY_NOT_RUNTIME·구매 잠금 유지. 과거 Flutter130·서버21/43·Android8/2·저장2단계 통과 기록은 보존한다.
- [외부 설정 첫 화면·입력 항목·장비 순서](EXTERNAL-SETUP-ORDER.md)를 저장했다. 첫 작업은 기존 Firebase 일반 설정/앱/요금제의 읽기 전용 확인이다. 실제 콘솔을 재조회하거나 변경하지 않았다.
- 앱 아이콘이 Flutter 기본 아이콘임을 확인해 기존 자체 오로라(P-38 형태) 기체를 참조한 navy/teal 아이콘·배너를 내장 imagegen으로 제작했다. 생성 원본은 `docs/release-prep/graphics/icon-source-v1.png`, `feature-source-v1.png`에 복사했다. 외부 API/CLI 키를 쓰지 않았다. [프롬프트 기록](release-prep/ASSET-PROMPTS.md).
- Play용512×512 RGBA 아이콘, iOS용1024×1024 RGB 아이콘, Play1024×500 RGB 배너와 Android5파일/iOS15파일(19슬롯, 당시23개 표기는 재개 후 정정) native 아이콘 리소스를 변환했다. 앱 ID·버전·서명 설정·게임 아트/규칙은 변경하지 않았다. 당시 마스크/실제 런처·Xcode 검증과 출처/사용 조건 최종 정리는 남아 있었다.
- `integration_test/store_capture_test.dart`·`tool/capture_store_android.mjs`로 **별도 가상 `.integration` 앱의 실제 무료 플레이 프레임4장**을1080×1920으로 촬영했다. 촬영 검사1개 통과(26초). 적/점수/유료 권한을 직접 주입하지 않고 일반 드래그·자동 사격·무료 보호막을 사용했다. 실제 계정/스토어/실기기/iOS 검증이 아니다.
- 캡처 원본은 `docs/release-prep/screenshots/android/raw/`, 같은 크기의 RGB 변환본4장은 바로 상위 `android/`에 있다. UI 합성/크롭/리터치/확대는 하지 않았다. 홈과 보호막 화면은 육안 확인했으나 전체 자료 최종 검토는 남는다.
- 촬영 설치 시 **가상 시험 패키지의 debug 서명 불일치**로 Flutter가 기존 `.integration` 패키지를 제거한 뒤 설치했다. 실제 일반 `.dev` 앱/사용자 자료는 대상이 아니다. 이 촬영을 서명 연속성/데이터 보존 업데이트 시험으로 표시하지 않는다. 기존9·11단계의 가상 저장 유지 통과와 구분한다.
- PowerShell `.ps1` 이미지 변환 실행은 기존 실행 정책에 막혔다. 정책을 완화/우회하지 않고 해당 새 파일을 제거했다. 대신 기본 .NET Framework C# 컴파일러/이미지 API를 사용하는 `tool/ReleaseImageHelper.cs`·`tool/prepare_release_images.mjs`로 변환을 완료했다. helper exe/공개 작업 계획은 앱의 무시되는 `.runtime` 안에만 있으며 제출 자산이 아니다.
- 새 촬영 Dart 파일 정적 분석 **문제 없음**(146.1초). 기존 전체 검사 반복은 하지 않았다.
- 아이콘 반영 후 일반 `lib/main.dart` release APK 로컬 빌드 **exit0**(84.6초, 표시76.2MB). 이 최신 APK의 서명/manifest/리소스·제한된 비밀 패턴·SHA/16KB 정렬 검사는 **아직 안 했다**. Stage11의 이전 APK 해시와 혼동하지 않는다. AAB/Archive/IPA는 생성하지 않았다.
- 실행하던 분석/빌드는 중단 요청을 처리할 때 이미 exit0으로 종료돼 결과만 회수했다. 촬영 VM은 종료했고 추가 자동 작업을 남기지 않았다.

현재 산출물 파일/해시 저장 스냅샷은 `release-prep/WORK-IN-PROGRESS.json`을 따른다. 이는 준비 완료 manifest가 아니다.

## 재개할 때 남은 작업

1. README/ROADMAP·이 문서와 현재 파일 상태를 확인한다. 사용자 변경을 유지한다. 전체 통과 검사를 반복하지 말고 새 변경/미실행 범위만 진행한다.
2. 새 아이콘의 native 파일/마스크·규격/브랜드·출처/사용 조건·프롬프트 기록을 정리한다. 이미지 생성 원본은 보존한다. 제작한 배너는 실제 게임 스크린샷과 구분한다.
3. 최신 미서명 **검사 APK**의 ID/버전/target API36·네트워크/권한·디버그/모의 코드/인증 표식·서명 상태·ZIP/ELF16KB 정렬과 SHA-256을 확인한다. 기존 Stage11 APK 경로가 새 빌드로 갱신됐다는 이력을 기록한다. 정적 검사만으로 실제16KB 기기/런타임 통과를 선언하지 않는다.
4. [12단계 준비 문서](STAGE12-PREPARATION.md)를 완성한다. 서명/배포 설정이 없는 동안 서명 AAB·IPA를 만들었다고 하지 않는다. Windows/Mac·서명/프로비저닝·기기/외부 설정별 직접 절차를 남긴다. 기존 키를 읽거나 임의 생성/교체하지 않는다.
5. 지원·개인정보·탈퇴/약관 Markdown의 오래된 전체 동기화/구현 표현을 현재 상태로 맞추고 **로컬 미공개 HTML 검토본**을 준비한다. 실제 웹 Auth/App Check/삭제 어댑터 구현·서버/HTTPS 공개는 미완료로 유지한다. 운영자/연락처/보관 기간/국가/URL은 임의 확정하지 않는다.
6. 검증된 무료 기능 중심 소개 문구·같은 혜택 월/연 구독 조건·자료 목록/해시·직접 스토어 등록 확인표·관련 기능 단계→11→12 복귀 경로를 작성한다. 이미 생성한 실제 캡처4장과 icon/banner를 재사용한다. 필요 시 장비별 원본을 다시 촬영한다.
7. README/ROADMAP·11/12 관련 기록에 구현/확보/미실행/소유자 직접 작업을 구분하고 문서/자료 링크와 파일 지문을 확인한다. 최종 제출 준비 완료로 표시하지 않는다.

## 공식 요구 확인 기록 — 자료 작성에 반영할 것

2026-10-29 공식 문서에서 Play 신규/업데이트 target API36(2026-08-31부터), native16KB 페이지 지원,512px32-bit icon·1024×500 RGB feature graphic·실제 RGB screenshots 최소2장/권장 게임3장9:16의1080×1920을 확인했다. 현재4장 캡처는 RGB/9:16 변환까지다. [Play target SDK](https://developer.android.com/google/play/requirements/target-sdk), [16KB](https://developer.android.com/guide/practices/page-sizes), [그래픽 규격](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).

Apple은 현재 Xcode26+/iOS26 SDK, iOS13+ 대상의 업로드 요구를 확인했다. 소스 deployment target15.0은 별도이며 Xcode/실제 기기 빌드는 미실행이다. iPhone large display는 실제 기기/시뮬레이터 크기로 촬영하고 Android 이미지를 iOS 화면으로 바꾸지 않는다. [Apple 현재 요구](https://developer.apple.com/news/upcoming-requirements/), [스크린샷 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), [Flutter Android](https://docs.flutter.dev/deployment/android), [Flutter iOS](https://docs.flutter.dev/deployment/ios).

상품 ID/가격·공개 URL·실제 서버/스토어·Apple 유료 멤버십/Team·Mac/Xcode/iPhone·Android 실기기 미준비, 구매 잠금을 유지한다. 과금 전환·실제 청구·서버/페이지 공개·스토어 등록/업로드/공개·실사용자 삭제·자동 commit/push는 하지 않았다. 사용자 재개 요청 전 멈춘다.
