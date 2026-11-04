# 외부 연동 준비표

2026-10-27 최신 후속은 [9단계 실제 연결 준비·직접 설정 안내](ACCOUNT-LIVE-SETUP.md)를 따른다. Firebase 개발 프로젝트·Google 클라이언트3개·카카오 앱1614509는 기존 등록 이력이 있고 공개 구성/콜백16개를 이번에 로컬 대조했다. 현재 콘솔/실제 로그인 재검증은 아니다. 아래의 “등록 전/모두 미확인” 표는 최초 설계 이력이며 기존 등록을 중복 생성하라는 지시가 아니다. Apple은 계정 로그인만 완료·유료 멤버십 없음, 무료 유지·원격 배포/실제 삭제 금지다.

8단계 소셜 로그인은 사용자 선택에 따라 로컬 코드/검증을 먼저 준비했다. Google/카카오/필요한 iOS Apple의 개발자 앱 등록·client/서명/Bundle/scheme·App Check·custom token IAM·서버 HMAC secret은 실제 적용 대기다. 기존 파일은 존재 여부만 확인했다. 비밀 값을 채팅에 보내지 않고 직접 설정하는 순서는 [SOCIAL-SETUP.md](SOCIAL-SETUP.md), 공급자별 구현/실연동 구분은 [SOCIAL-AUTH-RESULTS.md](SOCIAL-AUTH-RESULTS.md)를 우선한다. 이번 작업에서 가입·클라우드/스토어 배포를 실행하지 않았다.

7단계에서 공식 이메일 SDK/화면·로컬 서버를 연결했지만 아래 **실제 외부 설정**은 적용하지 않았다. 새 필수 조건은 이메일 provider/비밀번호 정책·클라이언트 직접 가입 제한·enumeration/자동 공격 방어·검증된 App Check·메일/복귀 handler·서버 전용 HMAC Secret이다. 확인 전 `AIRZERO_EMAIL_SECURITY_READY` 미설정으로 기본 거부한다. 공개 client config와 서버 비밀을 분리하며 실제 메일/링크 만료·referrer/로그 통제·Android/iOS 복귀는 [7단계 직접 확인 목록](EMAIL-AUTH-RESULTS.md)을 따른다. 이 플래그가 실제 콘솔 설정을 검사하거나 대신 적용하지 않는다.

6단계 로컬 구현/검사는 [AUTH-BACKEND-RESULTS.md](AUTH-BACKEND-RESULTS.md)에 완료 증거를 기록했다. 실제 외부 설정 상태는 여전히 아래처럼 미확인이다. 실제 dev/prod의 project/region/허용 App Check app ID/전용 service account 설정이 없으면 서버 시작을 거부한다. dev/prod 규칙 파일은 각각 준비했으며 운영 적용하지 않았다. 설정 계약/로컬 실행은 [서버 README](../server/firebase/README.md)에 있다. 비밀 값을 전달할 필요는 없다.

이 표의 설정 상태는 모두 **미확인 / 이 단계에서 생성하지 않음**이다. 사용자의 콘솔·인증 파일·실제 이메일·비밀 값을 읽거나 요청하지 않았다. 개발자 계정·프로젝트·상품·키 생성과 설정은 사용자가 직접 한다.

## 환경·식별자 경계

| 항목 | 개발/테스트 | 운영 |
|---|---|---|
| 앱 식별자 | 제안 com.example.raikeopeu2026.dev, 등록 전 | 제안 com.example.raikeopeu2026, 실제 개발자 prefix 확정 전 |
| Firebase | 로컬 demo- 프로젝트로 시작, 실제 dev 프로젝트는 사용자 생성 | 이 앱 전용 별도 프로젝트, 타 앱/테스트 DB와 분리 |
| 게임 저장 | Auth/Functions/Firestore Emulator로 두 가상 기기·UID별 저장/충돌 검증 | 같은 계정 게임 프로필·세션/정산 DB, 지역·보관/백업·IAM·비용 한도 사용자 확인 |
| 구매 | StoreKit 로컬/샌드박스, Google 라이선스 테스터·가상 API | 운영 스토어·상품만 허용 |
| OAuth | dev 앱 키·서명·callback 허용 목록 | 운영 앱 키·앱 서명·도메인 별도 |
| 로컬 비밀 경로 | 예정 ~/.app-secrets/raikeopeu2026/dev/ | 예정 ~/.app-secrets/raikeopeu2026/prod/ |

경로는 저장소 밖의 보관 위치 제안이며 폴더/파일을 만들거나 실제 존재를 확인한 값이 아니다. 이후 준비 여부와 경로만 기록하고 키·토큰·비밀번호·영수증 본문은 기록하지 않는다. 운영에서는 가능하면 관리형 서비스 계정/IAM·Secret Manager를 사용하고 서비스 계정 JSON 다운로드를 피한다. 이 경로의 AI 제외도 준비 설정일 뿐 현재 관리 세션의 실제 차단 적용은 미확인이다.

## 공급자별 설정을 섞지 않기

| 연동 | 공개 식별자·리다이렉트·서명 설정 | 서버 전용 비밀 / 안전한 위치 계획 | 사용자 준비와 검증 시점 |
|---|---|---|---|
| Firebase 이메일/비밀번호 | 앱별 Firebase project/app ID, email/password 활성화, 승인 도메인, 이메일 action URL·continue URL | 앱에 Admin 비밀을 넣지 않음. 운영 IAM/Secret Manager | 7단계 실제 메일 전송 전 템플릿·발신자·도메인·쿼터 확인. 로컬은 에뮬레이터로 선행 |
| 계정 게임 저장/이어하기 | 앱/환경별 Functions 저장 API·Firestore 데이터베이스·지역·스키마/인덱스·기본 거부 규칙 | 서버 최소 IAM, Admin 비밀을 앱에 포함하지 않음. 백업·정산/세션 자료도 사용자별 분리 | 6단계 에뮬레이터 검증 후 사용자 dev 설정, 두 실기기의 같은 UID 저장/재로그인/충돌 검증. 운영 생성/공개는 사용자 수행 |
| 이메일 확인/복구 링크 | 콘솔 기본 action handler와 앱 복귀용 검증된 App/Universal Link. OAuth의 /__/auth/handler와 이메일의 /__/auth/action을 구분 | 일회성 코드·링크는 사용자에게만 표시, 저장/로그 금지 | Firebase 콘솔이 제시하는 실제 URL을 사용. 폐기된 Firebase Dynamic Links 기반 설계를 추가하지 않음 |
| Google Android 로그인 | OAuth Android client ID, package name, debug/release SHA-1·필요한 SHA-256, Firebase Google provider | native client ID는 공개 설정. 별도 웹 클라이언트 secret이 필요한 서버 흐름이면 Secret Manager | 8단계 실제 로그인 전. upload key와 Play App Signing의 앱 서명 인증서를 구분 |
| Google iOS 로그인 | iOS OAuth client ID·Bundle ID·reversed client URL scheme. 웹 흐름이면 허용 redirect와 Firebase callback | 필요한 웹 OAuth secret만 서버. 예정 dev/prod/google-oauth/ | native/웹 client를 혼용하지 않고 최소 scope. 앱 내 연결 해제까지 검증 |
| Kakao 로그인 | 앱 ID·Native/REST 앱 키, Android package/key hash, iOS Bundle ID/URL scheme, 필요한 REST redirect URI·OIDC 활성화·동의 항목 | REST client secret이 필요한 경우만 서버 Secret Manager. 불필요한 Admin key를 앱/문서에 넣지 않음 | 8단계 실제 로그인 전. 사용한 키와 aud·nonce·state 일치 확인. 이메일/전화번호 scope 강요 안 함 |
| Apple 로그인 (iOS) | App ID/Bundle ID·Sign in with Apple capability·Team ID. 웹 OAuth를 쓸 때 Service ID·return URL/도메인 | 로그인용 Key ID·.p8 및 client-secret 생성은 서버. 예정 dev/prod/apple-login/ | 8단계 로그인·이메일 숨김·토큰 철회·계정 삭제까지 확인. Apple 결제 키와 구분 |
| Apple 월간/연간 구독 | 앱 레코드·하나의 구독 그룹 안 월간/연간 product ID·동일 혜택/서비스 수준·샌드박스 테스터·Server Notifications V2 URL | App Store Server API 전용 issuer/key ID·.p8. 예정 dev/prod/apple-store/ | 10단계 실제 샌드박스 전. 유료 앱 계약·세금/정산·상품 상태·접근 권한은 사용자가 확인 |
| Google 월간/연간 구독 | package·구독 상품·월간/연간 자동 갱신 base plan·중복/교체 처리·라이선스 테스터·테스트 조건·RTDN Pub/Sub 설정 | Android Publisher 최소 권한 서비스 계정/IAM. JSON이 꼭 필요한 경우만 예정 dev/prod/google-play/ | 10단계 공식 테스트 전. 필요 앱/상품/서명 사전 등록과 사용자의 테스트 업로드를 구분 |
| iOS 코드 서명 | 개발/배포 인증서·provisioning·Team/Bundle ID | .p12/서명 키는 OS Keychain 또는 예정 dev/prod/signing/ | Mac 빌드 단계에서 사용자 준비. Apple 로그인 .p8/IAP .p8과 다름 |
| Android 코드 서명 | debug/release/upload/app-signing 인증서의 용도 구분 | .jks/.keystore·key.properties는 저장소 밖 signing/ | debug부터 가능, 운영 서명/비밀번호는 사용자만 관리. 개인 키 출력 안 함 |
| Cloudflare Pages | 프로젝트·공개 도메인·지원/개인정보/삭제/약관 URL, 필요한 DNS | 수동 공개라 API token 불필요. 추후 CLI를 선택하면 token은 사용자 보관 | 9/12단계 사용자 공개 전 URL 확인. 현재 계정 가입·프로젝트 생성·업로드 안 함 |
| 삭제 요청 웹 경로 | 재설치 없이 접근할 URL, 앱/개발자명, 요청 접수·본인 확인·처리 상태 경로 | 삭제 API의 관리자 비밀은 서버만, URL에 토큰/UID를 노출하지 않음 | 9단계 로컬 가상 요청 → 운영 전 소유 테스트 계정으로 실제 종단 검증 |

참고: [Firebase Flutter 공급자 구성](https://firebase.google.com/docs/auth/flutter/federated-auth), [Kakao 공식 로그인 API](https://developers.kakao.com/docs/en/kakaologin/rest-api). 콘솔이 제공한 프로젝트별 실제 값을 우선하고 이 표의 제안 식별자를 등록된 값으로 사용하지 않는다.

## 지금 가능한 로컬 개발과 사전 설정이 필요한 검증

가격은 관리자 사용자만 최종 검토 후 스토어 콘솔에서 설정/변경한다. 월간/연간 각각 총 청구액·지역·갱신 조건과 기존 구독자 가격 변경/동의 규칙을 검토한다. 앱의 가격 표시값 편집으로 실제 청구액을 바꾸지 않으며 공식 SDK 가격을 사용한다. 일반 사용자에게 가격 입력/변경 권한을 주지 않는다. 현재 가격·상품 생성·콘솔 변경은 실행하지 않는다.

| 작업 | 콘솔 설정 없이 가능한 범위 | 실제 연동 전 필요한 사전 설정 |
|---|---|---|
| 이동·변신·폭탄·탄막·성장·기체 선택 | 가상 자산/데이터와 로컬 저장으로 개발·테스트 가능 | 없음. 상업용 최종 자산 라이선스는 별도 확인 |
| 계정 게임 저장/이어하기 | 가상 저장 adapter·Auth/Functions/Firestore Emulator, 같은 UID 두 세션·다른 UID·오프라인/중복/삭제 시뮬레이션 | 사용자 dev 프로젝트·DB 지역·규칙/IAM·Functions·검증할 계정/두 기기. 실제 운영 가입/공개와 분리 |
| 이메일/계정 상태 UI | demo- Auth Emulator·가상 확인/복구 링크·만료/재사용·거부 상태 | 실제 Firebase provider·메일 템플릿/도메인·소유 개발 메일 계정 |
| Google/Kakao/Apple | 공급자 응답 mock·취소/오류/토큰 위조·연결 충돌 처리 | 각 개발자 앱·클라이언트·서명·리다이렉트·테스트 허용 계정 |
| 삭제/접근 통제 | Auth/Functions/Firestore Emulator와 사용자 A/B·가상 삭제 작업 | 실제 공급자 연결 해제·세션 철회·웹 요청 접수·보관 정책 |
| 구매/복원/환불 | 가상 스토어 adapter·거래 상태 테스트. StoreKit 로컬은 Mac/Xcode 필요 | Apple sandbox/Google 라이선스 테스터·앱/상품·필요 서명·서버 API 권한·알림 |
| 공개 문서 | 이 폴더 Markdown 초안, 이후 로컬 HTML 미리보기 | 사용자 도메인/지원 연락처·Cloudflare 공개·삭제 API 경로 |

최종 스토어 공개 전에도 실제 OAuth와 결제 검증을 하려면 콘솔 사전 설정이 필요할 수 있다. 실제 테스트 업로드·테스트 배포가 필요한 경우 사용자에게 안내하고 대신 실행하지 않는다. 설정 지연으로 독립적인 핵심 게임 개발을 중단하지 않는다. 가상 테스트 성공을 실결제·실메일·실소셜 로그인 검증 완료로 표시하지 않는다.

이메일 에뮬레이터는 실제 메일함 전달/스팸/공급자 발신 제한을 검증하지 않는다. 실연동 단계에서 사용자가 소유한 개발용 계정으로 직접 메일 수신 → 확인 → 만료/재사용 거부 → 재설정 → 새 비밀번호 로그인/이전 세션 처리 순서로 확인한다. 실제 사용자에게 테스트 메일을 보내지 않는다. [Auth Emulator 지원 범위](https://firebase.google.com/docs/emulator-suite/connect_auth), [Play 결제 테스트](https://developer.android.com/google/play/billing/test), [StoreKit 로컬 테스트](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode).
