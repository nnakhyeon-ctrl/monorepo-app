# 6단계 인증 백엔드·데이터 접근 통제 결과

2026-10-19, AIRZERO STRIKE 한 앱에 적용했다. 기존 3단계 선택인 Firebase Auth·Functions·Firestore를 사용한다. 기존에는 Dart 정책 모델만 있었고 실행 가능한 Firebase 서버/규칙이 없어서 `server/firebase`에 앱 전용 서버를 추가했다. 앱의 무료 로컬 플레이·기록·앱 ID·그래픽·구독 방식은 유지했다. **로컬 구현/검증 완료와 실제 클라우드 적용은 다르다. 실제 프로젝트 생성·운영 DB 변경·가입·유료 플랜·배포는 하지 않았다.**

## 구현된 인증과 권한

- Admin SDK의 `verifyIdToken(token, true)`로 서명/발급자/대상 프로젝트/만료/철회·비활성 여부를 검사한다. 서버가 확인한 Firebase UID만 경로에 사용한다. 이메일·클라이언트 UID·가격·premium 값은 권한이 아니다.
- cloud 모드의 모든 개인 API에 검증된 App Check 및 이 앱 전용 Android/iOS app ID 허용 목록을 요구한다. 스토어 구분도 이 증명의 app ID에서 정하며 클라이언트 store 문자열을 신뢰하지 않는다. 실제 Play Integrity/App Attest 설정·검증은 대기다. [공식 검증 방식](https://firebase.google.com/docs/app-check/custom-resource-backend).
- 계정 status/generation과 SHA-256 해시로 보관한 랜덤 256비트 앱 세션 핸들을 매 요청 검사한다. 핸들은 최대 1시간이면서 ID token 만료를 넘지 않는다. 토큰 서명만 확인하고 삭제/철회를 무시하지 않는다.
- 내부 UID와 공급자 고유 ID 매핑은 서버 전용이다. password는 이메일 대신 Firebase UID, Google/Apple은 Admin이 반환한 provider UID를 사용한다. 다른 UID에 이미 귀속된 매핑은 409로 거부하며 자동 재배정하지 않는다.
- 이메일 미확인 계정은 개인 API 진입을 거부한다. 무료 게스트는 Auth 익명 계정도 만들지 않고 기기에서 그대로 플레이한다. Firebase Google/Apple 세션 검증 경계는 있지만 실제 로그인/연결 화면·SDK는 미연결이다.
- Google ID token·Apple ID token·Kakao OIDC proof 타입과 검증 인터페이스를 Firebase 세션과 분리했다. 원본 공급자 proof 처리기는 현재 501 거부만 하며 JWKS/nonce/code 교환·Kakao custom token 발급을 구현 완료로 표시하지 않는다. Firebase custom token을 API의 ID token으로 받지 않는다. [공식 ID token 검증](https://firebase.google.com/docs/auth/admin/verify-id-tokens).

모든 개인 자료는 `apps/airzero-strike/environments/{dev|prod}` 아래에 둔다. 실제 dev/prod는 별도 프로젝트, 다른 앱도 별도 프로젝트/IAM으로 준비해야 한다. 이번 로컬 fixture에서 다른 앱/환경 경로의 직접 접근 거부를 확인했다. Admin SDK는 규칙을 우회하므로 전용 서비스 계정/IAM과 API 소유권 검증이 함께 필요하다. [Rules와 서버 라이브러리 경계](https://firebase.google.com/docs/firestore/security/rules-conditions).

| 경로/작업 | 허용 | 기본 거부 |
|---|---|---|
| public/catalog | schema 1·published·허용 스테이지/무료 ID만 고정 문서 GET | 목록 검색·쓰기·개인 필드가 섞인 공개 문서 |
| accounts/{uid}/private/progress | 본인 API GET·동의한 빈 계정 최초 가져오기 | 직접 DB 읽기/쓰기/삭제·타 UID·전체 덮어쓰기 |
| accounts/{uid}/private/preferences | 본인 API GET/PUT/DELETE(기본값 복구), revision/generation/중복키 검사 | 타인·미인증·만료·임의 필드·유료 권한 필드 |
| private/entitlement_{store} | 본인 API에서 서버 검증 상태의 최소 결과만 조회 | 모든 클라이언트 직접 접근/변경·권한 부여 API |
| providers, sessions, operations, 계정 상태 | 검증된 서버 트랜잭션 전용 | 클라이언트 직접 조회/수정/삭제·다른 앱/환경 |
| 그 밖의 경로/메서드 | 없음 | 기본 거부. 계정/게임 삭제·가격·재화·보상 API도 없음 |

직접 Firestore 조회는 본인도 막는다. API를 거쳐야 실시간 철회/계정 상태와 세션을 함께 검사할 수 있기 때문이다. dev/prod 규칙 코드를 각각 작성하고 실제 로컬 Firestore 에뮬레이터에 컴파일·적용해 검사했다. 운영 프로젝트에 적용한 결과는 없다.

## 게스트 기록과 개인 설정

최초 가져오기는 `import-preview` → 최근 5분 이내 인증 → 명시적 confirmed → expectedRevision/generation/operationId를 포함하는 트랜잭션이다. 빈 계정만 받는다. 이미 가져온 기록 또는 기존 클리어/최고점수 자료가 있으면 양쪽 보존 충돌을 반환한다. 같은 키·같은 요청은 멱등 응답, 다른 요청은 거부하며 같은 UID 두 세션의 동시 가져오기 중 하나만 성공한다. generation이 다른 오래된 자료도 쓰지 못한다.

허용 입력은 15탄 이내 스테이지/클리어/최고점수/시도 수뿐이다. 다음 탄은 연속 클리어에서 서버가 계산한다. 상한·형식·진행 순서를 검증하되 오프라인 점수를 서버가 실제 공략으로 증명한 것은 아니므로 `guest-import`/`offline-unverified`를 기록한다. 보상·재화·순위·유료 소유권을 지급하지 않는다. 앱의 게스트 파일 삭제/자동 업로드·계정 기록 자동 합산은 연결하지 않았다.

개인 설정 DTO는 기존 감도 .75/1/1.25·음악/효과음/진동·효과 완화·음량만 받는다. API의 개인 설정은 향후 명시적 선택 시 사용할 계정 사본이며 현재 기기 설정을 자동 동기화하지 않는다. 일반 게임 결과/성장 저장, 쓰기 세션 인계, 두 휴대폰 동기화 UI·대기열 전송은 후속 범위다. 이번 단계는 최초 가져오기와 소유권/CAS 기반을 완성한다.

## 유료 권한 경계

클라이언트의 paid/owned/verified 필드·DB 직접 쓰기·API PUT으로 유료 콘텐츠를 해금할 수 없다. 서버 전용 자료도 앱·환경·UID·스토어·검증 출처·유효기간·active/canceled/grace 상태가 맞아야 최소 이용권을 반환한다. 취소 후 남은 유효기간과 만료/철회를 구분한다. 다른 앱·UID·환경·스토어 자료는 미확인으로 처리한다.

검사에서 사용한 entitlement는 테스트 Admin이 쓴 가상 자료다. **Play/App Store 영수증 검증기·구매 원장 쓰기·알림·실결제/복원은 구현하지 않았다.** 운영 기본 Flutter 이용권 저장소는 계속 미확인이고 이번 서버의 가상 자료가 앱 유료 기능을 열지 않는다. 10단계 공식 검증기가 준비되기 전 권한 쓰기 경로를 추가하지 않는다.

## 전송·저장·비밀·로그

운영 API는 HTTPS만 받으며 query/UID 경로·알 수 없는 필드·32KiB 초과 본문·잘못된 JSON 타입을 거부한다. private 응답은 no-store, 오류는 고정 코드와 requestId만 반환한다. 앱 관리 로그에는 코드/상태만 기록하고 토큰·이메일·UID·입력/오류 객체는 기록하지 않는다. 공급자/플랫폼 자체 IP·요청 메타데이터 로그의 운영 보관은 별도 확인이 필요하다.

`lib/security/backend_session.dart`에 native 보호 저장소를 추가했다. 앱/프로젝트/dev-prod별 키에 불투명 앱 세션 핸들·UID·만료·generation만 저장한다. Firebase 비밀번호/refresh token·구매 권한·게임 파일은 저장하지 않는다. Android Keystore 암호화 저장과 iOS의 이 기기 잠금 해제 시 Keychain 옵션을 사용하며 동기화/백업 이전·오류 시 평문 대체를 허용하지 않는다. 웹 저장 구현은 거부한다. 로그아웃 중 지연 쓰기가 세션을 되살리지 않으며 저장소 오류는 가린 오류로 실패한다.

Firebase SDK 세션 유지/갱신 adapter는 이후 이메일/소셜 단계에서 연결할 인터페이스만 있다. 앱 세션 만료 시 fresh ID token으로 다시 시작해야 한다. 서버 로그아웃은 현재 앱 세션을 닫고 기존 ID token으로 재시작하는 것을 막는다. 다른 기기의 기존 세션까지 전역 로그아웃하지는 않는다. 앱 UI/SDK signOut/계정 전환에 실제 연결하는 단계와 구분한다.

cloud 구성은 프로젝트·dev/prod·지역·허용 Firebase app ID·동일 프로젝트의 전용 service account가 모두 있어야 시작한다. 관리자 키 파일을 만들지 않았고 관리형 ADC/IAM만 사용하도록 구성했다. 실제 IAM 역할은 미적용이다. 로컬은 정확한 demo 프로젝트와 loopback Auth/DB 주소만 허용한다. 서명 없는 에뮬레이터 token이 운영으로 들어갈 환경 변수를 cloud에서 거부한다. [에뮬레이터의 토큰 제한](https://firebase.google.com/docs/emulator-suite/connect_auth).

첫 CLI 검사에서 도구가 상속한 DEBUG 값 때문에 환경을 자동 상세 출력하는 문제가 발생해 중단했다. 실행기를 필요한 OS 변수만 전달하도록 고쳤고 사용자 CLI/클라우드 설정·자격증명을 물려주지 않는다. 원본 상세 로그를 검토/외부 전달하지 않고 이번 작업에서 생성한 로컬 debug 로그를 삭제했다. `.runtime`·로그·테스트·환경 파일은 Git 및 Functions 업로드에서도 제외했다.

## 공식 구성·비용·데이터 위치

| 구분 | 현재 구성과 상태 |
|---|---|
| 로컬 | demo-airzero-strike, Windows loopback Auth/Firestore/Functions. 실제 클라우드 사용료·계정 가입 없음. 로컬 디스크/네트워크 다운로드 사용 |
| 실제 dev/prod | 서로 다른 앱 전용 프로젝트·App Check 앱·서비스 계정 필요. 프로젝트/DB/과금/IAM 생성·변경·규칙 배포 모두 미실행 |
| DB/Functions 지역 | Seoul asia-northeast3는 지원 지역 후보이자 로컬 함수 경로. 사용자 실제 선택 아님. DB 생성 전 위치 확정 필요. [Firestore 위치](https://firebase.google.com/docs/firestore/locations), [Functions 지역](https://firebase.google.com/docs/functions/locations) |
| 인증 데이터 | Firebase Auth는 공식 문서상 미국 데이터센터에서 처리한다. DB를 서울로 선택해도 모든 인증 자료가 국내에 머무는 구성이 아니다. App Check/공급자 처리도 별도 고지 필요. [공식 데이터 위치](https://firebase.google.com/support/privacy) |
| 비용 | Functions 운영에는 Blaze 준비가 필요하다. 무료 포함량이 있어도 호출/CPU/메모리·DB 읽기/쓰기/저장·네트워크·로그·빌드/이미지·비밀 보관에 따라 과금된다. 일반 Auth와 Identity Platform의 요금/쿼터도 다르다. 실제 예산·플랜 활성화 없음. [공식 가격](https://firebase.google.com/pricing), [Firestore 과금](https://firebase.google.com/docs/firestore/pricing) |

minInstances=0/maxInstances=3/30초/256MiB는 서버 코드의 초기 제한이며 비용 상한 보장은 아니다. 사용자별 호출/세션 생성 쿼터·남용 방어·예산 알림·관측은 운영 전 결정/검증해야 한다. 매 프레임 업로드·분석/광고 SDK는 추가하지 않았다.

세션은 접근 만료만 구현했고 만료 세션 문서의 정리/TTL 배포는 하지 않았다. operation receipt는 중복 안전성을 위해 보존하며 삭제 기간·재연 방지 high-water mark를 확정하기 전 임의 삭제하지 않는다. provider 매핑·삭제 tombstone/generation·계정 하위 문서의 실제 삭제 작업/보관 근거·백업 복구 정책도 9단계/운영 준비에서 확정해야 한다. 이 상태를 출시용 보관/삭제 완료로 표시하지 않는다.

## 검사 결과

| 검사 | 결과/실제 범위 |
|---|---|
| TypeScript build·서버 단위 8개 | 통과. 환경 기본 거부·SDK 철회 호출·issuer/aud/exp·App Check 경계·upstream 미연결·입력 검증 |
| Auth/Firestore/Functions 통합 12개 묶음 | 통과. 가상 A/B 실제 로컬 ID token으로 HTTP API와 Firestore REST 규칙 검사. 본인/타인·직접 CRUD/list/batch·미인증/만료 조회/수정/삭제·동의/중복/동시 충돌·기존 기록 보존·유료 권한 변조·철회/비활성/삭제/만료·provider 충돌·로그아웃·prod 규칙 로컬 적용 |
| Flutter 호스트 73개 | 통과. 기존 67개 + 보호 저장소 6개: 범위 분리·재시작·만료·로그아웃 쓰기 경합·오류/손상 보존. 실제 플랫폼 암호화 검증과 구분 |
| Flutter 정적 분석 | 수정 후 문제 없음 |
| Android 에뮬레이터 native 6개 | 통과. 실제 Android 보호 저장소에 가상 세션 저장→새 인스턴스 조회→해당 키 삭제, 기존 전투/입력/HUD·선택·기기 기록/설정·무료 보호막/미연결 복원 회귀 확인. 물리 기기/iOS 검증 아님 |
| npm 실행 의존성 audit | 0건. firebase-admin 14.5.0/firebase-functions 7.4.0 |
| npm 개발 도구 포함 audit | 7건(중간4/높음3), 최신 도입 Firebase CLI 15.34.0의 전이 의존성에 남음. 아래 제한 참조 |
| 일반 Android 앱 | lib/main.dart로 debug APK 재빌드·기존 com.example.raikeopeu2026.dev에 install -r 성공·일반 앱 실행. 기존 앱 데이터 삭제/재설치 없음 |
| 저장소 문서/민감 패턴 검사 | Markdown 73개·민감 패턴 검사 통과, 주요 추가 문서의 상대 링크 누락 없음. 실제 비밀의 부재를 전면 보증하는 검사는 아님 |
| 운영/실기기/iOS | 미실행. 실제 TLS/서명/App Check·IAM/배포 규칙·Auth 공급자/메일·스토어·두 실기기·iOS Keychain/재설치 잔존 확인 대기 |

npm lockfile 750개 항목의 resolved는 공식 registry.npmjs.org만 사용한다. 설치 script는 `--ignore-scripts`로 실행하지 않았다. 사용하지 않는 Firebase 웹/rules 테스트 SDK는 제거하고 공식 Firestore REST로 규칙을 실검사했다. 런타임 감사와 개발 도구 감사를 구분하며 자동 강제 수정/override·보안 우회는 하지 않았다. 남은 개발 도구 근원은 [OpenTelemetry](https://github.com/advisories/GHSA-8988-4f7v-96qf), [braces](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm), [uuid](https://github.com/advisories/GHSA-w5hq-g745-h8pq)이며 Firebase CLI는 고정 신뢰 입력/loopback에만 쓴다. 외부 입력·실제 자격증명과 결합하기 전 상위 의존성 수정 버전을 다시 확인해야 한다.

Flutter `flutter_secure_storage` 11.2.0은 pub.dev의 유지관리자 소스·Android/iOS 옵션/빌드·archive SHA-256 및 lockfile을 확인했다. 전이 플랫폼 패키지는 pub.dev 해시로 고정한다. Android backup/cleartext 거부 설정은 기존 것을 유지했다. [공식 패키지](https://pub.dev/packages/flutter_secure_storage). 네이티브 및 전이 의존성 전부의 무취약성/실기기 동작을 보증하는 검사는 아니다.

재현 명령은 [서버 README](../server/firebase/README.md)에 있다. 로컬 Node 24.21.0에서 실행했으며 선언한 Cloud Functions nodejs22 환경의 실행 결과는 아직 없다. Android 검사는 별도 `.integration` ID·가상 파일·가상 세션만 쓰며 일반 앱/기존 데이터를 삭제하지 않는다.

Android native 검사는 보호 저장소와 기존 게스트 흐름이다. 모바일 Auth SDK→서버 API의 실제 통신/로그인·토큰 갱신·UI 상태를 검증한 것은 아니다. debug 전용 BackendScope의 에뮬레이터 URI는 주소 계약일 뿐 일반 앱의 cleartext 거부를 풀지 않았다. 후속 SDK 연결 때 허용된 로컬 통신/실제 dev HTTPS 경로를 별도로 검증해야 한다.

이번 요청의 기반·로컬 권한 검증까지 진행하고 멈춘다. 이메일/소셜 화면 실연동·실제 공급자 proof 검증·계정 삭제·전체 게임 동기화·구매 검증/스토어 연결·클라우드/스토어 배포는 시작하지 않는다.
