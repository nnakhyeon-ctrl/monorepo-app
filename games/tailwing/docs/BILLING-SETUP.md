# 10단계 스토어 테스트·서버 설정 준비

2026-10-28. 현재 상품 ID/가격은 미정이며 구매는 잠겨 있다. 실제 결제·상품/테스터 등록·계약 동의·결제 계정 연결·배포는 실행하지 않았다. [구현/검증 결과](BILLING-RESULTS.md), [9단계 선행 조건](ACCOUNT-LIVE-SETUP.md)을 함께 확인한다.

## 후속 점검 — 로컬 누락과 직접 입력 순서

기존 판매 방식은 **기본 무료 + 같은 혜택의 월간/연간 자동 갱신 구독**이다. 새 상품 종류/가격·광고/재화·체험/할인을 추가하지 않았다. 이전 사용자 답변인 “상품 ID 미정·미설정”을 유지한다. 현재는 로컬 보완에 상품 선택이 필요하지 않아 다시 묻지 않았다. 실제 등록 직전에만 소유자가 ID·판매 국가·가격을 확정한다. 아래는 직접 준비 절차이며 이번 작업에서 콘솔에 등록하거나 설정을 적용하지 않았다.

앱 폴더에서 `node tool/check_billing_readiness.mjs`를 실행한다. 현재 결과는 `PENDING`, `EXAMPLE_ONLY_NOT_RUNTIME`, 실제 연결 `NOT_RUN`이다. 종료 코드2는 준비 누락, 1은 잘못된 입력이며 0도 로컬 형식 검사를 뜻할 뿐 실제 연결/판매 허가가 아니다. 공개 점검 양식 `config/billing.public.example.json`에 상품 관련 ID7개와 공개 주소4개가 비어 있다. 필요할 때 `config/.local-public/billing.dev.public.json`에 **공개 값만** 복사해 점검할 수 있다. 원문 값·추가 필드·오류 본문은 출력하지 않는다. 이 파일은 런타임 환경/배포 입력이 아니며, READY를 true로 적어도 연결 완료나 구매 권한이 되지 않는다. 비밀키·토큰·인증서는 이 양식에 넣지 않는다.

| 누락된 공개 값 | 직접 확인할 위치 | 코드에 연결할 위치 |
|---|---|---|
| Play product ID | Play Console → 해당 앱 → 수익 창출 → 상품 → 정기 결제 | 서버 `AIRZERO_PLAY_SUBSCRIPTION_ID` |
| 월/연 base plan ID2개 | 위 구독 → 기본 요금제 → 자동 갱신 → 1개월/1년 | 서버 `AIRZERO_PLAY_MONTHLY_PLAN`, `AIRZERO_PLAY_ANNUAL_PLAN` |
| Apple 월/연 product ID2개 | App Store Connect → 해당 앱 → 구독 → 같은 그룹/같은 서비스 수준 | 서버 `AIRZERO_APPLE_MONTHLY_PRODUCT`, `AIRZERO_APPLE_ANNUAL_PRODUCT` |
| Apple group ID·App Apple ID | 구독 그룹 정보·앱 일반 정보 | 서버 `AIRZERO_APPLE_SUBSCRIPTION_GROUP`, `AIRZERO_APPLE_STORE_APP_ID` |
| 약관·개인정보·지원 URL3개 | 운영자가 확정한 HTTPS 공개 페이지 | 앱의 공개 빌드 설정 `AIRZERO_TERMS_URL`, `AIRZERO_PRIVACY_URL`, `AIRZERO_SUPPORT_URL` |
| 외부 계정 삭제 URL | 실제 웹 본인 확인/삭제 어댑터 구현·공개 후 주소 | 점검 양식 `AIRZERO_ACCOUNT_DELETION_URL`만 기록. 현재 웹 구현/공개 미완료이며 앱에 값을 넣어 해금하지 않음 |

앱의 `PublicContacts.fromEnvironment()`가 공개 주소3개와 선택적인 `AIRZERO_SUPPORT_EMAIL`을 읽는다. 공개 주소만 담은 파일을 별도로 준비한 후 `flutter run --dart-define-from-file=config/.local-public/policies.public.json`으로 개발 실행할 수 있다. 이 파일에는 위 URL3개/선택적 공개 문의 이메일만 넣는다. 결제 점검 양식 전체나 서버 READY·Secret을 앱 빌드에 전달하지 않는다. 주소가 비어 있거나 허용 HTTPS 주소가 아니면 기존 “등록 대기” 표시와 구매 차단을 유지한다. 주소 형식 통과는 웹 공개/정책 내용 검증을 대신하지 않는다.

### Play에서 직접 확인할 순서

1. [Play Console](https://play.google.com/console/)의 **기존 앱**에서 패키지와 결제 기능 사용 권한부터 확인한다. 로그인/개발자 계정·결제 프로필·등록비가 필요한 화면에서는 이번 범위의 작업을 멈춘다. 기존 결제 기능이 열려 있지 않다면 Billing 포함 빌드의 트랙 등록 등 공식 조건을 먼저 준비해야 한다. [공식 준비 절차](https://developer.android.com/google/play/billing/getting-ready).
2. 구독 생성 화면에서 확정한 product ID·표시 이름·혜택 설명을 입력한다. 같은 혜택 구독 하나에 월간/연간 base plan을 각각 둔다. 갱신 유형은 자동 갱신, 기간은 1개월/1년이다. 이름/ID를 임의 생성하지 않으며 체험/프로모션·선불/할부를 선택하지 않는다.
3. 각 base plan에서 국가/지역·현지 가격/세금·판매 조건을 소유자가 확인한다. 월/연 혜택이 같고 연간은 연간 총 청구액으로 표시되는지 확인한다. 앱에 가격 숫자를 직접 넣는 경로는 없다. 등록/활성화/트랙 업로드는 소유자가 별도 판단해 수행할 일이다.
4. 라이선스 테스트에 본인 개발용 Google 계정을 지정하고 시험 기기의 Play 계정과 대조한다. OAuth 테스트 사용자/내부 트랙 참여자라는 사실만으로 무료 결제 테스트가 되지 않는다. 라이선스 테스터는 패키지 일치 등 조건을 충족하면 debug sideload 시험도 가능하지만 **테스트 결제수단과 테스트 표시를 확인**해야 한다. [공식 라이선스 시험 조건](https://developer.android.com/google/play/billing/test).
5. 로컬 자동 검사의 `.integration` APK는 등록 앱과 ID가 다르므로 실제 Play 상품 검사에 사용하지 않는다. 실제 라이선스 시험용은 등록 앱과 일치하는 기존 `com.example.raikeopeu2026.dev` 빌드가 필요하다. 일반 앱 데이터 초기화/삭제로 해결하지 않는다. 로컬 unsigned release 산출물도 설치/스토어 준비 완료를 뜻하지 않는다.
6. 서버 선행 조건이 갖춰지면 기존 Cloud 프로젝트의 Play Developer API와 런타임 서비스 계정을 사용한다. Play Console의 사용자/권한에서 해당 앱으로 범위를 제한한다. 공식 Billing API 안내의 `View financial data, orders, and cancellation survey responses`와 `Manage orders and subscriptions` 권한을 검토하되 전체 관리자/다른 앱/가격 변경 권한을 부여하지 않는다. JSON 개인 키를 다운로드해 앱에 넣지 않고 서버 managed identity를 사용한다. [공식 서버 API 권한](https://developers.google.com/android-publisher/getting_started).
7. RTDN은 승인 후 앱 전용 토픽과 서명된 push를 준비한다. Google Play의 공식 발행 주체에는 해당 토픽의 Publisher만 주며 앱의 push/worker 주체와 구분한다. Play의 수익 창출 설정 → 실시간 알림에서 완전한 `projects/<project>/topics/<topic>`을 입력하고 구독/철회 알림을 선택한다. 테스트 전송이 HTTPS 서버에 전달되고 정확한 OIDC 주체/audience 검증을 통과하는지 확인한다. 토픽 전송 성공만으로 구매 검증 완료가 아니다. [RTDN 공식 설정](https://developer.android.com/google/play/billing/getting-ready#configure-rtdn).

### Apple에서 직접 확인할 순서

현재는 사용자가 확인한 **무료 계정 로그인만 완료·유료 개발자 멤버십 없음** 상태를 유지한다. 아래는 멤버십/권한·Mac이 이미 준비된 이후의 절차이며 유료 가입을 유도하거나 대신 실행하지 않는다.

1. [App Store Connect](https://appstoreconnect.apple.com/)의 기존 앱에서 Bundle ID·숫자 App Apple ID를 확인한다. 로그인·Team·capability가 준비돼도 앱의 Apple 로그인 서버 검증 완료와는 별개다.
2. 구독 그룹 하나에 월/연 자동 갱신 상품을 각각 등록하고, 같은 혜택이므로 같은 서비스 수준인지 확인한다. 각 reference name·확정 product ID·기간·표시 이름/설명·현지 가격/국가·심사 메타데이터를 소유자가 입력한다. [구독 공식 구성](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/).
3. 사용자 및 액세스의 Sandbox에서 본인 개발용 테스터를 준비하고 iPhone의 Sandbox 계정으로 시험한다. 일반 Apple 계정/카드의 실제 결제로 대체하지 않는다. [Sandbox 계정 안내](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/create-a-sandbox-apple-account/).
4. Account Holder/Admin 권한에서 사용자 및 액세스 → 통합 → In-App Purchase 키를 확인한다. 기존 전용 키가 있으면 재사용 가능 여부부터 확인한다. 새 키 생성·다운로드는 별도 소유자 작업이다. Key ID/Issuer ID만 서버 공개 구성에 대조하고 개인 키는 서버 비밀 저장소에 둔다. [공식 IAP 키 위치](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/generate-keys-for-in-app-purchases/).
5. 앱 서버 알림의 Sandbox V2 URL과 운영 V2 URL을 환경별로 분리한다. Mac/Xcode·iPhone에서 StoreKit2 구매/복원·미완료 거래 재전달·갱신/만료/철회를 확인한다. Windows의 가상 검증과 StoreKit 로컬, Sandbox는 각각 별도 결과로 기록한다.

### 실제 검증 전에 필요한 9단계 조건

검증된 내부 UID·앱 세션·App Check가 정상 왕복하고 서버의 앱/환경/스토어가 기기와 일치해야 한다. 본인 A/B가 각각 로그인·전환·로그아웃할 때 이전 계정의 캐시/비동기 응답이 차단되는지도 실제 서버에서 확인해야 한다. 이메일 일치로 계정/구매를 합치지 않는다. [9단계 실제 연결 준비](ACCOUNT-LIVE-SETUP.md)의 실제 로그인·웹 삭제/Apple 철회·서버 보안 규칙/IAM 대기는 그대로다. 현재 Functions 배포의 Blaze 조건 때문에 무료 유지 범위에서 서버를 공개하지 않는다. [Firebase 공식 배포 조건](https://firebase.google.com/docs/functions/get-started).

지금 코드에서 준비한 항목은 공식 SDK·서버 검증/알림 경로·계정 격리·재시도·기본 거부·공개 주소 연결·오프라인 공개 값 점검이다. **직접 설정할 항목**은 확정 ID/국가/가격/공개 정책·개발자 계정/서명·API/IAM/Secret·RTDN/V2/worker·라이선스 테스터/Sandbox와 장비다. 월↔연 교체·탈퇴 후 정당한 구매 복구/보관 정책·제공 불가 Google 거래 대응은 콘솔 입력만으로 끝나지 않는 추가 구현/정책 항목으로 계속 남긴다.

## 지금 상태와 진행 순서

| 순서 | 필요한 조건 | 현재 |
|---|---|---|
| 1 | 실제 인증된 내부 UID·세션·App Check·앱 전용 서버/IAM | 9단계 로컬 통과, 실제 연결 대기 |
| 2 | 스토어 개발자 계정/계약·같은 앱 ID·공식 월/연 상품 | 등록/권한 상태 미확인, 상품 미정 |
| 3 | 운영자·판매 국가·현지 가격·공개 약관/개인정보/지원 URL | 사용자 확정 대기. 임시 가격/주소를 만들지 않음 |
| 4 | 공식 서버 API·구매 연결값·암호화 secret·알림/worker | 코드 준비, 실제 설정/배포 없음 |
| 5 | Play 라이선스 테스트 / Apple Sandbox | 미실행. 아래 절차는 이후 사용자 준비용 |
| 6 | 실제 갱신·만료·환불·기기 변경·재설치·부하/장애 검증 | 설정 후 같은 10단계에서 반복 |

현재 Firebase Spark 상태에서 Functions를 배포하려고 Blaze로 전환하지 않는다. 서버/알림/Cloud Scheduler·Pub/Sub의 실제 사용과 비용은 별도 검토·승인 전 실행하지 않는다. Apple은 계정 로그인만 완료했고 유료 Developer 멤버십은 없다. 회원가입/연간 회비를 대신 결제하지 않는다.

## Google Play — 사용자가 준비할 항목

접속: [Google Play Console](https://play.google.com/console/). 기존 개발자 계정과 AIRZERO STRIKE 앱이 있는 경우 재사용한다. 계정/앱이 없거나 결제 프로필·등록비가 요구되면 현재 작업에서는 진행하지 않는다. 앱 ID `com.example.raikeopeu2026.dev`와 실제 서명/스토어 등록 가능 여부를 먼저 확인하며 임의로 ID를 바꾸지 않는다.

| 순서 | 화면 / 입력 항목 | 설정 기준 |
|---|---|---|
| 1 | 해당 앱 → 수익 창출 → 상품 → 정기 결제 | 동일 혜택의 구독 상품1개. **product ID는 사용자 확정값**, 현재 없음 |
| 2 | 구독 → 기본 요금제 | 월간/연간 각각의 base plan ID와 자동 갱신 기간1개월/1년. 동일 혜택 유지 |
| 3 | 판매 국가·가격·세금·상품 조건 | 스토어가 제공할 현지 총 청구액. 선불/할부·무료 체험·프로모션/할인은 이번 모델에 추가하지 않음 |
| 4 | 설정 → 라이선스 테스트 | 본인 소유 개발 테스트 Google 계정만 등록. 실제 사용자 이메일을 테스트 대상으로 쓰지 않음 |
| 5 | 시험 휴대폰의 Play 계정 | 등록한 라이선스 테스터로 테스트. OAuth 테스트 사용자와 Play 라이선스 테스터는 별도 |
| 6 | 결제창의 수단 | **테스트 카드: 항상 승인/항상 거절**, 지연 승인/거절 등 공식 테스트 수단만 사용. 일반 카드/실제 청구 표시라면 취소 |
| 7 | Google Play Developer API / 서버 계정 권한 | 해당 앱 구독 조회·ack에 필요한 최소 권한. 다른 앱·가격 변경·전체 관리자 권한을 주지 않음 |
| 8 | 수익 창출 설정 → 실시간 개발자 알림 | 앱 전용 Pub/Sub 토픽/서명된 push·RTDN 구성. 프로젝트/주체/audience를 아래 서버 계약과 일치 |
| 9 | 내부 시험 트랙·서명 / 기기 설치 | 스토어에서 요구하는 등록/빌드·상품 활성화와 라이선스 테스트 조건을 공식 문서대로 사용자 수행. 업로드/테스트 배포는 대신 실행하지 않음 |

라이선스 테스터의 개발 빌드 시험 조건과 콘솔 상품 설정/빌드 요건은 별도로 확인한다. 일반 Android 에뮬레이터에서 SDK가 응답했다고 라이선스 테스트가 끝난 것은 아니다. [Play 준비/RTDN](https://developer.android.com/google/play/billing/getting-ready), [공식 결제 테스트](https://developer.android.com/google/play/billing/test).

테스트 순서는 승인 → 취소 → 거절 → 지연 승인/거절 → 앱 강제 종료 후 알림/재시작 → 복원 → 갱신/갱신 중단/유예/보류/만료/공식 철회다. 서버와 같은 내부 UID/스토어 계정을 확인하고 거래 원문은 공유하지 않는다. 새 구매 token은 제공 후 acknowledge가 필요하며 공식3일 기한은 PENDING에서 PURCHASED로 바뀐 뒤 시작한다. 테스트 환경의 단축 기한도 확인한다. 구독에는 consume을 호출하지 않는다. [공식 생명주기](https://developer.android.com/google/play/billing/lifecycle/subscriptions).

## Apple — 멤버십·Mac 준비 이후

접속: [App Store Connect](https://appstoreconnect.apple.com/). 현재 유료 멤버십이 없어 앱/상품/Sandbox 작업을 완료하지 못했다. 무료 Apple 계정 로그인·Sign in with Apple·App Store 결제 키는 서로 다른 준비 항목이다.

| 순서 | 화면 / 입력 항목 | 설정 기준 |
|---|---|---|
| 1 | 기존 앱 / Bundle ID·App Apple ID | 기존 앱과 `com.example.raikeopeu2026.dev` 식별자 유지, 실제 App Apple ID 확정. 중복 앱 생성 안 함 |
| 2 | 앱 → 구독 → 구독 그룹 | 동일 서비스 수준의 그룹1개, 월간/연간 auto-renewable 상품 각각. group ID·product ID 확정 |
| 3 | 상품의 기간/가격/국가/약관 | 1개월/1년, 동일 혜택, 실제 지역별 총 청구액. 소개 혜택/체험·프로모션은 없음 확인 |
| 4 | 사용자 및 액세스 → Sandbox → 테스터 | 본인 개발용 Sandbox 계정. 실제 사용자나 일반 카드 결제 시험을 하지 않음 |
| 5 | 실제 iPhone → 개발자/Sandbox Apple 계정 | OS 버전의 공식 경로에서 Sandbox 계정 사용. 구매창에 Sandbox임을 확인 |
| 6 | 통합/API 키 → In-App Purchase 서버 API | 별도 승인 후 전용 IAP 키/Key ID/Issuer ID. private key는 서버 Secret Manager에만 보관. 로그인용 Apple 키와 혼용하지 않음 |
| 7 | 앱 서버 알림 | 개발은 Sandbox Notifications V2 URL, 운영은 별도 환경. 아래 `/v1/billing/notifications/apple` 경로로 서명 검증/재조회 |
| 8 | Mac/Xcode | StoreKit2 native 빌드·서명·실제 기기/미완료 거래 큐 확인. Windows 검증으로 대체하지 않음 |

StoreKit 로컬 시험은 Xcode의 전용 시험 구성으로 UI/상태를 검증하는 별도 층이다. 로컬 Xcode 거래/JWS를 실제 Sandbox/Production 서버 권한으로 허용하지 않는다. 현재 로컬 StoreKit도 미실행이며 릴리즈에 모의 상품/우회 토글을 넣지 않았다. [Sandbox 계정 생성](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/create-a-sandbox-apple-account/), [Apple Sandbox 안내](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox).

Apple 거래 완료는 서버 검증/제공 뒤 SDK completePurchase로 실행한다. 실패/앱 종료 시 미완료 큐를 다시 받는다. StoreKit2/실제 Sandbox 콜백 재전달·finish 실패 재시도·철회 반영은 기기 검증 대기다. 기존 계정과 다른 appAccountToken/Family Sharing은 자동으로 귀속하지 않는다.

## 서버 설정 계약 — 현재 미설정, 비밀값 공유 금지

아래는 **서버** 설정이다. 모바일 Dart define/공개 JSON에 관리자 키나 아래 secret을 넣지 않는다. 기존 [인증 서버 계약](../server/firebase/README.md)의 project/dev/prod/region/App Check/service account와 함께 구성한다. 상품 값을 확정하기 전에는 빈 값과 기본 거부를 유지한다.

| 이름 | 값/역할 |
|---|---|
| AIRZERO_BILLING_READY | 기본 미설정/false. 준비 플래그만 켜서 구매 성공으로 만들지 않음 |
| AIRZERO_BILLING_NOTIFICATIONS_READY | 실제 RTDN/V2·worker 실행/감시/실패 재시도 확인 후에만 검토 |
| AIRZERO_BILLING_POLICY_READY | 공식 공개 약관/개인정보/지원·상품 가격/조건·무체험 모델 확인 |
| AIRZERO_BILLING_RETENTION_READY | 구매/가명 소유권 표식의 보관 근거·기간·물리 정리 정책 검증. 현재 미완료 |
| AIRZERO_BILLING_SEAL_KEY | **서버 Secret**, 암호학적 임의32 bytes를 base64로 보관. 사용자 비밀번호 관리자/Secret Manager에서만 다루고 값을 명령 인수·소스·채팅·로그에 넣지 않음 |
| AIRZERO_PLAY_SUBSCRIPTION_ID | 확정한 Play 구독 product ID |
| AIRZERO_PLAY_MONTHLY_PLAN / AIRZERO_PLAY_ANNUAL_PLAN | 동일 구독의 서로 다른 월간/연간 base plan ID |
| AIRZERO_PLAY_PUSH_EMAIL | 앱 전용 `airzero-billing-push-…@<project>.iam.gserviceaccount.com` |
| AIRZERO_PLAY_PUSH_AUDIENCE | 정확한 `https://<region>-<project>.cloudfunctions.net/api/v1/billing/notifications/play` |
| AIRZERO_BILLING_WORKER_EMAIL | 별도의 `airzero-billing-worker-…@<project>.iam.gserviceaccount.com` |
| AIRZERO_BILLING_WORKER_AUDIENCE | 정확한 `https://<region>-<project>.cloudfunctions.net/api/v1/billing/maintenance` |
| AIRZERO_APPLE_MONTHLY_PRODUCT / AIRZERO_APPLE_ANNUAL_PRODUCT | 확정한 Apple 월간/연간 product ID |
| AIRZERO_APPLE_SUBSCRIPTION_GROUP / AIRZERO_APPLE_STORE_APP_ID | 실제 구독 그룹 숫자 ID / 앱 숫자 ID |
| AIRZERO_APPLE_IAP_KEY_ID / AIRZERO_APPLE_IAP_ISSUER_ID | 서버 IAP 키 식별자 / Issuer UUID |
| AIRZERO_APPLE_IAP_PRIVATE_KEY | **서버 Secret**, 공식 P-256 IAP 개인 키. 실제 파일/값은 AI 작업 범위에서 읽지 않음 |

서버 Secret은 배포/런타임 바인딩까지 필요하다. 파일/표 작성만으로 실제 적용하지 않았다. 현재 프로젝트는 Functions 과금 조건 때문에 서버 배포도 대기다. [Firebase 배포 조건](https://firebase.google.com/docs/functions/get-started).

RTDN push는 지정한 Google 서명 OIDC의 issuer/audience/email_verified/email을 검증하고 Apple V2는 Apple 서명/앱/환경을 검증한다. 알림의 상태·시간 순서를 거래 진실로 쓰지 않는다. 유지보수 HTTP도 별도 OIDC 주체만 허용한다. 스케줄러/토픽·push·IAM·HTTPS 공개·감시·Firestore billingLimits TTL과 구매 데이터 물리 정리는 코드와 별도의 실제 설정 대기다. 공개 webhook 경로가 있다고 개인 API/App Check/DB 규칙을 전체 허용으로 바꾸면 안 된다.

검증할 실제 운영 경계는 **dev=Play testPurchase/Apple Sandbox**, **prod=실제 Production**이다. 상품/환경 불일치·미선택 offer/선불/할부는 허용하지 않는다. 현재 API는 dev 앱 식별자를 유지하므로 출시 식별자·서명/계약 확정 없이 운영 활성화하지 않는다.

## 계정·복원 정책

- 구매 시작 전 검증된 앱 내부 UID에 서버 UUID를 귀속한다. 소셜 이메일이 같다는 이유로 묶지 않는다.
- 같은 UID·같은 스토어 계정의 재설치/기기 변경은 공식 구매 재조회와 기존 서버 귀속으로 복원한다. 기기 기록 복원은 별개다.
- 다른 앱 UID/스토어 계정/다른 OS는 자동 이전하지 않는다. 원래 계정 복원을 안내한다.
- 탈퇴 뒤 재가입은 새 UID다. 이전 구매를 이메일/로컬 영수증으로 가져오지 않는다. 정당한 보유자의 지원 복구 정책/본인 증명·최소 보관 처리는 추가 구현/확정 대기다.
- 같은 혜택의 중복 구매를 막고 활성/유예/대기 거래가 있으면 새 구매를 시작하지 않는다. 이번 단위의 앱 내 월↔연 전환은 미구현이며 새 상품을 별도 구매해 중복 청구하도록 우회하지 않는다.
- 로그아웃·만료·환불은 게임 기록 삭제가 아니다. 계정 탈퇴와 스토어 갱신 중단/환불도 별개다. 구독 중이라는 이유로 즉시 탈퇴를 막지 않는다.
- 미검증·제공 불가 거래의 실제 취소/환불 쓰기는 이번 앱에 연결하지 않았다. 특히 다른 계정이 제시한 참조만으로 원래 소유자의 거래를 환불하면 안 된다. 실제 보유 확인·정당한 제공 불가 대응의 빠른 취소/환불은 같은 단계의 후속 구현/실검증 항목이다.

## 로컬 재현과 완료 기준

앱 폴더: `flutter analyze --no-pub`, `flutter test --no-pub`.
서버 폴더: `npm.cmd run build`, `npm.cmd test`, `npm.cmd run test:emulator`.
Android: 기존 `test:native-core` / `test:native-email`의 별도 integration 앱과 demo runner만 사용한다. 일반 앱을 지우거나 실제 스토어 결제창을 호출하는 자동 검사는 없다.

로컬 가상 통과, 네이티브 채널/빌드 통과, StoreKit 로컬, Play 라이선스/Sandbox, 실제 운영 결제는 서로 다른 완료 항목이다. 이번에는 뒤 세 가지를 완료로 표시하지 않는다. 실제 테스트 조건이 갖춰지면 10단계를 반복하며 11단계로 자동 이동하지 않는다.

정책 기준은 [Google 결제 정책](https://support.google.com/googleplay/android-developer/answer/9858738?hl=ko), [Apple IAP/구독 지침](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)이다. 한국/다른 국가의 예외 프로그램·외부 결제 유도는 선택하지 않았다. 판매 국가/프로그램을 확정하면 최신 요건을 다시 확인하며 원치 않는 별도 결제수단을 추가하지 않는다.
