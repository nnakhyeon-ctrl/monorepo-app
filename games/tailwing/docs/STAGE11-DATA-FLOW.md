# 11단계 실제 데이터 흐름 대조

2026-10-28. 내부 검토 자료다. 공개 개인정보처리방침/스토어 제출 파일이 아니며 최종 검증 완료가 아니다. **소스·로컬 전송 대역/가상 서버·Android 실행과 실제 공급자/운영 검증을 구분**한다.

## 시점·목적지·전송 항목·보관

| 시점/동작 | 목적지·필요 항목 | 저장/제한·검증 범위 |
|---|---|---|
| 앱 시작/로그인 복구 | 공개 설정이 있으면 Firebase Core/Auth/App Check 초기화·SDK 인증 복구. UID가 있으면 앱 session/progress/profile/import 조회 | 설정 누락은 Firebase 초기화 전에 거부. 계정 메뉴를 누르지 않아도 복구가 시도됨. 실제 attestation/SDK 자동 통신은 미검증 |
| 무료 전투/기록/설정 | 내장 이미지·음향과 로컬 파일. 선택 통계도 기기 내 허용 집계만 | schema1 두 사본·revision/체크섬. 선택 ID는 권한 아님. 모든 전투 자동 업로드 없음. 호스트/Android 검사 |
| 앱 이메일 API | `https://<region>-<project>.cloudfunctions.net/api/v1/auth/...`; 동작별 이메일·비밀번호/일회용 코드·고정 복귀 주소 등 | Firebase Auth에 필요한 범위로 전달. 비밀번호 DB/게임 파일/자체 관리 로그에 보관 안 함. 실제 메일 발송 미검증 |
| Firebase Auth SDK | 공식 인증/갱신 서비스에 이메일/비밀번호·ID/refresh token·보안 메타데이터 | SDK 자체 세션 보관과 앱 vault는 별개. Android demo 왕복/로그아웃 확인, 실제 서비스·iOS 잔존/키체인/재설치 미검증 |
| App Check | Firebase App Check·Play Integrity 또는 Apple App Attest/DeviceCheck에 무결성/SDK 메타데이터 | 실제 API는 app ID·SDK token·App Check·앱 세션 검증. provider 선택/기본 거부 소스·가상 검사, 실제 증명/갱신은 미검증 |
| Google/Kakao/Apple 선택 로그인 | 공식 SDK/계정 UI 및 앱 social challenge. 종류별 token·state/nonce | subject로 내부 UID 연결. 이메일 일치 병합/필수 전화번호·사진/이름 요구 없음. Kakao 앱 token manager는 RAM·logging=false·종료 clear. 실제 공급자 UI/SDK 보관 미검증 |
| 서버 소셜 검증 | Google 공개 인증서, Kakao `kauth.kakao.com` JWKS / `kapi.kakao.com/v1/user/access_token_info`, Apple `appleid.apple.com/auth/keys` | JWT/opaque access token을 분리 검증. issuer/audience/대상 앱/만료·nonce·grant/UID 매핑 검사. 합성 proof이며 실제 token 사용 안 함 |
| 개인 API/최초 게스트 보관 | 위 앱 전용 Functions에 SDK ID token·App Check·불투명 세션, 동의한 bounded 기록/설정·revision/generation/operation ID | 앱/환경/UID별 서버와 UID/환경/세대별 로컬 캐시. 충돌 양쪽 보존·자동 합산 없음. 전체 전투 동기화/실제 두 기기는 미완료 |
| 구매/복원 | 준비 시에만 Play Billing/StoreKit2와 앱 status/intent/verify. 서버 UUID 계정 연결값·상품 ID·구매 참조 | 서버 암호화 원장·스토어/계정 귀속, 앱 권한은 RAM 최대2분 기한에 요청 대기시간 차감. SDK 자체 큐/캐시는 별도. 실제 상품/스토어 미검증 |
| 서버 결제/알림 | Google `androidpublisher.googleapis.com` / Apple 공식 환경별 Server API. RTDN OIDC / Apple V2 JWS | 공식 canonical 상태 재조회·멱등 처리·제공 후 ack/거래 완료. 가상 역순/중복/만료/철회 검사, 실제 API/IAM/Secret/worker·OCSP 미검증 |
| 신고/외부 링크 | 사용자 입력 순서/현상 각800자+버전을 명시적 복사 때 OS 클립보드로. 허용 URL은 탭으로 외부 앱 열기 | 자동 문의·원본 로그/계정정보 첨부 없음. 닫으면 controller 정리. OS 클립보드는 별도. 로컬 복사·허용 주소·실패 검사, 실제 외부 앱/클립보드 기록은 미검증 |

전송 코드의 실제 경로/방식·HTTPS·인증 헤더·redirect=false·32KiB 요청/64KiB 응답·안전 오류를 HTTP 대역으로 검사했다. Android 공식 Auth SDK는 demo 왕복으로 구분한다. 실제 공급자/클라우드 패킷을 캡처해 모두 확인한 것은 아니다. Firebase의 IP/설치/보안 메타데이터 처리 가능성을 ‘수집 없음’으로 바꾸지 않는다. Auth와 DB/Functions 위치도 동일하다고 가정하지 않는다. [Firebase 개인정보/보안](https://firebase.google.com/support/privacy), [설치 ID 설명](https://firebase.google.com/docs/projects/manage-installations).

## 삭제·캐시·백업·화면 대조

- 앱 OS vault는 앱/프로젝트/환경별 UID·불투명 세션·만료/세대와 이미 동의한 삭제 재시도 확인값을 보관한다. SDK 로그아웃 실패 후 자동 재연결을 막는 상수 표식도 보관하며 명시적 로그인 성공 시 제거한다. 비밀번호/Firebase refresh token/구매 권한 저장소가 아니다. Android namespace·resetOnError=false, iOS unlocked_this_device·synchronizable=false를 사용한다. SDK 별도 보관까지 모두 vault 암호화라고 주장하지 않는다.
- 탈퇴는 최근 재인증·최종 동의 뒤 접근 차단→앱 자료/세션/매핑·Auth 사용자·기기 캐시 정리/재시도다. 다른 앱/UID/게스트 원본을 삭제하지 않는다. 실제 전용 Auth 프로젝트/worker·지원 처리 기한 확인은 대기다.
- 구매 정리는 재사용 가능한 암호화 참조·UID·연결 인덱스를 제거하고 임의 재귀속 방지용 가명 표식을 남긴다. 보관 근거/기간·지원 복구·물리 정리 정책 미확정이며 실제 삭제/결제는 비활성이다. 논리 만료는 TTL/운영 백업 삭제 완료가 아니다.
- Android는 backup/fullBackup/cleartext=false·cloud/device transfer 제외와 release FLAG_SECURE를 사용한다. 기본 비생체 vault에 불필요한 USE_BIOMETRIC/USE_FINGERPRINT의 간접 병합을 제거했다. SDK가 추가한 네트워크 상태·Billing·reCAPTCHA의 READ_GSERVICES·내부 signature receiver 권한은 기능/보안 라이브러리 출처를 확인했다. manifest 존재가 실제 과금·데이터 처리 검증을 대신하지 않는다. 실제 OS 백업/화면 공유·공급자 화면은 별도 검증이다. debug 가상 검사에는 가상 자료만 사용한다.
- Flutter 배경 가림막은 계정 화면의 접근성 정보도 제외하도록 보완했고 연결된 semantics 트리로 검사한다. iOS는 공통 코드/ATS 소스 확인이며 native build·snapshot/녹화·키체인/backup은 미검증이다. iOS 스크린샷 전체 차단을 주장하지 않는다.
- 수동 신고 복사는 승인한 입력만 포함한다. 사용자가 비밀을 직접 입력할 수 있으므로 입력 금지 안내를 유지한다. 기기 클립보드 전체를 임의로 읽거나 비밀을 분석 서비스에 보내지 않는다.

## 공개 고지/스토어 대기

앱과 비공개 초안의 전체 자동 동기화·게스트 임시 구매·구매 원장 미구현 표현을 현재 구현/대기로 구분했다. 운영자 연락처·처리 지역/위탁/국외 이전·보관 예외/기간·실제 권리 행사·HTTPS 공개 주소가 미확정이다. 공개 양식은 미제출이고 ‘수집 없음’을 선택하지 않았다.

[Play 데이터 안전](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)·[Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/)는 제3자 SDK도 포함해 대조한다. 실제 설정 빌드의 요청/지역·제공자 로그/백업과 Xcode의 SDK Privacy Manifest/required-reason 집계를 확인하기 전 최종 수집/공유 선언을 확정하지 않는다. 제출용 최종 파일은 12단계에서 별도 준비한다.
