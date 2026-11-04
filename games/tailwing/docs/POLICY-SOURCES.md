# 공식 출처·판단·미검증 기록

확인일: 최초 2026-10-17, 구독·관리자 가격 흐름 갱신 2026-10-18, 한국 시간. 다음은 공개된 공식 문서 확인 결과이며 심사 승인·계정 설정·실결제/실메일 검증 결과가 아니다. 정책·요금·SDK 지원은 바뀔 수 있으므로 연동 도입 및 제출 파일 준비 단계에서 다시 확인한다.

## iOS 로그인·계정

[Apple App Review Guidelines 4.8](https://developer.apple.com/app-store/review/guidelines/#login-services)은 주요 앱 계정에 소셜 로그인을 쓸 경우 최소 정보·이메일 비공개 선택·동의 없는 광고 목적 상호작용 수집 제한을 갖춘 동등 옵션을 요구한다. 이 앱은 iOS Sign in with Apple을 그 옵션으로 계획한다. 자체 인증만 쓰는 경우, 대체 마켓 전용 계정, 기존 조직/학교 계정이 필수인 앱, 정부/산업 신원 인증, 특정 외부 서비스의 전용 클라이언트 등 예외를 확인했으나 현재 게임은 어느 예외에도 해당한다고 판단할 근거가 없다. 사용자가 직장인/대학생이라는 사실만으로 조직/교육 계정 예외를 적용하지 않는다.

동일 지침 5.1.1(v)를 고려해 기본 로컬 플레이는 계정·구독 없이 유지하며, 2026-10-18 요청으로 추가한 계정 기반 기록 동기화에는 계정 연결을 요구한다. 이메일·소셜 로그인과 임시 구매 세션을 구분하고 최신 요청의 기본 무료 + 추가 콘텐츠 월간/연간 구독을 따르며 동기화 자체를 별도 과금하지 않는다.

[Apple 앱 내 계정 삭제 안내](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion)에 따라 삭제 시작 경로·연결 데이터 정리·Apple 인증 철회를 계획한다. 월간/연간 구독 관리·해지 안내와 즉시 계정 삭제 선택을 제공하며 만료까지 계정 삭제를 강제 지연하지 않는다. 앱 계정 삭제가 구매 취소/환불을 뜻한다고 안내하지 않는다.

## 스토어 결제·삭제

- [Apple 3.1.2 구독](https://developer.apple.com/app-store/review/guidelines/#subscriptions), [Google 구독 정책](https://support.google.com/googleplay/android-developer/answer/9900533?hl=en): 구독 기간에 지속/반복 이용 가치를 제공한다. 일회성 코인/소모성 보너스만으로 구독을 구성하지 않고 기본 무료 범위·혜택·총 청구액·주기·갱신/해지를 명확히 안내한다.
- [Apple 구독 가격 관리](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions), [Google 구독/base plan 관리](https://support.google.com/googleplay/android-developer/answer/140504?hl=en): 관리자 사용자가 최종 검토 후 콘솔에서 가격을 설정/변경하고 앱은 공식 지역화 가격을 읽는다. 기존 구독자 가격 변경/동의 조건도 공식 절차를 따른다. 현재 콘솔/가격 변경은 실행하지 않았다.

- [Apple 디지털 기능 결제](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase), [Google Play 결제 정책](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en): 핵심 게임 디지털 이용권은 각 스토어 결제를 기본으로 선택. 국가/프로그램별 예외가 있으므로 출시 국가를 확정한 뒤 자격/약관을 확인하며 현재 외부 결제를 도입하지 않음.
- [Google Play 계정 삭제 요구](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en): 계정 생성 앱의 앱 안 삭제와 외부 웹 요청 경로·연관 데이터·정당한 보관 예외를 검토. Markdown 안내 초안만으로 작동하는 삭제 요청 경로를 갖췄다고 표시하지 않음.
- [Play 구매 보안](https://developer.android.com/google/play/billing/security), [결제 통합](https://developer.android.com/google/play/billing/integrate): 구매 증명을 서버 검증하고 권한 반영/acknowledge를 처리. 구매 대기를 성공으로 처리하지 않고 구독 최초 구매 acknowledge·갱신/복원·환경/소유 검증을 구분하고 중복 가입을 방지함.
- [Play 구독 생명주기](https://developer.android.com/google/play/billing/lifecycle/subscriptions), [Apple 구독 상태](https://developer.apple.com/documentation/AppStoreServerAPI/Get-All-Subscription-Statuses): 자동 갱신 중단과 잔여 이용권, 만료, 공식 유예, 재시도/계정 보류, 철회를 구분하는 현재 구독 설계 기준으로 적용. 실제 연동은 10단계이며 기본 무료 경로는 유지함.
- [Play 결제 테스트](https://developer.android.com/google/play/billing/test), [Xcode StoreKit 테스트](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode): 로컬/mock와 실제 샌드박스·라이선스 테스터 검증을 분리. Windows에서 iOS StoreKit 테스트가 끝났다고 표시하지 않음.

## 인증·메일·데이터·호스팅

| 공식 문서 | 계획에 반영한 내용 |
|---|---|
| [Firebase Auth Emulator](https://firebase.google.com/docs/emulator-suite/connect_auth) | demo- 프로젝트, 가상 사용자, 확인/복구 URL을 통한 로컬 이메일 흐름. 실제 메일함 전달은 별도 검증 |
| [Firebase Flutter 공급자 인증](https://firebase.google.com/docs/auth/flutter/federated-auth) | Google·Apple 준비, nonce·토큰 철회, 공급자 연결을 실제 삭제 흐름에 포함 |
| [Firebase custom token](https://firebase.google.com/docs/auth/admin/create-custom-tokens), [ID token 검증](https://firebase.google.com/docs/auth/admin/verify-id-tokens) | Kakao 교환은 서버에서 수행하고 Firebase 내부 UID를 기준으로 권한 검사 |
| [Firebase 임시 인증](https://firebase.google.com/docs/auth/flutter/anonymous-auth) | 회원가입 없는 구매 검증 세션과 이후 명시적 계정 연결을 위한 설계 선택 |
| [Kakao 공식 API/OIDC](https://developers.kakao.com/docs/en/kakaologin/rest-api) | 서명/JWKS·issuer·사용 키의 aud·nonce·만료 검증. 이메일 부재 허용·디버깅 API와 운영 검증 구분 |
| [Firebase 개인정보 처리](https://firebase.google.com/support/privacy) | Auth/서버 메타데이터 처리 가능성, 제공자 보관과 앱 직접 저장을 구분 |
| [Firebase 가격](https://firebase.google.com/pricing), [Functions 준비](https://firebase.google.com/docs/functions/get-started) | 인증/실행/DB/네트워크/보관 비용과 운영 과금 준비를 구분. 플랜 가입 미실행 |
| [Cloudflare 정적 HTML](https://developers.cloudflare.com/pages/framework-guides/deploy-anything/), [Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/) | 공개 문서용 로컬 산출물 계획과 사용자의 공개 절차. AWS 구성 불필요 |
| [Flame 공식 저장소](https://github.com/flame-engine/flame) | Flutter 기반 루프·충돌·입력·애니메이션 엔진 선택, 도입 시 호환 버전/라이선스 확인 |
| [Google 버튼](https://developers.google.com/identity/branding-guidelines), [Kakao 버튼](https://developers.kakao.com/docs/ko/kakaologin/design-guide), [Apple 버튼](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple) | 기본 흑백 UI와 공급자별 공식 디자인/동등 노출을 함께 고려 |

## 2026-10-18 서버 저장 설계 추가 확인

[Firestore 오프라인](https://firebase.google.com/docs/firestore/manage-data/enable-offline)에서 동일 문서의 마지막 쓰기 우선 동작을, [트랜잭션](https://firebase.google.com/docs/firestore/manage-data/transactions)에서 재시도·원자성·오프라인 클라이언트 제약을 확인했다. 이에 따라 계정 게임 저장은 서버 API·revision/세션·멱등 정산·로컬 대기열로 설계한다. [규칙/IAM](https://firebase.google.com/docs/firestore/security/rules-conditions)은 Admin SDK 서버에도 별도 권한 검증이 필요함을, [삭제 문서](https://firebase.google.com/docs/firestore/manage-data/delete-data)는 하위 자료 명시적 삭제가 필요함을 설명한다. [과금 문서](https://firebase.google.com/docs/firestore/pricing)를 기준으로 기록 읽기/쓰기·삭제·보관 비용도 포함했다. 이는 공식 동작을 바탕으로 선택한 설계이며 실제 동기화 검증 결과가 아니다.

## 아직 확인하지 않은 것 (갱신)

실제 공급자 프로젝트·키/도메인/서명·상품 가용성·샌드박스 거래·메일 수신·실제 SDK 자동 수집/패킷·최종 개인정보/등급/국가별 보관 의무·명칭/자산 권리·Mac 빌드·게임 성능은 미검증이다. 제안 식별자는 외부 예약/등록된 값이 아니다. 사용자 계정이나 비밀을 조사하지 않고 미확인으로 기록했다.
