# 8단계 실제 로그인 설정 순서

2026-10-27 실제 연결 후속의 우선 순서와 단계별 접속/입력 항목은 [9단계 직접 설정 안내](ACCOUNT-LIVE-SETUP.md)를 따른다. 기존 등록을 재사용하며 Apple 계정 로그인만 완료·유료 멤버십 없음과 서버 무료 유지 제약을 반영했다. 아래 8단계 설명은 기존 구현의 설정 계약으로 유지한다.

2026-10-20 현재 원격 개발 등록 결과는 [SOCIAL-REMOTE-SETUP.md](SOCIAL-REMOTE-SETUP.md)를 우선한다. 사용자 승인으로 무료 Firebase 개발 프로젝트·Google 클라이언트 3개·카카오 개발 앱/플랫폼/OIDC를 등록하고 공개 설정을 준비했다. 이후 사용자가 **무료 유지**를 선택해 과금 전환/서버 배포는 하지 않는다. Apple은 마지막이며 비밀번호는 공식 사이트에 직접 입력한다. **실제 Google·카카오·Apple 로그인 연결은 아직 완료되지 않았다.** 아래는 2026-10-19 로컬 구현 후 작성한 설정 절차다. 비밀키·토큰·비밀번호·인증 링크를 채팅에 보내지 않는다. 구현과 검사 근거는 [SOCIAL-AUTH-RESULTS.md](SOCIAL-AUTH-RESULTS.md).

## 1. 기존 설정과 환경부터 확인

로컬 작업 착수 당시 소스의 공개 로그인 설정은 기본 빈 값이며 `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `server/firebase/.firebaserc`는 존재하지 않았다. 2026-10-20에는 [공개 개발 설정](../config/README.md)을 별도로 준비했다. 관리자 자격증명/비밀 환경 파일은 읽지 않았다.

1. 이 앱 전용 **개발용** Firebase 프로젝트를 준비한다. 운영은 별도 프로젝트로 분리한다. 다른 모노레포 앱의 DB·로그인 클라이언트·구매 권한을 재사용하지 않는다.
2. 기존 Android applicationId와 iOS Bundle ID `com.example.raikeopeu2026.dev`를 그대로 등록한다. 패키지 이름을 바꾸거나 앱 데이터를 지우지 않는다. 자동 검사 전용 `.integration` ID는 일반 개발 앱과 별개이며 실제 공급자 등록을 대신하지 않는다.
3. 기존 [6단계 서버 설정](../server/firebase/README.md)과 [7단계 메일 설정](EMAIL-AUTH-RESULTS.md)을 먼저 확인한다. 선택한 DB/Functions 지역은 서울 후보지만 실제 생성/위치 확인은 아직 하지 않았다. Firebase Auth 처리 위치는 Firestore 지역과 같다고 가정하지 않는다. [Firebase 개인정보 설명](https://firebase.google.com/support/privacy).
4. 새 프로젝트 생성·유료 플랜 선택·서버 배포 전 요금과 지역을 확인한다. 로컬 demo 에뮬레이터 검사는 클라우드 DB를 사용하지 않는다. 실제 Functions/Firestore/App Check/인증의 무료 한도와 과금 조건은 [Firebase 공식 요금](https://firebase.google.com/pricing)에서 확인한다. 원격 개발 프로젝트는 Spark 무료로 생성했고 과금 전환·서버 배포는 하지 않았다.

## 2. Google 등록

1. [Google Cloud Console](https://console.cloud.google.com/)에서 해당 Firebase 개발 프로젝트를 선택한다. Google Auth Platform의 Branding/Audience/Clients를 설정한다. 테스트 상태에서는 본인 개발용 계정만 테스트 사용자로 등록한다.
2. **Android OAuth 클라이언트**를 만들고 위 패키지와 실제 개발 서명 인증서 SHA-1을 등록한다. Firebase 앱 설정에는 필요한 SHA-1/SHA-256을 확인한다. debug/release/향후 Play App Signing 인증서는 각각 다르므로 한 값을 복사해 공용으로 쓰지 않는다. 개인 키·keystore 비밀번호는 공유하지 않는다.
3. 같은 프로젝트에 **Web OAuth 클라이언트**를 만든다. 이 흐름은 그 공개 Client ID를 ID token의 server audience로 사용한다. Web client secret을 모바일에 넣지 않는다.
4. iOS에서는 동일 Bundle ID의 **iOS OAuth 클라이언트**를 추가한다. Client ID와 reversed Client ID를 각각 기록한다.
5. 공개 값을 아래 설정표와 일치시킨다. Drive/Calendar 등 추가 API 권한은 요청하지 않는다. SDK가 기본 계정 정보를 반환해도 앱 서버에 이메일·이름·사진을 복사하거나 이를 계정 병합에 사용하지 않는다.

앱은 Google 네이티브 인증으로 받은 ID token만 서버에 보낸다. 서버가 서명·issuer·Web audience·허용 azp·만료·현재 요청 nonce를 검증한다. [Google 서버 검증 안내](https://developers.google.com/identity/sign-in/android/backend-auth), [Flutter Google SDK](https://pub.dev/packages/google_sign_in).

**Firebase Google provider로 직접 로그인하는 경로는 이 구현에서 사용하지 않는다.** 같은 이메일 자동 연결을 피하려고 세 공급자 모두 앱 서버 검증 → Firebase custom token 교환을 사용한다. 직접 Firebase 소셜 로그인은 개인 API에서 거부하며, 앱의 명시적 연결 절차를 우회해 provider 매핑을 만들지 않는다.

## 3. 카카오 등록

1. [Kakao Developers](https://developers.kakao.com/)에서 이 앱 전용 개발 앱을 준비하고 카카오 로그인을 활성화한다.
2. Android 플랫폼에 기존 패키지와 본인 개발 인증서의 **키 해시**를 등록한다. 이는 Google SHA-1 문자열과 같은 형식이 아니다. debug/release/실제 앱 서명별로 확인한다.
3. iOS 플랫폼에 같은 Bundle ID를 등록한다. Native App Key와 숫자 App ID를 공개 설정으로 기록한다.
4. OpenID Connect를 활성화한다. 현재 서버는 ID token과 access token을 함께 검증하므로 OIDC 미설정은 성공 처리하지 않는다. 이메일·프로필·전화번호 수집을 필수로 추가하지 않는다.
5. 콜백은 `kakao<Native App Key>://oauth`이다. Android 빌드는 공개 Dart define에서 scheme을 만든다. iOS는 Xcode의 `AIRZERO_KAKAO_SCHEME`을 같은 값으로 설정한다. REST/Web 방식의 임의 redirect URL이나 다른 앱의 Native Key를 넣지 않는다.
6. 설치된 카카오톡은 공식 SDK로 열고, 미설치면 카카오계정 브라우저 인증을 사용한다. 취소·거절 후 자동으로 두 번째 창을 열지 않는다. 계정 화면의 **카카오계정으로 로그인 · 브라우저**로 사용자가 직접 재시도한다.

현재 SDK v2의 Android 수신 Activity와 iOS Scene callback은 소스에 연결했다. 최소 카카오톡 조회만 허용하며 전체 설치 앱 조회는 추가하지 않았다. 서버는 opaque access token을 JWT로 해석하지 않고 카카오 공식 token-info에서 대상 앱/사용자/남은 수명을 확인한다. [공식 Flutter 설정/흐름](https://developers.kakao.com/docs/en/kakaologin/flutter), [OIDC 검증](https://developers.kakao.com/docs/en/kakaologin/utilize).

## 4. iOS Apple 등록 — Mac에서 진행

1. [Apple Developer](https://developer.apple.com/account/)의 해당 App ID에 **Sign in with Apple** capability를 활성화한다. 기존 Bundle ID를 유지한다.
2. Mac의 Xcode에서 Runner Signing & Capabilities와 본인 Team/provisioning을 확인한다. 코드에는 `Runner.entitlements`와 세 빌드 구성의 entitlement 참조를 준비했다. 개발자 계정/서명/프로비저닝을 생성하거나 변경하지 않았다.
3. 공개 Dart define `AIRZERO_APPLE_LOGIN=true`와 서버 Bundle ID를 일치시킨 뒤 **실제 iPhone**에서 검사한다. Android에는 Apple 웹 인증을 추가하지 않았다.
4. 이 구현은 native AuthenticationServices ID token + state/hashed nonce를 검증한다. 현재 웹 Service ID·Apple private key·클라이언트 secret·서버 authorization-code 교환을 사용하지 않는다. Apple authorization code를 세션으로 받아들이거나 저장하지 않는다. 공급자 권한 철회/계정 삭제 연동은 이후 단계에서 별도 구현해야 한다.

이 일반 게임이 제3자 기본 계정 로그인을 제공하므로 현재 [App Review 4.8](https://developer.apple.com/app-store/review/guidelines/#login-services)에 맞는 선택지를 제공하기 위해 Apple 로그인을 포함했다. 적용 예외/최종 심사 결과는 실제 제출 시 재확인한다. [Apple 로그인 API](https://developer.apple.com/documentation/authenticationservices/implementing-user-authentication-with-sign-in-with-apple). Flutter는 `sign_in_with_apple` 브리지로 공식 native API를 호출하며 Apple이 발행한 Flutter SDK라고 표시하지 않는다.

## 5. 공개 설정과 서버 비밀을 분리

### 모바일 공개 설정

| 설정 | 입력할 값 |
|---|---|
| AIRZERO_FIREBASE_PROJECT / API_KEY / APP_ID / SENDER_ID | 위 개발 프로젝트의 플랫폼별 공개 Firebase client config |
| AIRZERO_ENVIRONMENT / AIRZERO_REGION | dev / 실제 선택 지역 |
| AIRZERO_GOOGLE_WEB_CLIENT_ID | 위 Web Client ID, Android/iOS 공통 server audience |
| AIRZERO_GOOGLE_IOS_CLIENT_ID | 해당 iOS Client ID, Android에서 불필요 |
| AIRZERO_KAKAO_NATIVE_KEY | 해당 앱 Native App Key, 관리자 키 아님 |
| AIRZERO_APPLE_LOGIN | iOS 설정 완료 후 true |

Firebase 키 이름 전체는 `AIRZERO_FIREBASE_API_KEY`, `AIRZERO_FIREBASE_APP_ID`, `AIRZERO_FIREBASE_SENDER_ID`다. 이 공개 값은 서버 관리자 권한을 주지 않으며 HTTPS/App Check/서버 UID 검증을 대체하지 않는다.

사용자가 저장소 밖에 **공개 값만** 들어 있는 JSON 파일을 준비한 뒤 `flutter run --dart-define-from-file=<그 파일의 절대 경로>`로 실행할 수 있다. 비밀번호·토큰·client secret·서비스 계정 JSON·서명 키를 이 파일에 섞지 않는다. 릴리즈용 값은 개발용과 별개로 검토하며 이번 단계에서 릴리즈 빌드/배포하지 않는다.

iOS Xcode의 Runner Build Settings에서 다음 공개 값도 설정한다. `ios/Flutter/AuthPublic.xcconfig`의 기본값은 미설정 표시용이다. Debug/Profile/Release 모두 대상 앱과 일치시켜야 한다.

| Xcode 설정 | 값 |
|---|---|
| AIRZERO_KAKAO_SCHEME | kakao + Native App Key |
| AIRZERO_GOOGLE_REVERSED_CLIENT_ID | iOS OAuth client의 reversed Client ID |

### 서버 전용 설정

기존 서버 환경 설정에 아래 **공개 설정**을 추가한다. 실제 콘솔·앱·콜백·App Check 검증 전에는 READY를 켜지 않는다. 플래그가 외부 설정을 자동 검사하거나 적용하지 않는다.

| 설정 | 의미 |
|---|---|
| AIRZERO_GOOGLE_READY | 준비를 직접 확인한 뒤 true |
| AIRZERO_GOOGLE_WEB_CLIENT_ID | 모바일의 server audience와 동일 |
| AIRZERO_GOOGLE_ANDROID_CLIENT_IDS | 허용할 Android OAuth client ID, 쉼표 구분 |
| AIRZERO_GOOGLE_IOS_CLIENT_IDS | 허용할 iOS OAuth client ID, 쉼표 구분 |
| AIRZERO_KAKAO_READY / NATIVE_KEY / APP_ID | 각각 AIRZERO_KAKAO_READY, AIRZERO_KAKAO_NATIVE_KEY, AIRZERO_KAKAO_APP_ID |
| AIRZERO_APPLE_READY / BUNDLE_ID | 각각 AIRZERO_APPLE_READY, AIRZERO_APPLE_BUNDLE_ID |

`AIRZERO_SOCIAL_RATE_SECRET`은 **서버 전용 32자 이상 HMAC 비밀**이다. 본인 비밀번호 관리자로 임의 값을 생성해 해당 개발 프로젝트의 Google Cloud Secret Manager에 직접 입력하고 Functions secret으로 바인딩한다. 이메일용 `AIRZERO_EMAIL_RATE_SECRET`과 분리한다. 앱/저장소/명령 인수/문서/로그/채팅에 값을 적지 않는다. 서비스 계정은 키 파일 다운로드 대신 관리형 ADC/IAM을 사용하고 custom token 서명을 위한 해당 서비스 계정의 최소 signBlob 권한을 확인한다. 실제 IAM/Secret/Functions/Firestore 규칙 적용은 아직 하지 않았다.

네이티브 Firebase SDK가 앱 인증을 유지하고, 앱 서버 핸들은 기존 OS 보호 저장소를 쓴다. 공급자 원본 ID/access/refresh token은 앱 자체 파일에 저장하지 않는다. 카카오 TokenManager는 RAM만 사용하고 교환 종료 시 비운다. Google 계정 선택 상태 정리와 앱 로그아웃은 연결했지만 공급자 전체 동의 철회/삭제를 의미하지 않는다.

## 6. 설정 후 본인 개발용 계정으로 확인

1. Android Google/카카오, iOS Google/카카오/Apple 각각: 성공 → 열었던 설정 화면 복귀 → 로그아웃 → 다시 로그인. 이메일 추가 가입을 강제하지 않는지 확인한다.
2. 취소·동의 거절·오프라인·카카오톡 미설치·브라우저 직접 재시도를 확인한다. 모든 경우 기기 기록/설정을 보존해야 한다.
3. 기존 이메일 계정 로그인 → 계정 → **기존 이메일 계정에 소셜 로그인 연결** → 동의 → 현재 **이메일 비밀번호** 재확인 → 공급자 인증. 다른 계정에 연결된 공급자는 충돌 안내와 두 원본 보존을 확인한다. 소셜 비밀번호는 앱에 입력하지 않는다.
4. 잘못된 OAuth client/서명/Bundle ID/콜백, 만료/다른 nonce·state, 로그아웃 중 늦은 응답을 개발 환경에서 확인한다. 실제 토큰을 복사해 채팅/로그에 남기지 않는다.
5. 실제 App Check·Firebase revocation·서비스 IAM·DB 규칙을 별도로 확인한다. 이메일 가입/확인/재설정의 이전 검증도 반복한다. 정상 공급자 로그인만으로 유료 기능이 풀리면 안 된다.

현재 서버 소셜 인증 grant는 1시간이며 Firebase SDK의 token refresh가 이 시간을 늘리지 않는다. 만료되면 새 공급자 인증이 필요하다. 자동 반복 팝업을 띄우지 않고 사용자 재시도를 기다린다. 장기 무중단 로그인 정책·공급자 철회 알림·탈퇴/자료 정리는 후속 단계다. Windows에서 iOS 빌드/실제 OS 인증은 검증하지 못했다.

로컬 재현은 [서버 README](../server/firebase/README.md)의 안전한 demo runner만 사용한다. 실제 SDK 호출·메일 전달·실기기 복귀·운영 설정 검증을 로컬 합성 토큰 검사와 같은 완료로 표시하지 않는다.
