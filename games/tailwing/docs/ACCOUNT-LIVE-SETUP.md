# 9단계 실제 연결 준비·직접 설정 안내

2026-10-27. [9단계 로컬 검증 결과](ACCOUNT-MANAGEMENT-RESULTS.md)의 통과 기록은 유지한다. 이번 후속 작업은 기존 공개 설정의 오프라인 대조와 실제 연결의 선행 조건 정리다. 로그인된 콘솔·실제 사용자·운영 DB·비밀 파일을 조회하지 않았고 과금/배포/삭제를 실행하지 않았다. 대상은 `C:\Users\user\Desktop\App\monorepo\games\tailwing`다.

## 지금 확인된 상태

| 구분 | 확인된 근거 | 다음 조건 / 현재 막힌 이유 |
|---|---|---|
| 인증 서버 | 기존 TypeScript·Firebase Admin·개인 API·demo 검사 구현. 실제 서버는 이전 기록상 미배포 | 현재 Functions 구조의 배포는 Blaze 연결 필요. 무료 유지 조건에 따라 배포하지 않음 |
| Google | 기존 Android/iOS/Server OAuth 3개를 재사용. 로컬 공개 Client ID 대조 통과 | 콘솔의 현재 테스트 사용자·서명·동의 설정 재확인, 서버·App Check·실제 Android/iOS 왕복 |
| 카카오 | 기존 앱 `1614509`·Native Key·iOS 콜백의 로컬 대조 통과 | 콘솔 ON/OIDC/플랫폼/최소 동의 재확인, 서버·톡 설치/미설치·취소·실제 왕복 |
| 외부 삭제 페이지 | demo 가상 이메일 웹 요청과 보안/재시도 검사 완료 | 웹 본인 확인·웹 App Check·웹 전용 요청 어댑터 추가 구현, HTTPS 주소/지원/처리 기한 및 서버 필요 |
| Apple | 사용자가 계정 로그인 완료·유료 멤버십 없음 확인. 준비 플래그 비활성 | 지원 capability가 있는 멤버십/Team, Apple 철회 처리 추가 구현, Mac/Xcode·iPhone. 유료 가입 안 함 |
| iOS | Bundle ID·entitlements·공개 콜백 소스 준비 | 현재 Windows에 Xcode 빌드 도구 없음. Mac 접근 가능 여부와 실제 iPhone 미확인 |
| Android 실기기 | 앞선 Android 가상 기기 인증2개·전투/설정7개 통과 유지 | 이번 `adb devices`에서 연결된 기기 없음. USB 기기 연결 및 실제 서버/App Check 준비 필요 |

공개 설정 대조는 앱의 Firebase 키/앱 ID 형식, 프로젝트/환경, 서버 모바일 허용 목록, Google/Kakao 값 일치, iOS 콜백 및 비활성 플래그 **16개 통과**다. 콘솔 재조회·실제 토큰 검증·등록된 개발 서명 재대조를 대신하지 않는다. Firebase Spark 상태는 이전 확인 기록이며 이번에 청구 콘솔을 다시 읽지 않았다.

## 1. 지금 할 일 — 기존 등록 확인부터

아래 순서에서 **새 프로젝트·새 OAuth 클라이언트·새 카카오 앱을 만들 필요는 없다.** 기존 항목이 없거나 다르면 값을 덮어쓰지 말고 일단 확인을 멈춘다. 로그인/2단계 인증은 공식 사이트에서 직접 수행한다. 전달할 내용은 “일치/다름/설정 없음” 정도면 충분하다.

### 1-1. Firebase 프로젝트·앱·요금 확인

접속: [AIRZERO STRIKE DEV 일반 설정](https://console.firebase.google.com/project/airzero-strike-dev/settings/general).

| 순서 | 화면 / 항목 | 확인할 값·동작 |
|---|---|---|
| 1 | 프로젝트 설정 → 일반 → 프로젝트 ID | `airzero-strike-dev`. 비슷한 이름의 다른 앱 프로젝트를 선택하지 않음 |
| 2 | 프로젝트 이름 | 기존 `AIRZERO STRIKE DEV` 재사용 |
| 3 | 내 앱 → Android | 패키지 `com.example.raikeopeu2026.dev`. 기존 등록 유지 |
| 4 | 내 앱 → iOS | Bundle ID `com.example.raikeopeu2026.dev`. 기존 등록 유지 |
| 5 | Android의 SHA 인증서 지문 | 현재 개발 서명의 SHA-1/SHA-256과 대조. 값 자체는 채팅/문서에 복사하지 않음. upload/Play/release 서명과 혼용하지 않음 |
| 6 | 사용량/결제 또는 좌측 요금제 표시 | Spark인지 직접 확인만 함. “업그레이드/Blaze/결제 계정 연결”은 진행하지 않음 |

내 앱의 API key/App ID는 공개 클라이언트 값이다. 이미 `config/.local-public/`에 준비되어 있으므로 재다운로드/새 키 생성은 필요 없다. 로컬 대조가 통과했더라도 키 제한·현재 콘솔 일치는 별도 확인 사항이다. 관리자 키·서비스 계정 JSON은 다운로드하지 않는다.

### 1-2. Google — 기존 3개만 확인

접속: [Google Auth Platform 클라이언트](https://console.cloud.google.com/auth/clients?project=airzero-strike-dev).

| 기존 이름 | 유형 / 입력 항목 | 맞출 값 |
|---|---|---|
| AIRZERO STRIKE Android DEV | Android / 패키지 이름 / SHA-1 | 기존 앱 패키지와 해당 개발 서명 |
| AIRZERO STRIKE iOS DEV | iOS / Bundle ID | 위 Bundle ID |
| AIRZERO STRIKE Server DEV | 웹 애플리케이션 / 공개 Client ID | 모바일 `AIRZERO_GOOGLE_WEB_CLIENT_ID`와 서버의 같은 공개 항목. 모바일 ID token의 audience 용도 |

1. 프로젝트 선택기가 `airzero-strike-dev`인지 먼저 확인한다.
2. [브랜딩](https://console.cloud.google.com/auth/branding?project=airzero-strike-dev)에서 기존 앱 이름과 승인받은 본인 지원/개발자 연락처를 유지한다. 주소를 소스나 채팅으로 옮기지 않는다.
3. [대상](https://console.cloud.google.com/auth/audience?project=airzero-strike-dev)에서 외부/테스트 중 상태와 승인받은 본인 개발 계정이 테스트 사용자에 있는지만 확인한다. 운영 게시·브랜드 검증 제출은 하지 않는다.
4. 추가 Drive/Calendar/연락처 권한은 신청하지 않는다. 소셜 사용자에게 별도 이메일 가입을 요구하지 않는다.
5. 현재 native 흐름은 서버 검증 → Firebase custom token이다. **Firebase Google provider를 켜서 이 서버를 우회하는 방식으로 바꾸지 않는다.** 기존 Web Client의 secret이나 임의 redirect URI를 모바일에 추가하지 않는다. 외부 삭제용 웹 인증의 redirect는 나중에 실제 도메인/별도 웹 설계에 맞춰 설정한다.

공식 Android 인증은 Credential Manager를 사용하며, 현재 프로젝트의 기존 Google native 어댑터를 유지한다. 실제 계정 선택/nonce/서버 검증은 아직 미실행이다. [Google 공식 Android 인증](https://developers.google.com/identity/android-credential-manager).

### 1-3. 카카오 — 기존 앱 1614509

접속: [AIRZERO STRIKE DEV 카카오 앱](https://developers.kakao.com/console/app/1614509), [로그인 설정](https://developers.kakao.com/console/app/1614509/product/login).

| 순서 | 항목 | 확인할 내용 |
|---|---|---|
| 1 | 앱 이름 / 개발자·회사명 | 기존 AIRZERO STRIKE DEV / 케일. 새 앱 생성 안 함 |
| 2 | 카카오 로그인 → 사용 설정 | 기존 ON 확인 |
| 3 | 카카오 로그인 → OpenID Connect | 기존 ON 확인. 이 서버는 ID token과 opaque access token을 함께 검증 |
| 4 | 앱/플랫폼 키 → Native App Key의 Android 설정 | 기존 패키지와 개발 인증서의 Base64 키 해시. Google의 콜론 형식 SHA-1을 그대로 넣지 않음 |
| 5 | 동일 Native Key의 iOS 설정 | 기존 Bundle ID. App Store ID/Team을 추측해서 채우지 않음 |
| 6 | 동의항목 | 닉네임/사진/이메일/전화번호/친구/메시지 등을 추가 필수로 켜지 않음 |
| 7 | 앱 콜백 | 코드가 만드는 `kakao<Native App Key>://oauth`와 iOS 공개 콜백의 일치 확인. 실제 키/URL 전체를 공유하지 않음 |

콘솔 메뉴 이름이 바뀌면 “앱 → 플랫폼 키 → 네이티브 앱 키”와 “카카오 로그인”을 기준으로 찾는다. **현재 모바일 native 방식에 REST API 키/REST client secret/웹 redirect 방식을 섞지 않는다.** 외부 삭제 페이지의 웹 카카오 인증은 별도 웹 흐름을 구현한 뒤 설정해야 한다. [카카오 설정](https://developers.kakao.com/docs/ko/kakaologin/prerequisite), [공식 Flutter native/웹 구분](https://developers.kakao.com/docs/ko/kakaologin/flutter).

## 2. 실제 서버 연결 — 현재는 비용 조건에서 대기

확인 위치: [Functions](https://console.firebase.google.com/project/airzero-strike-dev/functions).

공식 문서는 Functions의 로컬 에뮬레이션과 배포를 구분하고 배포에 Blaze를 요구한다. 무료 사용량이 있더라도 청구 가능성/결제 계정 연결이 없어지는 것은 아니다. 현재 요청에 따라 요금제 전환·배포를 하지 않는다. [Firebase Functions 시작하기](https://firebase.google.com/docs/functions/get-started), [공식 요금제](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans).

현재 구조를 유지한 실제 원격 로그인은 이 조건이 해결되기 전에는 완료할 수 없다. 나중에 사용자가 서버 연결을 승인할 때 **호스팅 방식·발생 가능한 비용·데이터 위치·권한·배포 대상**을 먼저 확정한다. 다른 호스팅으로 옮기는 것은 별도 설계/보안 검증이며 이번에 자동 변경하지 않았다.

이후 승인된 개발 서버에만 적용할 순서:

| 순서 | 접속 위치 / 항목 | 준비할 내용 — 지금 생성/적용하지 않음 |
|---|---|---|
| 1 | Firebase → Firestore Database | 앱 전용 dev DB와 실제 데이터 위치 결정. 코드의 `asia-northeast3`은 예정 API 지역이며 DB/Auth 데이터 위치 확인 증거가 아님 |
| 2 | Google Cloud → IAM 및 관리자 → 서비스 계정 | 앱 전용 `airzero-auth-…@airzero-strike-dev.iam.gserviceaccount.com`, 관리형 ADC. 키 JSON 다운로드 없이 최소 Firestore 접근/토큰 서명 권한을 검토 |
| 3 | Google Cloud → Secret Manager | `AIRZERO_EMAIL_RATE_SECRET`, `AIRZERO_SOCIAL_RATE_SECRET`, `AIRZERO_ACCOUNT_RATE_SECRET`를 서로 다른 32자 이상 임의값으로 서버에만 보관. 실제 값은 사용자 비밀번호 관리자/콘솔에서만 다룸 |
| 4 | 서버 공개 구성 | 기존 `server.dev.public.json`은 대조표다. 서버 환경의 project/dev/region/App Check app IDs·Google/Kakao 공개 값과 대조하고 `GCLOUD_PROJECT`도 같은 프로젝트인지 확인 |
| 5 | 서버 전용 추가 항목 | `AIRZERO_SERVICE_ACCOUNT`, 이메일 공식 API용 공개 `AIRZERO_FIREBASE_WEB_API_KEY`와 위 서버 secret 바인딩. 앱 define에 비밀을 넣지 않음 |
| 6 | Firestore 보안 규칙 / 최소 IAM | 개인 클라이언트 직접 접근 기본 거부. Admin 서버는 규칙만으로 보호되지 않으므로 서버 UID/객체 권한과 IAM도 검증 |
| 7 | HTTPS endpoint / App Check / 메일 정책 | 실제 기기에서 검증. 미설정을 전체 허용·임시 토큰으로 우회하지 않음 |
| 8 | 계정 삭제 유지보수 | `AccountService.maintenance()`의 비공개 실행·실패 감시·7일 최소 기록 정리/TTL을 구현/연결하고 검사. 현재 HTTP api만 export되므로 콘솔 스위치만으로 worker가 실행되지 않음 |
| 9 | 최종 준비 플래그 | 조건을 검증한 공급자만 READY 검토. 현재 모든 공급자 비활성 유지. 삭제 READY 두 항목도 실제 정리/보관/지원 경로 검증 전에는 켜지 않음 |

미완료 삭제 작업에는 TTL을 설정하지 않는다. 앱 전용 Auth 프로젝트임을 확인하기 전 UID 삭제를 허용하면 안 된다. 실제 사용자 삭제는 이번 요청의 허용 범위 밖이다. 상세 환경 계약은 [서버 README](../server/firebase/README.md)를 재사용한다.

### 이메일과 App Check에서 놓치면 안 되는 항목

[Firebase Authentication](https://console.firebase.google.com/project/airzero-strike-dev/authentication/providers)의 로그인 방법에서 이메일/비밀번호, 설정의 비밀번호 정책·사용자 액션·계정 존재 노출 방지, 템플릿의 확인/재설정 메일을 순서대로 확인한다. 앱 코드는 신규 비밀번호 최소15·최대4096 UTF-16 코드 단위·공통 비밀번호 거부와 주기/조합 강제 없음을 기준으로 한다.

서버 외 직접 가입/삭제 경로를 제한할 수 있는 `client.permissions.disabledUserSignup`/`disabledUserDeletion`과 기본 메일 handler의 정책 우회를 검증해야 한다. 콘솔에 옵션이 없으면 임의의 버튼/값을 만들거나 Identity Platform 업그레이드를 누르지 않는다. 지원 플랜/API·비용을 별도 확인하고 정책을 충족하기 전 이메일 READY를 켜지 않는다. [공식 client permissions](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v2/Config), [이메일 존재 노출 보호](https://docs.cloud.google.com/identity-platform/docs/admin/email-enumeration-protection).

메일 확인/복구 handler와 App/Universal Link는 추가 구현·설정 대기다. 현재 붙여넣기 확인을 자동 앱 복귀 완료라고 표시하지 않는다. 고정 action/continue 주소 외 임의 URL을 허용하지 않는다. 이전 [이메일 실연동 검사 목록](EMAIL-AUTH-RESULTS.md)을 따른다.

[App Check](https://console.firebase.google.com/project/airzero-strike-dev/appcheck) → 앱에서 Android Play Integrity의 해당 개발 SHA-256, iOS App Attest/DeviceCheck를 검토한다. Android는 Play 밖 개발 설치와 Play 배포의 요구 verdict가 다르다. 현재 코드의 검증을 생략하지 않고 실제 배포 방식에 맞는 공식 등록/기기 무결성을 검증한다. 디버그 토큰을 채팅·소스·로그로 공유하거나 운영 우회로를 추가하지 않는다. [Flutter App Check](https://firebase.google.com/docs/app-check/flutter/default-providers), [Play Integrity 배포 방식별 설정](https://firebase.google.com/docs/app-check/android/play-integrity-provider).

## 3. 외부 삭제 요청 페이지 — 추가 구현과 공개를 분리

[비공개 삭제 안내](pages/delete-account.md)와 `server/firebase/src/deletion-portal.ts`의 demo 초안을 재사용한다. 현재 cloud 폼은 의도적으로 비활성이다.

| 순서 | 남은 작업 | 선행 조건 |
|---|---|---|
| 1 | 실제 이메일/Google/카카오/향후 Apple 웹 본인 확인·재인증 | 승인된 개발 서버/도메인. 이메일 일치 병합 금지·동일 내부 UID 검증 |
| 2 | 웹 Firebase App ID/App Check 및 서버 웹 요청 어댑터 | 현재 서버 allowlist는 Android/iOS만 허용. 웹을 Play 구매 권한으로 취급하지 않도록 플랫폼/권한 계약 추가 필요 |
| 3 | OAuth state/nonce/PKCE·허용 callback·code 교환 | 실제 공개 HTTPS origin과 공급자 웹 설정. 모바일 Native Key/커스텀 scheme 재사용으로 대체하지 않음 |
| 4 | 최종 확인·취소·응답 유실·재시도·본인 외 접근 차단 | 기존 삭제 API와 동일 내부 계정에 연결, 토큰 URL/분석/저장소 유출 방지 |
| 5 | 개인정보/삭제 범위·보관 예외·실제 처리 기한·운영 지원 경로 | 사용자 확정. 개발자명 케일 외 임의 연락처·기간을 만들지 않음 |
| 6 | 재설치 없이 끝까지 요청 가능한 공개 HTTPS 경로 | 서버/웹 실연동 검사와 공개 승인. Cloudflare Pages 등 정적 안내만 게시해도 인증 서버가 생기지는 않음 |
| 7 | 향후 Play Console → 앱 콘텐츠 → 데이터 보안 → 삭제 URL | 실제 공개 경로가 완성된 이후 사용자가 제출. 지금 콘솔 등록/업로드/제출하지 않음 |

로컬 주소나 비활성 안내 페이지만으로 외부 삭제 요구사항 완료를 표시하지 않는다. 클라우드의 실제 삭제 검사는 빈 전용 개발 계정 범위와 별도 승인을 먼저 확인해야 하며, 이번 작업에서는 어떤 실제 계정도 삭제하지 않았다. [Google Play 공식 삭제 경로 안내](https://support.google.com/googleplay/android-developer/answer/13327111?hl=ko).

## 4. Apple — 유료 가입 없이 보류할 부분

접속: [Apple Developer 계정](https://developer.apple.com/account/). 지금은 계정 로그인·멤버십 상태 확인만 가능하며 Enrollment/구매/자동 갱신/결제 수단 등록을 하지 않는다. 무료 Personal Team의 일반 기기 테스트와 Sign in with Apple capability 검증은 구분한다. [계정/Personal Team 설명](https://developer.apple.com/help/account/basics/about-your-developer-account), [멤버십 서비스](https://developer.apple.com/programs/whats-included/), [iOS capability 목록](https://developer.apple.com/help/account/reference/supported-capabilities-ios).

기존 지원 멤버십·Mac·기기가 확보되는 경우에만 후속 절차를 검토한다:

1. Certificates, Identifiers & Profiles → Identifiers → 해당 Bundle ID를 선택한다. 동일 App ID가 있으면 새로 만들지 않는다.
2. Capabilities의 Sign in with Apple과 Team/프로비저닝을 확인한다. Team ID/App Store ID를 추측해서 입력하지 않는다.
3. Xcode Runner → Signing & Capabilities에서 같은 Team/Bundle/entitlements와 Debug/Profile/Release의 공개 콜백을 대조한다.
4. 앱 `AIRZERO_APPLE_LOGIN`과 서버 `AIRZERO_APPLE_READY`/`AIRZERO_APPLE_BUNDLE_ID`의 활성화는 서버·서명·기기 검사 이후 검토한다. **지금 두 준비 플래그는 비활성**이다.
5. 현재 native 코드는 ID token을 교환하며 Apple authorization code의 서버 교환/refresh token 철회 처리는 없다. **계정 탈퇴의 Apple revoke 연동은 추가 서버 구현**이다. 필요한 키/client secret은 서버 보관만 허용하며 실제 키 생성/다운로드는 이번에 하지 않는다. 철회 실패의 재시도·접수/완료 구분도 연결해야 한다.
6. 실제 iPhone에서 승인·취소·이메일 미제공·기존 연결·재인증·철회/재로그인을 검사한다. Apple 자체 계정을 삭제하는 작업은 아니다.

[Apple 계정 삭제/토큰 철회 기술 안내](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple). Apple 계정 로그인만 완료한 현재 상태를 앱 인증 성공으로 바꾸지 않는다.

## 5. 장비 준비와 실제 검사 순서

### Android

1. 본인 시험 휴대폰에서 개발자 옵션/USB 디버깅을 허용하고 PC에 연결한다. 기기의 USB 허용 창은 사용자가 직접 승인한다.
2. 앱 폴더 PowerShell에서 `& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices`로 device 상태를 확인한다. 기기 일련번호·계정/화면 캡처를 채팅에 보내지 않는다.
3. 일반 앱을 삭제/초기화하지 않는다. 자동 회귀는 별도 integration 앱을 사용한다. 이 integration 앱은 일반 개발 앱용 OAuth 등록을 대신하지 않는다.
4. 실제 공급자 검사는 등록된 일반 개발 앱 ID/개발 서명·공개 구성·App Check·승인된 실제 서버를 모두 준비한 뒤 사용자 소유 개발용 계정으로 한다. 그 전에는 무료 게스트 플레이/입력/설정 검사만 가능하다.

### iOS

Mac의 지원 Xcode/Flutter, 해당 Team/프로비저닝, 개발 모드/신뢰가 준비된 본인 iPhone이 필요하다. 이번 PC는 Windows이고 Xcode가 없어 iOS native 빌드·기기 설치를 수행하지 않았다. 시뮬레이터/UI 검사도 실제 App Attest/Keychain/공급자 왕복의 증거가 아니다. Mac에서 무료 게스트 테스트를 준비하더라도 현재 Apple entitlement·capability 지원 여부를 따로 검토해야 한다.

### 실제 연결 시 기록할 결과 — 지금 전부 미실행

| 기능 | 확인할 흐름 | 완료 증거 |
|---|---|---|
| 이메일 | 가입/확인/재전송/로그인/재설정/만료·재사용·잘못된 링크/옛 세션 거부 | 본인 개발용 메일·기기 왕복, 민감 링크/주소 없이 상태만 기록 |
| Google | 계정 선택/성공/취소/동의 거절/앱 복귀/잘못된 대상/만료 | Android/iOS별 실제 서버 검증과 동일 내부 계정 |
| 카카오 | 톡 설치·미설치/명시적 브라우저 재시도/취소/거절/복귀 | 실제 대상 앱/subject 검증, 게스트 원본 보존 |
| 계정 전환 | A/B·게스트 전환/재실행/만료/늦은 응답/유료 표시 | 계정별 기록·설정·선택 분리. 동일 이메일 자동 병합 없음 |
| 삭제 요청 웹 | 앱 미설치 상태 본인 확인/최종 동의/취소/재시도 | 실제 공개 경로. 실제 삭제 실행은 별도 허용 범위 확인 전 금지 |
| Apple/iOS | 서명/capability/실기기 로그인·재인증·철회·복귀 | 플랫폼 및 실제 공급자 결과. 현재 미완료 유지 |

## 로컬 준비 점검을 다시 실행하는 방법

앱 폴더에서:

```powershell
node tool/check_auth_readiness.mjs
node --test tool/check_auth_readiness.test.mjs
```

고정된 공개 JSON 3개와 공개 iOS 콜백 파일만 읽고 값은 출력하지 않는다. 임의 경로/토큰 인수, .env/비밀/CLI 계정/기기 자료 로드나 네트워크 요청은 없다. 실패 시 본문을 보여주지 않고 검사 ID/고정 사유만 반환한다. 준비 플래그를 켰다는 이유로 실연동 성공을 표시하지 않는다.

이번 실행은 로컬 대조16개·새 도구 검사6개 통과, `liveVerification=NOT_RUN`이다. 기존 Flutter107·서버14/통합33·Android2+7 결과는 이전 로컬 근거로 유지하며 앱 실행 코드를 바꾸지 않아 다시 실행하지 않았다. Node22 클라우드 런타임·실제 연결·장비가 필요한 검사는 미완료다.

10단계 결제 개발로 이동하지 않았다. commit/push·새 의존성 설치·유료 전환·배포·실제 사용자 자료 삭제도 하지 않았다.
