# AIRZERO STRIKE 인증 기반 서버

## 10단계 구독 검증 — 로컬 첫 단위

월간/연간 동일 혜택 구독의 서버 검증을 기존 UID·앱 세션·App Check에 연결했다. 최신 구현·검사는 [결제 결과](../../docs/BILLING-RESULTS.md), 공식 스토어·서버 설정 순서는 [결제 준비](../../docs/BILLING-SETUP.md)를 따른다. 상품 ID와 가격은 미정이며 기본 `AIRZERO_BILLING_READY=false`로 구매·검증을 거부한다. 기존 로컬 완료 플래그만으로 유료 권한을 부여하지 않는다.

Google subscriptionsv2 및 Apple 공식 App Store Server Library를 분리 사용한다. 암호화 원장·스토어별 계정 연결값·거래군 임대로 중복/소유권을 검증하고, 제공 기록 후 acknowledge/거래 완료를 처리한다. Google RTDN·Apple V2 및 별도 OIDC 유지보수 API는 공식 현재 상태를 재조회한다. 현재 서버 Secret·IAM·알림·worker·TTL/보관 정책은 실제 적용하지 않았다. 앱 종료 직후 첫 거래는 사전에 서버에서 발급한 계정 연결값으로만 귀속하며, 다른 계정·스토어로 자동 이전하지 않는다.

`npm.cmd test`에 결제 구성/검증 단위를, `test:emulator`에 가상 A/B·중복·대기·ack 재시도·알림 역순·탈퇴·소유권·요청 제한 검사를 포함했다. 이 검사에 사용한 가상 스토어 verifier는 test 파일에만 있으며 Play/Sandbox 성공 증거가 아니다. 실제 스토어 구매·환불/해지 쓰기 API·과금 전환·서버 배포는 실행하지 않는다. 9단계 실제 연결 미완료 목록은 아래와 같이 유지한다.

## 9단계 계정 관리·탈퇴

현재 결과는 [계정 관리 검증](../../docs/ACCOUNT-MANAGEMENT-RESULTS.md)을 우선한다. 기존 UID/앱 세션을 재사용하며 이메일 일치로 계정을 합치지 않는다. 소셜 `intent=reauth`는 이미 연결된 동일 subject만 허용하고 새 연결/계정을 만들지 않는다.

| 경로 | 역할과 권한 |
|---|---|
| `GET /v1/me/account` | 유효한 SDK 토큰·앱 세션으로 본인 UID/세대/연결 공급자만 조회 |
| `GET /v1/public/account-policy` | 삭제 준비 상태·고정 안내 버전. 개인 정보 없음 |
| `POST /v1/account/deletion/prepare` | 최근 재인증·본인 세션·확인값 검증. 5분 준비만 하며 삭제하지 않음 |
| `POST /v1/account/deletion/commit` | 같은 소유자/세션·확인값·명시적 최종 동의·안내 버전. 접근 차단 후 정리 |
| `POST /v1/account/deletion/resume` | 이미 최종 동의한 삭제의 확인값만으로 완료/재시도. 개인 조회·새 탈퇴 권한 아님 |
| `GET /account-deletion` | demo 가상 이메일 웹 초안. 운영 자격증명 폼은 비활성 |

확인값은 앱 OS 보호 저장소에만 보관하고 서버 문서 ID에는 SHA256만 둔다. `deletionJobs`의 임대와 `AccountService.maintenance()`로 정리를 재시도한다. 미완료 작업에는 TTL을 두지 않는다. 완료 확인값/접근 차단 해시의 7일 보관·준비 5분 만료는 논리 검증이며 실제 TTL/정리 worker는 **미배포**다. worker는 공개 HTTP 작업 실행 경로로 노출하지 않는다.

cloud의 `AIRZERO_ACCOUNT_DELETION_READY=true`, `AIRZERO_ACCOUNT_CLEANUP_READY=true`, 32자 이상 `AIRZERO_ACCOUNT_RATE_SECRET`이 모두 없으면 삭제는 거부한다. Secret은 서버 전용이며 앱 define/문서에 값을 넣지 않는다. READY는 자동 검사기가 아니다. 전용 Firebase Auth 프로젝트가 다른 앱의 계정을 공유하지 않는지, 최소 IAM·App Check·worker/감시·실제 정리 기간·지원 경로를 검증하기 전에 켜지 않는다. 다른 앱과 Auth 프로젝트를 공유하면 UID 자체 삭제가 다른 앱 인증에도 영향을 줄 수 있으므로 현재 삭제 구조를 사용하면 안 된다.

이번 단계는 무료 demo 검사다. 실제 사용자/운영 자료 삭제·규칙 배포·유료 요금제 전환·공급자 자체 계정 삭제/구독 취소를 실행하지 않는다. 외부 웹은 실제 이메일/소셜 인증과 웹 전용 App Check/삭제 요청 어댑터의 추가 구현이 필요하다. 현재 서버 App Check 허용 목록은 Android/iOS 앱만 받는다. HTTPS 공개·허용 도메인·운영 설정과 실연동 검증도 대기이며 로컬 웹 초안 주소를 스토어 공개 URL로 제출하지 않는다.

2026-10-20 현재 승인된 무료 개발 등록과 공개 설정은 [원격 설정 결과](../../docs/SOCIAL-REMOTE-SETUP.md)를 우선한다. Firebase Spark·Google 클라이언트 3개·카카오 앱/플랫폼/OIDC를 준비했지만, 사용자가 무료 유지를 선택했으므로 Blaze/결제 계정·Functions·Firestore/IAM/규칙/Secret/App Check 실제 적용은 하지 않았다. 공개 설정 대조표의 READY는 false다. 아래 ‘등록하지 않음’은 로컬 구현 시점의 이력이며 실제 로그인 완료를 뜻하지 않는다.

8단계는 기존 서버에 공급자별 공식 proof 검증·challenge/nonce/state·UID 매핑·소셜 grant와 custom token 발급을 추가했다. 이메일과 개인 API는 재사용한다. 결과는 [SOCIAL-AUTH-RESULTS.md](../../docs/SOCIAL-AUTH-RESULTS.md), 서버 공개 설정/전용 비밀·사용자 콘솔 순서는 [SOCIAL-SETUP.md](../../docs/SOCIAL-SETUP.md)를 우선한다. 실제 앱 등록/클라우드 배포/운영 적용은 하지 않았다.

`GET /v1/public/social-policy`, `POST /v1/social/begin`, `POST /v1/social/complete`를 추가했다. 기본 설정에서는 활성 공급자가 없고 로그인은 503으로 거부한다. cloud에서는 세 공급자의 공개 allowlist 설정과 `AIRZERO_SOCIAL_RATE_SECRET` 32자 이상 서버 Secret이 필요하다. 운영 fake proof/test user 환경 변수나 테스트 JWKS URL은 없다. 테스트용 키 주입은 test 코드에서만 한다. 서버가 발급한 Firebase custom token은 SDK 교환용이며 공급자 token/custom token 원문으로 개인 API에 접근하지 못한다.

`npm.cmd test`는 기존 권한 단위 검사와 합성 서명 검사, `test:emulator`는 기존 이메일/접근 통제와 소셜 검사를 함께 실행한다. 두 native 명령은 하나씩 실행한다. 최초 nonce/소유권/최근 재인증·동시 최초 로그인·충돌/철회를 로컬에서 확인하되 실제 공급자 통신/OS 로그인 완료와 구분한다.

6단계 TypeScript/Firebase Admin 기반에 7단계 이메일 흐름을 추가했다. 기존 Flutter 계정 화면과 공식 SDK로 로컬 연결하며 무료 게스트 기록·앱 ID·협동 서버와 분리한다. 최신 검증/미적용 항목은 [EMAIL-AUTH-RESULTS.md](../../docs/EMAIL-AUTH-RESULTS.md), 기존 접근 통제 근거는 [AUTH-BACKEND-RESULTS.md](../../docs/AUTH-BACKEND-RESULTS.md)를 따른다. 운영 프로젝트는 만들거나 배포하지 않았다.

## 로컬 검사

PowerShell에서 이 폴더를 작업 경로로 사용한다. 공식 Node 22/24·npm·Java 21 이상이 필요하다. 이번 검사는 Node 24.21.0/npm 11.19.0/Android Studio JBR 25.0.3을 사용했다. 운영 대상 런타임은 nodejs22이며 해당 런타임/클라우드 검증은 별도다.

```powershell
npm.cmd ci --ignore-scripts --no-fund --no-audit
npm.cmd run build
npm.cmd test
npm.cmd run test:emulator
npm.cmd run test:native-email
npm.cmd run test:native-core
npm.cmd run test:native-persistence
```

`test:native-persistence`는 `.integration` 패키지의 가상 기록/설정 fixture를 저장한 뒤 다른 테스트 define의 debug APK를 `--no-uninstall`로 교체·재실행해 확인한다. 실제 버전 상승/정식 서명/스토어 업데이트 검사는 아니다. 네이티브 runner는 Flutter의 기본 pub/플러그인 재생성을 유지한다. 현재 Flutter SDK에서는 release↔통합 검사 전환 때 `--no-pub`가 생성 registrant를 이전 모드에 남겨 빌드/채널 오류를 일으킬 수 있으므로 생성 파일을 손으로 수정하지 않는다.

`test:emulator`는 로그인된 Firebase CLI를 재사용하지 않는다. 필요한 OS 실행 변수만 전달하고, 앱 전용 빈 CLI 설정/캐시·메타데이터 탐색 차단·고정 `demo-airzero-strike`·loopback 포트만 사용한다. 공식 에뮬레이터 JAR는 최초 실행 때 내려받는다. 실제 프로젝트·계정·서비스 키는 불필요하다. 에뮬레이터 UI/가져오기/내보내기·배포 스크립트는 없다. 테스트 데이터는 가상 `example.test` 사용자이며 프로세스 종료 시 DB가 사라진다.

| 대상 | 주소 |
|---|---|
| Auth | 127.0.0.1:9299 |
| Firestore | 127.0.0.1:8280 |
| Functions | 127.0.0.1:5101 |
| API | /demo-airzero-strike/asia-northeast3/api/v1/... |

## 운영 전 필수 설정 — 현재 미적용

실제 dev/prod는 이 앱 전용의 서로 다른 Firebase 프로젝트가 필요하다. 설정이 빠지면 Admin 초기화 전에 시작을 거부한다. `.firebaserc`·서비스 계정 키·실제 환경 파일은 만들지 않았다.

| 서버 설정 | 의미 |
|---|---|
| AIRZERO_PROJECT_ID | 플랫폼 GCLOUD_PROJECT와 같은 airzero-strike- 접두사 프로젝트 |
| AIRZERO_ENVIRONMENT | dev 또는 prod |
| AIRZERO_REGION | 사용자가 선택한 지원 Functions 지역 |
| AIRZERO_FIREBASE_APP_IDS | 허용된 Firebase Android/iOS app ID, 쉼표 구분. package/이메일이 아님 |
| AIRZERO_SERVICE_ACCOUNT | 같은 프로젝트의 airzero-auth- 접두사 전용 서비스 계정. 실제 최소 IAM은 사용자 설정·검증 필요 |
| AIRZERO_FIREBASE_WEB_API_KEY | 이메일 공식 REST API용 공개 Firebase client key, 관리자 비밀 아님 |
| AIRZERO_EMAIL_RATE_SECRET | 32자 이상 HMAC 비밀. cloud Secret Manager에서만 바인딩 |
| AIRZERO_EMAIL_SECURITY_READY | 이메일 외부 보안 설정을 실제 확인한 뒤에만 true. 기본 미설정/거부 |

관리형 ADC/IAM을 사용한다. 관리자 키를 Dart define·assets·저장소·로그에 넣지 않는다. cloud 모드에서는 Auth/DB/Storage 에뮬레이터 변수를 거부한다. 서명 없는 토큰/테스트 사용자를 허용하는 운영 분기는 없다.

`firebase.json`은 dev 공개 카탈로그 규칙과 로컬 포트, `firebase.prod.json`은 prod 공개 카탈로그 규칙만 지정한다. 두 규칙 모두 개인 데이터의 직접 접근을 전부 거부한다. 운영 규칙 적용·IAM·HTTPS 경로·App Check 허용 앱 검증은 미실행이다. 로컬 `.runtime`, 로그, 테스트·도구·환경 파일은 Functions 업로드 목록에서도 제외했다.

인증된 API는 `Authorization: Bearer <Firebase SDK ID token>`과 `X-Airzero-Session`을 요구한다. 시작 요청만 앱 세션 핸들이 없다. cloud에서는 검증 가능한 `X-Firebase-AppCheck`도 필수다. 이메일/UID 헤더나 공급자 원본 토큰은 세션이 아니다. 토큰을 셸 인수/URL/로그에 넣지 않는다.

Firebase CLI 전이 의존성의 알려진 감사 항목은 결과 문서에 남아 있다. `npm audit fix --force`·임의 override로 숨기지 않는다. CLI는 서버 운영 의존성이 아니며 로컬 고정 입력/loopback 검사에만 사용한다.

## 이메일 로컬 시험과 외부 설정

`npm.cmd run dev:emulator`를 실행하고 루트 VS Code의 **AIRZERO STRIKE · 이메일 로컬 시험**을 사용한다. 가상 `example.test` 계정만 쓰며 실제 메일은 발송되지 않는다. Android 앱은 10.0.2.2의 고정 포트로 접속하고 테스트 runner는 일반 앱과 분리된 `.integration` ID를 사용한다. 코드/메일 링크를 로그나 문서로 출력하지 않는다.

운영 모바일에는 공개 Dart define `AIRZERO_FIREBASE_PROJECT`, `AIRZERO_FIREBASE_API_KEY`, `AIRZERO_FIREBASE_APP_ID`, `AIRZERO_FIREBASE_SENDER_ID`, `AIRZERO_ENVIRONMENT`, `AIRZERO_REGION`만 사용한다. 관리자 키/메일 HMAC 비밀은 앱 define에 넣지 않는다. 구성 누락 시 초기화를 거부하며 기본 무료 플레이는 유지한다.

`AIRZERO_EMAIL_SECURITY_READY`는 자동 점검기가 아니다. 실제 Firebase의 이메일 provider/비밀번호 정책/클라이언트 직접 가입 제한/이메일 enumeration 보호·App Check·자동 공격 방어·메일/복귀 handler 보안을 먼저 확인해야 한다. 기본 Firebase 웹 재설정 handler와 직접 provider API가 앱 서버의 추가 정책을 우회하지 않는지도 검증한다. 운영 readiness는 현재 미설정이고 클라우드에 적용하지 않았다. 구체 절차와 Auth Emulator에서 재현되지 않는 링크 만료 검증은 [7단계 결과](../../docs/EMAIL-AUTH-RESULTS.md)에 있다.
