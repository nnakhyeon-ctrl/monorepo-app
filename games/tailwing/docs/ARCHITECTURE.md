# 인증·서버 저장·동기화 설계

최신 8단계는 [소셜 인증 결과](SOCIAL-AUTH-RESULTS.md)를 우선한다. 기존 이메일 컨트롤러/서버에 Google·카카오·iOS Apple별 proof 검증 → provider subject/internal UID → Firebase custom token/SDK 세션 → 기존 개인 API를 연결했다. 직접 Firebase trusted-email 병합은 사용하지 않는다. 명시적 연결과 최근 재인증을 요구하며 게임 기록/설정/이용권은 합치지 않는다. 실제 공급자 등록/운영 적용은 [설정 순서](SOCIAL-SETUP.md)의 대기 항목이다. 아래 소셜 미구현 문장은 과거 이력이다.

2026-10-19 최신 7단계는 [EMAIL-AUTH-RESULTS.md](EMAIL-AUTH-RESULTS.md)를 우선한다. 공식 FlutterFire Core/Auth/App Check와 기존 계정 폼·6단계 서버를 연결했다. 메일/링크 입력 검증·재인증·재설정 후 세션 철회·빈 계정의 명시적 기록 보관을 구현하며 현재 전투/설정은 기기에 보존한다. 실제 메일/자동 앱 복귀/운영 정책 적용은 미검증이다. 소셜·결제·삭제·전체 동기화는 새로 연결하지 않았다. 아래 이전 단계의 SDK 미연결 설명은 당시 이력이다.

2026-10-19 6단계 최신 구현은 [AUTH-BACKEND-RESULTS.md](AUTH-BACKEND-RESULTS.md)를 우선한다. `server/firebase`에 실제 Admin SDK 검증·앱/환경/UID별 API·기본 거부 규칙·로컬 에뮬레이터 검사를 추가했다. Flutter에는 OS 보호 저장소/토큰 공급 인터페이스만 추가했으며 Auth SDK/화면·운영 DB·전체 동기화는 미연결이다. 아래의 ‘모두 계획/SDK 미설치’ 문장은 이전 단계 이력이며 최신 서버 구현 상태를 대신하지 않는다.

2026-10-19 현재 구현: 기존 Flutter Ticker/CustomPainter 전투를 재사용하고 순수 Dart 전투 모델/15개 작전·path_provider 기기 기록을 추가했다. Flame은 설치하지 않았고 현재 구현의 필수 의존성이 아니다. 협동 참고 서버도 같은 Dart 엔진을 사용한다. 아래 Firebase 인증/기록 서버 구성은 계획이며 실제 연결 대기다. [현재 실행 결과](PLAYABLE-RESULTS.md), [협동 구조](COOP.md)를 우선한다.

아래 게임 엔진·인증·서버 구성은 계획이며 해당 SDK 설치·가입·운영 공개·실연동은 수행하지 않았다. 4단계 Flutter 기본 화면만 생성했으며 구조와 실행 결과는 [STAGE4-RESULTS.md](STAGE4-RESULTS.md)에 기록한다. 사용자가 원본 프로젝트 없이 신규로 만들면서 기존 아케이드 경험을 개선하는 방향으로 확인했다. 특정 원작 코드 재사용을 전제로 하지 않는다.

## 선택한 구성

| 영역 | 설계 선택 | 이유와 경계 |
|---|---|---|
| 모바일 | Flutter Ticker/CustomPainter + 순수 Dart 전투 모델 | 기존 구현 재사용, 렌더·입력과 전투 계산 분리. 현 범위에 Flame/별도 monorepo 도구를 강제하지 않음 |
| 인증 | Firebase Authentication | 이메일/비밀번호·Google·Apple·인증 에뮬레이터 지원. Kakao는 별도 서버 검증 후 custom token으로 연결 |
| 앱 서버 | 이 앱 전용 Cloud Functions for Firebase, Node/TypeScript | Admin SDK와 공식 스토어 API 검증, 삭제 작업·provider 연결·거래 처리. Node 런타임 지원 범위는 도입 단계에서 재확인 |
| 서버 DB | Cloud Firestore | 계정·provider·구매 원장과 분리한 UID별 게임 프로필. 진행·기체/성장·코인·최고 기록의 서버 확정본 저장 |
| 진행 동기화 | 앱 전용 Functions 저장 API + 서버 트랜잭션 | UID·revision·generation·작업 중복/쓰기 세션을 검증. 같은 계정의 다른 휴대폰에서 서버 확정본 불러오기 |
| 기기 저장 | UID별 로컬 캐시/대기열 + 기기 설정 | 오프라인 진행·전송 재시도·음량/조작 등. 클라우드와 기기 상태의 차이를 표시하고 세부 정책은 CLOUD-SAVE.md를 따름 |
| 세션·검증 캐시 | Auth SDK의 플랫폼 세션 보관 + OS 보안 저장소 | 비밀번호를 앱이 저장하지 않음. 서버 서명 이용권만 캐시하고 클라이언트 boolean을 권한 근거로 쓰지 않음 |
| 공개 안내 | Cloudflare Pages | 지원·개인정보·삭제·약관 문안. 정적 파일에 비밀이나 사용자 요청 내용을 넣지 않음 |

Flame의 루프·충돌·입력 지원과 Firebase의 custom token 모델을 확인했다. 이 조합은 현재 요구에 대한 설계 판단이며 기존 원본 프로젝트가 제공되면 재사용 범위·호환성을 다시 평가한다. [Flame 공식 저장소](https://github.com/flame-engine/flame), [Firebase custom token](https://firebase.google.com/docs/auth/admin/create-custom-tokens).

## 계정과 게임 저장은 별개

2026-10-18 사용자 요청으로 게임 진행·기체·영구 성장·재화·최고 점수를 서버 저장하고 같은 UID로 다른 휴대폰에서 이어하게 한다. 기기 설정과 UID별 오프라인 캐시는 구분한다. 인증·게임 기록 동기화·구매 복원은 서로 다른 상태로 처리한다. 동기화 완료/대기/충돌·체크포인트·다른 기기 쓰기 세션은 [CLOUD-SAVE.md](CLOUD-SAVE.md)를 따른다. 다른 앱이나 개발/운영 환경과 DB·서명·이용권을 공유하지 않는다.

정식 계정을 선택한 사용자는 앱 내부 UID로 식별한다. 이메일·Kakao subject·Google/Apple subject는 그 UID의 인증 수단이다. 소셜 이메일이 없으면 추가 수집하지 않고 프로필 사진·실명도 저장하지 않는다. 이메일 가입을 선택한 사용자에게만 이메일과 비밀번호를 요구한다.

같은 계정의 여러 기기 기록을 복구하려면 계정 연결이 필요하다. 기본 로컬 플레이는 계정·구독 없이 제공한다. 구독 구매/복원에는 정식/임시 세션의 소유 관계를 검증하며 임시 인증을 채택하면 이메일 없는 Firebase anonymous UID에서 정식 계정 연결을 검증한다. 이 경로는 다른 기기 기록 복구를 보장하지 않는다. 정식 계정 연결을 선택하면 최초 로컬 기록 가져오기/기존 클라우드 기록 충돌을 설명하고 처리한다. 스토어 검증이 없으면 구독 전용 기체·캐릭터·특수 장비만 잠근다. 기본 플레이를 차단하지 않는다. 구독과 무관하게 계정 게임 기록을 보존한다. [Firebase 임시 인증과 계정 연결](https://firebase.google.com/docs/auth/flutter/anonymous-auth).

## 인증 단위

1. 이메일: 등록 → 확인 메일 안내 → 검증 상태 갱신 → 로그인. 미확인 계정에는 확인 재전송·로그아웃·계정 삭제를 제공한다. 로컬에서 이미 산 게임까지 이메일 미확인을 이유로 차단하지 않는다. 클라이언트 emailVerified 표시만 믿지 않고 서버 ID token 상태도 확인한다.
2. 복구: 존재 여부를 노출하지 않는 동일 응답 → 일회성 재설정 링크 → 만료·재사용 검사 → 세션 갱신/폐기. 링크·코드·비밀번호는 로그/캡처에 남기지 않는다.
3. Google/Apple: 공식 공급자 자격증명을 Firebase에 교환, 서버는 Firebase ID token의 서명·issuer·audience·만료·해당 앱 환경을 검증한다. Apple은 nonce를 포함한 실제 인증과 계정 삭제 시 토큰 철회까지 연결한다.
4. Kakao: 서버가 짧은 수명의 일회용 nonce를 현재 임시/정식 세션에 연결 → Kakao SDK/OIDC 로그인 → 서버가 JWKS 서명·허용 알고리즘·issuer·앱 키 audience·exp·nonce·재사용 여부를 검증 → provider subject를 앱 UID에 매핑 → Admin SDK로 custom token 발급 → 앱에서 Firebase 로그인. ID token 정보 조회용 디버깅 API나 단순 JWT decode를 운영 검증으로 쓰지 않는다.
5. Kakao 토큰 audience는 사용한 REST/Native 앱 키에 따라 달라질 수 있으므로 환경별 정확한 허용 목록을 사용한다. 원본 액세스/리프레시 토큰은 서버 DB에 저장하지 않는다. nonce 전달을 지원하는 공식 로그인 경로를 구현 단계에서 확인하고, 미지원 경로를 검증 생략으로 우회하지 않는다.

검증 근거: [Firebase 서버 ID token 검증](https://firebase.google.com/docs/auth/admin/verify-id-tokens), [Flutter Google/Apple 인증·철회](https://firebase.google.com/docs/auth/flutter/federated-auth), [Kakao OIDC·서명·audience](https://developers.kakao.com/docs/en/kakaologin/rest-api).

## 계정 연결과 사용자별 통제

- 이메일 문자열이 같다고 서버 데이터나 구매를 합치지 않는다. 기존 UID와 새 공급자 양쪽을 재인증한 뒤 명시적으로 연결한다. Firebase의 trusted-provider 동작으로 UID/provider 정보가 변하는 경우도 8단계 실연동에서 검증하며 자체 구매 귀속은 별도로 보호한다.
- Kakao 연결은 현재 Firebase 세션 + 새 Kakao 인증의 소유 증명을 확인해 같은 UID의 provider 매핑으로 처리한다. 기존에 다른 UID에 연결돼 있으면 자동 덮어쓰지 않고 두 계정 증명과 명시적 복구 절차로 처리한다.
- 서버 API는 요청 본문의 uid를 권한 근거로 사용하지 않는다. 검증한 token의 uid, 활성/삭제 상태, 앱·환경을 기준으로 판단한다. 민감 작업은 최근 재인증과 철회/비활성 여부를 확인한다.
- Firestore는 기본 거부. 계정/게임 프로필/이용권의 본인 최소 조회는 검증된 API로 제공하고 저장/재화 정산은 서버 전용. provider 매핑·원본 거래 자료·삭제 작업·웹훅 중복키는 클라이언트 직접 읽기/쓰기 모두 금지한다. Admin SDK는 Security Rules를 우회하므로 서버 IAM·UID/활성 상태 검증도 별도로 필요하다.
- 사용자 A/B·임시 사용자·로그아웃·삭제된 사용자·다른 앱/환경 간 접근 거부를 가상 데이터로 검증한다. uid 변경·ID token 재사용·거래 재연·다른 상품 ID를 포함한다.
- 게임 기록은 연결한 UID의 서버 프로필과 기기 캐시로 분리한다. 로그아웃/계정 변경 시 이전 UID의 대기열을 새 계정으로 보내지 않는다. 계정 기록 초기화·계정 삭제와 이 기기 캐시 삭제를 구분하고, 오래된 오프라인 작업이 삭제/초기화한 기록을 되살리지 않게 한다.

## 보안 수준과 세션

일반 싱글 플레이 게임이며 금융·신용·성인 본인확인 서비스로 설계하지 않는다. 전화번호/SMS/PASS·주민번호·카드·계좌·설치 앱 목록을 받지 않는다. Kakao/Google 로그인은 결제가 아니다.

비밀번호 변경·공급자 연결/해제·계정 삭제·구매 귀속 변경에는 최근 재인증을 요구한다. 일반 가입과 구매에 고객 MFA를 강제하지 않는다. 서비스 운영자 콘솔은 강한 MFA와 최소 권한을 사용자가 설정한다. 추후 고객 MFA가 필요하면 전화번호 없는 수단·비용·필요성부터 검토한다.

로그인 유지·토큰 갱신·로그아웃을 명시적으로 구현한다. 로그아웃은 이 기기 세션을 정리하고 타 UID 캐시를 노출하지 않는다. 계정 삭제는 활성 상태를 먼저 닫고 세션 철회·데이터 삭제를 재시도 가능한 서버 작업으로 진행한다. App Check/무결성 검증은 서버 남용 방어 보조 수단으로 검토하며 사용자 인증이나 구매 검증을 대신하지 않는다. 새 분석·광고 SDK는 추가하지 않는다.

## 로컬 검증과 운영 경계

Auth/Functions/Firestore Emulator Suite의 demo- 프로젝트와 가상 스토어 응답을 사용한다. 인증 에뮬레이터의 서명 없는 token은 로컬에서만 허용하고 운영 서버는 에뮬레이터 환경 변수가 켜진 상태로 시작하지 못하게 한다. 에뮬레이터 데이터·계정·거래를 운영으로 마이그레이션하지 않는다.

이메일 링크는 에뮬레이터가 로컬 UI/터미널에 제공하므로 실제 사용자에게 메일을 보낼 필요가 없다. 이후 개발자가 소유한 테스트 메일 계정에서 실제 전달·스팸 처리·링크 도메인·만료/재사용·기기 복귀를 별도로 직접 확인한다. 현재는 지원 여부 확인만 했으며 실행 결과는 아니다. [인증 에뮬레이터](https://firebase.google.com/docs/emulator-suite/connect_auth).

실제 공급자 동의·스토어 영수증·웹훅 서명·라이선스 테스터·두 실기기 클라우드 저장은 콘솔 사전 설정이 있어야 검증할 수 있다. 설정이 늦어도 5단계 게임 저장 모델·로컬 캐시와 6단계 가상/에뮬레이터 동기화·인증 UI·가상 이용권 검증은 독립적으로 진행한다. 운영 공개·서비스 가입·과금 플랜 활성화는 지금 하지 않는다.
