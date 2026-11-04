# 8단계 소셜 인증 결과

2026-10-20 원격 후속: 사용자 승인으로 무료 개발 프로젝트·Google 클라이언트 3개·카카오 개발 앱/플랫폼/OIDC를 등록했다. 사용자가 **무료 유지**를 선택했고 중요한 변경 전 확인·원하지 않은 결제 금지를 명시했다. 실제 서버 배포/로그인·Apple/iOS native 검증은 미완료다. 현재 콘솔/공개 설정 상태와 한계는 [SOCIAL-REMOTE-SETUP.md](SOCIAL-REMOTE-SETUP.md)를 우선한다. 아래 2026-10-19 기록은 로컬 구현 시점의 근거다.

## 2026-10-20 원격 설정 후 재검증

- Flutter 정적 분석 문제 없음·호스트 **95개 통과**. 서버 TypeScript build·단위 **12개**·Auth/Firestore/Functions 가상 사용자 통합 **23개 통과**. A/B 소유권·미인증/만료·타인 조회/수정/삭제·유료 권한 임의 변경·명시적 연결/충돌/게스트 보존 검사를 포함한다. 실제 공급자 로그인이나 클라우드 규칙 적용을 뜻하지 않는다.
- 플랫폼별 공개 Firebase 프로젝트/App ID/API key 형식, Google Client ID 3개의 구분과 앱/서버 audience 대조, 카카오 Native Key/앱 ID·iOS reversed Client ID/콜백 일치, 관리자 비밀 필드 없음·모든 서버 READY false를 확인했다. 콘솔에서 Google 테스트 사용자 1개와 카카오 최소 동의항목/패키지/키 해시/번들 저장 값도 확인했다.
- 공개 개발 설정을 넣은 **Android debug APK 빌드 통과**. APK 내부에서 기존 `com.example.raikeopeu2026.dev`, 카카오 콜백 Activity/스킴, 등록한 debug 인증서 SHA-1을 대조해 통과했다. 이 APK는 컴파일/메타데이터 검사용이며 이번 후속에서 설치·실계정 로그인·스토어 업로드하지 않았다. 기존 설치 앱/기기 기록을 지우지 않았다. 2026-10-19 native 7개+인증2개의 검사는 과거 근거이며 이번에 다시 실행한 것으로 표시하지 않는다.
- 문서 **78개**, 변경 소스/문서 12개의 민감/개인 연락처 패턴과 상대 링크 **83개** 검사 통과. 공개 구성은 별도 Git 제외 로컬 폴더로 두고 일반 소스에 API key/비밀을 적지 않았다. `git check-ignore`는 저장소 소유권의 `dubious ownership` 보호로 차단돼 실제 추적 제외 검증/전체 Git 기반 민감 검사를 완료했다고 표시하지 않는다. `safe.directory`나 보안 설정을 바꾸지 않았다.
- 최초 제한 환경의 Flutter 검사는 시작 출력 없이 중단했고 로컬 에뮬레이터는 4501 포트 준비가 60초를 넘어 실패했다. 승인된 일반 로컬 환경에서 Java 경로를 명시해 다시 실행한 뒤 위 분석/95개/23개가 통과했다. 로컬 에뮬레이터는 Node24이고 설정 런타임은 Node22라는 경고, Firebase 플러그인의 향후 KGP 호환성·Java native-access·Android SDK XML 버전 경고는 남아 있다. 검사 삭제·보안 완화·강제 의존성 변경으로 우회하지 않았다.
- 사용자가 Apple 비밀번호 확인이 필요해 **Apple 보류**를 선택했다. 공식 로그인 화면만 열어두었고 비밀번호/2단계 인증·개발자 유료 가입·Team/capability 변경은 하지 않았다. 실제 Android/iOS 소셜 인증·iOS native·물리 기기 검증과 인증 서버 배포는 미실행이다. 무료 개발 설정/재검증 단위를 마치며 8단계 전체나 다음 단계를 완료로 표시하지 않는다.

2026-10-19. AIRZERO STRIKE 한 앱의 기존 6·7단계 서버/컨트롤러/계정 화면을 확장했다. 사용자가 선택한 **로컬 우선 구현·검증** 범위다. 실제 앱 등록·로그인·클라우드 적용은 대기이며, 실행 순서는 [SOCIAL-SETUP.md](SOCIAL-SETUP.md)에 정리했다. 다른 앱·게임 규칙/그래픽·구매 기능·계정 삭제·전체 게임 동기화는 수정하지 않았다. 가입/배포·commit/push도 하지 않았다.

## 구현

- 환경설정의 기존 계정/이메일 화면에 Google·카카오, iOS에 Apple 로그인 버튼을 연결했다. Apple은 native AuthenticationServices의 공식 버튼 스타일 위젯을 사용한다. 이메일 가입을 추가로 요구하지 않는다. 성공하면 계정 폼을 닫고 열었던 화면으로 돌아간다.
- 카카오톡 미설치는 브라우저 계정 인증을 사용한다. 취소/실패 시 대체 창을 강제하지 않고 명시적인 브라우저 버튼으로 다시 시도한다. busy/epoch/barrier로 중복 요청과 로그아웃 뒤 늦은 인증 응답을 차단한다.
- 기존 이메일 계정에 연결하는 별도 경로는 명시적 동의·현재 이메일 비밀번호로 SDK 재인증·최근 서버 인증·기존 서버 세션 소유권을 요구한다. 같은 이메일을 검색/자동 병합하지 않는다. provider가 다른 UID에 속하면 충돌하고 두 기록을 유지한다.
- 서버가 임의 challenge/state/nonce를 발급하고 해시만 저장한다. 5분 만료·플랫폼/연결 대상 UID/authEpoch·1회 사용을 확인한다. 검증된 provider subject를 내부 UID로 매핑하고 최초 동시 로그인은 Firestore transaction으로 한 UID를 선택한다.
- 공급자 검증 뒤에만 Firebase custom token을 발급한다. 공식 Firebase SDK가 이를 앱 ID token으로 교환하고 기존 UID/서버 세션/OS 보호 저장소로 이어진다. raw 공급자 토큰·바인딩 없는 custom 로그인은 개인 API에 접근하지 못한다.
- 네이티브 Firebase의 이메일 기반 자동 병합을 피하려고 직접 Firebase Google/Apple credential 로그인은 사용하지 않는다. 직접 클라이언트 credential linking 결과도 앱의 소셜 provider 매핑으로 복사하지 않는다. 승인 없는 소셜 계정 비밀번호 추가는 기존 7단계 규칙으로 거부한다.
- 로그인/취소/연결/로그아웃이 기기 기록·설정을 쓰거나 유료 권한을 변경하지 않는다. 기존 최초 가져오기는 빈 계정에만 명시적 동의/CAS/작업 ID를 적용하고 기존 계정 기록은 보존한다.

## 공급자 검증 경계

| 공급자 | 클라이언트/서버 구현 | 아직 실제 확인하지 않은 항목 |
|---|---|---|
| Google | 공식 Flutter native 어댑터, 요청별 nonce. 고정 Google JWKS·RS256·issuer·Web audience·허용 azp·iat/exp/nonce | 개발/릴리즈 OAuth client·인증서·실제 Android/iOS 인증/취소/복귀 |
| 카카오 | 공식 SDK v2 Talk/Account, 내부 PKCE. OIDC JWKS·native audience·nonce + opaque access token의 공식 token-info app/subject/수명 | 앱/OIDC/키 해시·scheme·Talk 설치/미설치 실제 OS 왕복·동의 거부 |
| Apple | native iOS ID token·scopes 최소화·state·SHA256 nonce. Apple JWKS·Bundle audience·issuer/수명 | Mac 빌드·Team/프로비저닝·실제 iPhone·이메일 숨기기·권한 철회 |

Google의 앱용 singleton은 한 번만 초기화하는 API이므로, 고정 버전의 공개 typed platform adapter를 이용해 직렬 요청마다 새 nonce를 설정한다. 이 경로의 nonce 전달은 호스트 fake-platform 테스트로 확인했으며 SDK 업데이트 때 재확인해야 한다. 공급자 SDK가 소유한 authorization code/state/PKCE/redirect 내부 처리를 서버가 직접 검증했다고 주장하지 않는다. 서버는 자체 challenge state와 실제 ID token nonce를 검증한다. Apple code/Google server authorization code/카카오 refresh token을 모두 JWT로 취급하거나 앱 세션으로 받지 않는다.

## 저장·접근·로그

자료는 기존 `apps/airzero-strike/environments/{dev|prod}`에 한정한다. `socialChallenges`에는 해시 state/nonce·5분 논리 만료·플랫폼/연결 의도/대상 UID/authEpoch, `socialGrants`에는 UID/provider subject/authEpoch·1시간 논리 만료, `providers`에는 subject 해시 키와 내부 UID/초기 생성 상태를 둔다. 비밀번호·원본 공급자 토큰·이메일/프로필 복사본은 저장하지 않는다. 카카오 TokenManager는 RAM만 사용한다.

private Firestore 클라이언트 규칙은 기본 거부를 유지한다. cloud에서는 HTTPS·허용 App Check 앱·검증된 Firebase 세션/사용자 상태·앱 grant·기존 객체 소유권을 검사한다. source 제한은 기존 서버 HMAC limiter를 재사용한다: 15분 동안 출처 20회, 소셜 begin/complete 합산 15회. 공급자 설정은 기본 비활성화하며 cloud HMAC 비밀 미설정은 거부한다. 로그는 고정 코드/상태만 기록한다.

Firebase SDK는 세션 갱신을 담당하지만 1시간 앱 grant 만료를 연장하지 않는다. 그 뒤에는 사용자 요청으로 공급자 인증을 다시 한다. Firebase 사용 중지/삭제/철회·앱 authEpoch 변경·provider 매핑 제거도 접근을 차단한다. Firebase 자체 인증 보관·App Check attestation·공급자 메타데이터의 실제 개인정보 처리/백업/Keychain 잔존은 별도 검증 대상이다.

논리 만료와 실제 TTL 삭제는 다르다. 클라우드 TTL/IAM/규칙/로그 보존·전체 공급자 동의 철회·탈퇴 시 하위 데이터 정리는 적용하지 않았다. 실제 적용 전 이 자료까지 삭제/보관 정책에 포함해야 한다. 가입/원본 IP/토큰을 저장하는 추가 추적 SDK는 없다.

## 검사 증거와 한계

- 서버 TypeScript build 및 단위 **12개 통과**. Google/카카오/Apple 합성 RSA 서명으로 issuer/audience/azp/서명/알고리즘/nonce/과거·미래·만료/kakao opaque token-info 오류·누락 이메일·기본 비활성을 검사했다.
- Auth/Firestore/Functions 로컬 통합 **23개 통과**: 기존 이메일/접근 통제 18개 + 소셜 5개. 합성 RSA proof → 실제 로컬 Firebase custom token 교환/세션, 최초 동시 생성, 이메일 같아도 별도 UID, 명시적 연결/충돌 보존, state/nonce/만료/재사용/다른 소유자, grant/계정 철회를 검사했다. 실제 공급자 통신을 했다는 의미가 아니다.
- 전체 Flutter 정적 분석 문제 없음, 호스트 **95개 통과**. 소셜 컨트롤러/어댑터 10개를 추가했고 기존 이메일/무료 전투/그래픽/설정/유료 권한 차단을 유지했다. 취소·중복·로그아웃 경합·원래 화면 복귀·fresh nonce·Talk 대체 선택을 가상 adapter로 검사했다.
- Android 네이티브 **7개 + 인증 2개 통과**. 미설정 소셜 로그인/게스트 기록 보존·보호 저장소·기존 전투/기록/설정 7개와, 공식 Firebase SDK custom token 교환만으로 앱 grant를 우회할 수 없다는 검사·기존 이메일 전체 흐름 2개다. 네이티브 custom token의 양성 소셜 전체 흐름과 실제 공급자 OS 왕복은 외부 설정 후 검증해야 한다. iOS native 빌드·물리 기기는 미검증이다.

추가 보완으로 직접 Firebase linking이 앱 provider 매핑을 자동 생성하지 못하게 했고 비활성 사용자의 새 토큰 발급/삭제 사용자 재생성을 거부했다. 카카오 token-info 응답은 스트림 읽기 중 8KB로 제한하고, opaque token은 JWT/base64url로 가정하지 않고 Bearer 문법을 허용한다. 이 보완 후 서버 단위12개/통합23개를 다시 통과했다. 운영 runtime은 nodejs22, 현재 로컬 실행은 Node24이며 서로 같은 환경이라고 표시하지 않는다.

## 외부 설정 대기

세 공급자 모두 **코드 구현·로컬 검증 / 실제 로그인 연결 대기**다. Firebase dev/prod 프로젝트·공급자 앱·OAuth/키 해시·App Check·custom token 서명 IAM·서버 HMAC Secret·메일 기존 정책/복귀 설정이 필요하다. native iOS는 Mac/Xcode/실기기가 추가로 필요하다. 현재 설정 파일 유무만 확인했으며 비밀 파일 내용/개인 계정/운영 자료를 읽지 않았다.

실제 Android/iOS의 성공·취소·동의 거부·이메일 미제공·카카오톡 미설치·잘못된 client/서명/콜백·공급자 만료/철회·장시간 로그인 유지·원래 앱 복귀는 [사용자 직접 확인 순서](SOCIAL-SETUP.md)의 남은 항목이다. 개발·릴리즈별 등록이 없어서 완료로 체크하지 않았다. 소셜 실연동은 설정 후 **8단계를 반복**한다. 결제/삭제 등 다음 단계는 시작하지 않는다.

## 의존성과 출처

공식 pub.dev/npm 메타데이터·배포 archive SHA/integrity·패키지 실행 스크립트/네이티브 설정·lockfile을 확인한 뒤 앱별로 고정했다. Firebase 기존 버전은 유지했다. 서버 설치는 `--ignore-scripts`를 사용했다.

| 패키지 | 버전/출처·조건 |
|---|---|
| google_sign_in / platform_interface | 7.2.0 / 3.1.0, [Flutter 공식](https://pub.dev/packages/google_sign_in), BSD-3-Clause |
| kakao_flutter_sdk_user/auth/common | 2.0.1, [Kakao 공식](https://pub.dev/packages/kakao_flutter_sdk_user), Apache-2.0 |
| sign_in_with_apple | 8.2.0, [aboutyou 브리지](https://pub.dev/packages/sign_in_with_apple), MIT. 공식 Apple native API 호출 |
| crypto | 3.0.7, Dart 패키지, BSD-3-Clause |
| jose | 6.2.12, [panva/jose](https://github.com/panva/jose), MIT, 고정 upstream JWKS 검증 |

주요 archive SHA256: Google `521031b65853b4409b8213c0387d57edaad7e2a949ce6dea0d8b2afc9cb29763`, Kakao user `047ff5a82f52a7e1558086acd87b89b941b072e6029de3eee0b96dbce4ca1e48`, Apple bridge `6d205ad2b30f95b231812d61f19b4a8df836f16ba9cde28735b3ac8ece9113f7`. 전이 의존성 해시는 `pubspec.lock`/서버 `package-lock.json`을 따른다. 라이선스 고지를 보존하며 앱 등록/브랜드 조건은 각 공급자 약관을 별도 준수한다.

서버 `npm audit --omit=dev --ignore-scripts`는 공개 공지 기준 런타임 **0건**이다. 기존 Firebase CLI 개발 의존성 감사/Flutter KGP·JDK 경고는 보안 우회나 강제 override로 숨기지 않는다. 전체 개발 감사·Android 경고 최종 결과는 아래에 기록한다.

## 최종 확인

- 최종 분석 문제 없음·Flutter95개·서버 build/단위12개/통합23개 통과. 문서76개·변경 앱 문서 상대 링크75개·민감 패턴 검사도 통과했다. iOS 공개 plist XML/Runner 세 구성의 entitlement 참조는 정적 확인했으며 native 빌드는 미실행이다. 토큰/링크/비밀/개인 자료를 출력하거나 실제 이메일에 테스트 메일을 보내지 않았다.
- Android 검사 앱은 `.integration` ID이며 일반 개발 앱과 분리했고 `--no-uninstall`을 사용했다. 일반 debug APK는 테스트 플래그 없이 따로 빌드해 `com.example.raikeopeu2026.dev`를 확인한 뒤 `adb install -r`로 업데이트했다. 기존 ID/데이터를 삭제하지 않았다. 첫 `am start -W`는 timeout, 재시도는 이미 실행 중인 최상위 Activity에 전달되어 `Status: ok`와 프로세스 실행을 확인했다. 일반 앱의 개인 기록/캡처는 조회하지 않았다. 실기기의 초기 로딩/장시간 성능은 미검증이다.
- 기존 native 재시작 검사 한 건은 파일 I/O 완료보다 화면 단언이 먼저 실행되어 실패했다. 캠페인 로딩 완료를 제한 시간 안에서 기다리도록 검사 코드를 수정한 뒤 7개 전체 통과했다. 새 계정 연결 보존 fixture의 누락 generation도 보완했다. 게임 규칙/저장 포맷을 완화해 검사를 통과시키지 않았다.
- 중복 인증 스택을 만들지 않고 기존 컨트롤러/서버/화면을 확장했다. 예전 미연결 upstream stub은 실제 provider별 verifier로 대체했다. 계정 상태/설정 누락 문구는 소셜에도 맞게 수정했다.
- 서버 runtime 감사0건, 개발 CLI 전이 의존성은 **7건(중간4/높음3)**이다. Firebase CLI의 pubsub/otel·chokidar/braces·gaxios/uuid 경로이며 임의 downgrade/강제 override는 적용하지 않았다. CLI는 업로드 대상에서 제외하고 고정 loopback 검사로 한정했다. Firebase plugin의 KGP 향후 호환성·JDK native-access 경고도 남아 있다. 현재 debug 빌드는 통과했으며 공급자 공식 업데이트/운영 runtime·릴리즈 검증은 별도다.
- 세 공급자 모두 실제 앱 등록/로그인·클라우드/IAM/규칙 적용 대기다. iOS 버튼 표시/합성 Apple proof 검사는 iOS native 실연동 완료가 아니다. 외부 설정 후 이 8단계를 반복하고 결제/삭제/전체 동기화는 시작하지 않는다.
