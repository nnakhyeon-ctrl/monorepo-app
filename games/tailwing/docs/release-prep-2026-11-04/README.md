# 테일윙 12단계 로컬 준비 · 13단계 계속 편집

2026-11-04 KST. **제출 준비 완료가 아니다.** 사용자가 만족할 때까지 캐릭터·기술·기능을 계속 편집하고, 나중에 Google Play 게시를 결정한다. 지금은 서버/페이지 공개·스토어 등록/테스트 배포/심사/공개를 하지 않는다. 13단계 전달의 예시 문구는 실제 글자 크기/검색 기능 요청으로 적용하지 않았다.

[로컬 자료 열기](index.html) · [실행/서명 절차](RELEASE-STEPS.md) · [직접 확인표](STORE-CHECKLIST.md) · [소개 후보](STORE-COPY.md) · [계속 편집](STAGE13-EDITING.md)

## 확보와 대기

| 영역 | 현재 상태 |
|---|---|
| 검증 소스 | [허용 소스의 SHA와 지문](SOURCE-SNAPSHOT.json), [플랫폼/설정 상태](READINESS.json). 현재 커밋/작업 상태를 함께 기록 |
| Android | 0.1.0+1, 기존 `com.example.raikeopeu2026.dev` 유지. 설치된 Flutter 기본 target 36 확인. Android SDK·실제 서명 연결 없음. 서명 AAB **미생성** |
| iOS | Windows, Mac/Xcode·서명/프로비저닝 준비 전. Archive/IPA **미생성**. 클라우드 빌드 미선택/미사용 |
| 출시 그림 후보 | 직접 작성한 편집 가능 SVG 원본과 Play 512 PNG·1024×500 RGB 배너·iOS 1024 RGB PNG. 최종 선택/런처/마스크 미검증, 네이티브 앱에는 **미적용** |
| 실제 화면 자료 | 2026-10-30 가상 Android debug의 실제 Flutter 렌더링 4장 사본/출처·규격/SHA. **현재 서명 릴리즈의 새 캡처 아님**. 구독 갑판 검사는 무료 보호막 홍보와 구분 |
| 웹 문안 | 지원·개인정보·계정 삭제·이용/구독 HTML 로컬 초안 4개와 목록. 폼/스크립트/실제 문의·삭제 처리/공개 URL 없음 |
| 실행/콜백·구매 | 현재 서명 릴리즈로 미실행. 실제 로그인/서버·App Check/스토어/공개 삭제 웹·플랫폼 테스트는 대기 |
| 현재 보안 감사 | [npm 공식 registry 재감사](DEPENDENCY-AUDIT.json): development 포함 moderate 16개 / production moderate 6개, high/critical 0. 과거 5/0 기록보다 증가, 최종 보안 미완료 |

이전 `docs/release-prep/`와 미서명 APK는 과거 AIRZERO 그래픽/검사 이력이며 최종 제출 자료로 사용하지 않는다. 새 벡터는 기존 3D 캐릭터 원본을 수정/대체한 결과가 아니라 편집 가능한 아이콘/배너 후보다. 기존 native 아이콘의 옛 항공기 그림은 최종 디자인 결정 뒤 별도 교체/검증해야 한다.

## 재생성과 검증

앱 폴더 PowerShell에서 실행한다. 첫 명령은 격리된 headless Edge로 작성한 SVG를 래스터화하며 사용자 브라우저 세션/자료를 사용하지 않는다. C# 도구는 RGB/RGBA 형식 변환만 한다. 새 외부 패키지를 설치하지 않는다.

```powershell
node tool/render_release_vectors.mjs
node tool/prepare_release_pages.mjs
node tool/prepare_release_candidate.mjs
node tool/check_release_candidate.mjs
node --test tool/release_candidate.test.mjs tool/check_auth_readiness.test.mjs tool/check_billing_readiness.test.mjs
```

자료를 수정한 뒤 준비 도구를 다시 실행해 [해시 목록](ASSET-INVENTORY.json)과 [검사 결과](CHECKS.json)를 갱신한다. 소스/신규 자산이 바뀌면 저장된 지문 대조는 실패하도록 되어 있다. 이를 현재 빌드 검증 통과로 덮어쓰지 않고 영향 기능→11→12단계로 돌아간다. 서명/릴리즈 실행과 Play 공식 테스트는 이 정적 자료 검사와 별개다.

## 공식 요건 확인

2026-11-04 공식 문서 조회 기준이다. 실제 제출 시 소유자가 다시 확인한다.

- Play의 일반 모바일 신규/업데이트는 2026-08-31부터 Android 16/API 36 이상 대상이다. [Play 공식 target API](https://support.google.com/googleplay/android-developer/answer/11926878).
- 네이티브 라이브러리를 포함하는 Flutter 앱은 16KB 지원을 빌드·생성 APK·16KB 장비에서 확인해야 한다. 현재 Android 공식 페이지에는 API 35 이상 64비트 앱의 지원 요구와 2027-02-01 업데이트 제한을 안내한다. 예외/기한은 실제 Play 앱 경고와 함께 확인한다. [Android 공식 페이지 크기](https://developer.android.com/guide/practices/page-sizes).
- iOS 제출은 2026-04-28부터 Xcode 26 이상/iOS 26 SDK 이상 요구가 안내되어 있다. [Apple 공식 제출 요건](https://developer.apple.com/news/upcoming-requirements/).
- Play 그림 규격은 아이콘 512×512, 배너 1024×500 등이며 형식·마스크·콘텐츠를 별도로 검토한다. [Play 공식 그림 안내](https://support.google.com/googleplay/android-developer/answer/9866151). iOS는 실제 앱/대상 기기 슬롯의 원본 화면이 필요하며 Android 캡처를 대체 사용하지 않는다. [Apple 스크린샷 안내](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

위 링크 확인과 제한 정적 검사는 무결함/유출 없음/심사 통과/수익을 보장하지 않는다.

## 새로 확인한 보안 대기

기존 lockfile을 가상 전용 폴더로 복사하고 개인 npm 설정 없이 익명 감사했다. 설치/수정/배포는 하지 않았다. production에서도 `glob`/`minimatch` 관련 경고가 보고되어 과거 production 0 기록을 현재 결과로 재사용할 수 없다. 이는 Node 서버/개발 lockfile 범위이며 Flutter 바이너리의 동일 취약점 포함 여부나 실제 악용 가능성을 증명하지 않는다. [glob 권고](https://github.com/advisories/GHSA-3g3m-2fjr-6pw4)·[minimatch 권고](https://github.com/advisories/GHSA-g3hv-75wg-m249)를 바탕으로 호환 패치/입력 경로를 기능 단계에서 검토한 뒤 서버 단위/demo→11→12로 돌아가야 한다. 강제 fix/override/major 변경은 하지 않았다.


편집 원본은 graphics/icon-master.svg와 feature-master.svg입니다. ios-icon-master.svg/PNG는 파생 산출물이므로 다시 내보내면 갱신됩니다. HTML을 직접 편집한 경우 페이지 생성기는 해시로 감지해 덮어쓰지 않고 중단합니다. 문안을 다시 생성하려면 tool/prepare_release_pages.mjs의 원본을 편집하고 기존 사용자 변경을 먼저 보존합니다.
