# 7단계 이메일 인증 결과

2026-10-19. AIRZERO STRIKE 한 앱의 기존 Firebase 기반과 계정 화면을 확장했다. 무료 게스트 전투·기기 진행/설정·앱 식별자는 유지했다. 소셜 로그인·스토어 결제·계정 삭제·전체 게임 동기화는 이번 단계에서 구현하지 않았다. 클라우드 가입/설정/배포·운영 DB 변경·실사용자 메일 발송도 하지 않았다.

## 구현한 흐름

- 환경설정 → 계정 → 이메일 가입/로그인. 기존 폼/경로를 재사용하고 비밀번호 재설정·이메일 링크 확인·재인증 후 이메일 변경을 연결했다.
- 가입은 서버에서 입력/동의/속도 제한을 검사한 뒤 Firebase Admin으로 생성하고 공식 Auth API로 확인 메일을 요청한다. 가입만으로 앱에 로그인하지 않는다. 중복 가입도 동일한 접수 안내를 표시하며 로그인/복구로 이동할 수 있다.
- 로그인은 공식 FlutterFire SDK로 처리한다. 미확인 계정은 확인 안내/재전송/상태 갱신만 이용하며 서버의 개인 게임 데이터는 거부된다. 서버가 검증한 UID와 세션을 확인하고 OS 보호 저장소에 보관한 뒤에만 계정 연결 완료로 표시한다.
- 재설정은 존재 여부와 관계없이 동일한 접수 응답을 사용한다. Firebase가 발급/검증/소비하는 코드만 허용하며 별도의 토큰/비밀번호 DB를 만들지 않았다. 완료 뒤 SDK 인증/기기 세션을 지우고 새 비밀번호로 직접 로그인하게 한다. 자동 로그인하지 않는다.
- 이메일 변경은 현재 비밀번호로 SDK 재인증하고 서버에서 최근 5분 인증을 확인한다. 새 주소 확인 전에는 기존 주소를 유지하고 확인 완료 후 이전 세션을 폐기한다. 승인된 계정 연결 없이 소셜 계정에 비밀번호를 추가하는 경로는 제공하지 않으며 서버에서도 차단한다.
- 비밀번호 표시/숨기기·붙여넣기·자동완성/비밀번호 관리자용 필드를 사용한다. 전화번호·별도 로그인 ID·실명·생년월일을 요구하지 않는다. 오류는 안전한 고정 문구로 안내하고 재시도/뒤로가기를 제공한다.

## 기기 기록과 계정 기록

로그인/가입/로그아웃/재설정이 기기 세이브 파일이나 설정을 바꾸지 않는다. 현재 전투는 계속 기기 기록을 사용한다. 계정 화면에서는 서버 기록 수를 별도로 표시한다.

빈 계정일 때만 사용자가 명시적으로 동의해 클리어·최고점수·시도 수를 최초 보관한다. UID는 요청 본문에서 받지 않는다. 6단계 revision/generation/CAS/작업 ID 규칙을 그대로 사용하고 충돌 시 양쪽 원본을 유지한다. 설정·재화·유료 권한은 이 가져오기에 포함하지 않는다. 이후 전투 자동 업로드나 서버 기록의 기기 덮어쓰기는 추가하지 않았다. [기반 결과](AUTH-BACKEND-RESULTS.md), [저장 설계](CLOUD-SAVE.md).

재설정/이메일 변경 시 Firebase refresh token 철회와 앱 서버의 `authEpoch` 증가를 함께 처리한다. 기존 세션 핸들은 새 ID token과 조합해도 거부하며 게임 데이터의 generation/기록은 보존한다. 로그아웃 중 늦게 도착한 초기화/로그인 응답이 다음 계정을 되살리지 않도록 이전 작업 정리를 기다린다. [공식 세션 철회 설명](https://firebase.google.com/docs/auth/admin/manage-sessions).

## 보안과 적용 범위

| 항목 | 코드/로컬 구현 | 실제 운영 적용 |
|---|---|---|
| 전송/권한 | cloud HTTPS·App Check·검증된 Firebase ID token·UID별 서버 세션, private Firestore 직접 접근 기본 거부 | 실제 프로젝트/IAM/규칙/App Check/인증서 경로 미검증 |
| 비밀번호 | 새 비밀번호 15자 이상/4096 UTF-16 코드 단위 이내, 조합/주기 변경 강제 없음. 서버의 공통 비밀번호 거부 목록. 로그인은 기존 비밀번호 길이를 재강제하지 않음 | Firebase 정책·직접 공급자 API/기본 웹 handler 우회까지 포함한 차단은 설정/직접 검증 대기 |
| 메일 남용 방지 | 출처 20회/15분, 계정+작업 5회/15분·60초 간격. 코드 검사는 출처 기준 20회/15분. HMAC 식별자로 저장, 영구 잠금 없음 | 공급자 자체 로그인 제한·enumeration 보호·reCAPTCHA·실제 프록시 출처 해석/분산 공격 방어 미검증 |
| 존재 노출 완화 | 가입/복구/주소 변경의 접수 응답·200 코드 통일, 800~900ms 최소 응답 시간, 계정 제한도 동일 접수 | 실제 공급자 응답 시간 차이/직접 API/메일 전달 관찰까지 없앤다는 보장은 아님 |
| 링크 | 고정 프로젝트/HTTPS 호스트·경로·API key·mode·복귀 주소만 허용, 중복/추가 쿼리 거부. 코드는 POST 본문만 사용하고 로그에 기록하지 않음 | 실제 메일 도착·짧은 만료 시간·App/Universal Link·웹 Referrer/분석/접근 로그 통제 미검증 |
| 저장/로그 | 비밀번호·OOB/ID/refresh token을 자체 파일/DB/로그에 보관하지 않음. SDK 네이티브 인증 보관과 앱 세션 보호 저장소 분리. API 로그는 고정 오류 코드/상태만 | SDK의 iOS 재설치/Keychain 잔존·실기기 백업/비밀번호 관리자 동작 미검증 |

서버에서 가입/재설정 시 새 비밀번호를 메모리로 받아 Firebase로 즉시 전달한다. 로그인/재인증 비밀번호는 공식 SDK로 전달한다. 자체 평문·복호화 저장·단순 SHA 계정 인증 테이블은 없다. 비밀번호의 실제 인증 저장/해시는 Firebase가 관리한다. 서버 응답 유실 등으로 완료 확인이 안 되면 성공으로 꾸미지 않으며 새 인증 정보 로그인/새 링크 요청으로 회복하도록 안내한다.

`emailLimits`에는 HMAC 처리한 출처/계정별 카운터와 만료 시각만, `passwordAccounts`에는 앱 서버에서 생성한 이메일 계정의 UID/출처/생성 시각만 저장한다. 원본 IP/이메일/비밀번호/메일 코드는 없다. 만료된 제한은 논리적으로 풀리지만 Firestore TTL/정리 작업은 운영에 적용하지 않았다. 계정 삭제 시 관련 서버 문서 정리도 이후 삭제 단계에서 함께 구현해야 한다.

## 로컬 실행

서버 폴더 `server/firebase`에서 PowerShell로 실행한다. 정상 앱은 설정이 없으면 ‘연결 준비 중’으로 안내하며 무료 플레이를 제공한다.

```powershell
npm.cmd run build
npm.cmd test
npm.cmd run test:emulator
npm.cmd run test:native-email
npm.cmd run test:native-core
```

수동 로컬 확인은 `npm.cmd run dev:emulator`를 실행한 상태에서 VS Code의 **AIRZERO STRIKE · 이메일 로컬 시험**을 사용한다. 이 프로필은 debug 전용 고정 `demo-airzero-strike`에만 접속한다. 기존 기기에 실계정이 있어도 시험에는 `example.test` 가상 주소만 사용한다. 에뮬레이터는 실제 이메일을 발송하지 않는다. 메일 코드/토큰을 터미널·문서·지원 문의에 복사하지 않는다. 현재 앱의 링크 확인은 사용자가 직접 붙여넣는 방식이며 자동 딥링크 복귀가 배포됐다는 뜻이 아니다.

자동 Android 검사는 `.integration` 앱 ID와 `--no-uninstall`로 일반 앱 데이터를 보존한다. 로컬 runner는 환경 변수를 허용 목록으로 제한하고 별도 빈 CLI 설정을 사용한다. SDK/테스트 도구가 출력하는 링크/토큰/가상 이메일도 출력 단계에서 가린다. release에서 에뮬레이터 토글을 허용하지 않는다. debug cleartext 예외는 Android 에뮬레이터/loopback 두 호스트에만 있고 release는 HTTPS를 유지한다.

## 검사 결과

| 검사 | 결과 |
|---|---|
| TypeScript build / 서버 단위 | 통과 / 8개 통과 |
| Auth/Firestore/Functions 로컬 통합 | 18개 묶음 통과: 이메일 6 + 기존 권한/데이터 12 |
| Flutter 이메일 단위/위젯 | 12개 통과: 링크 허용 목록/교체 실패·미확인/만료 차단·기록 보존·충돌·재설정 후 로그아웃·인증 경합·연결 중 재가입 보호·오류 재시도 |
| 전체 Flutter 호스트 / 정적 분석 | 최종 85개 통과 / 문제 없음 |
| Android 실제 SDK 이메일 흐름 | 1개 전체 흐름 통과: 가입→확인→로그인→최초 기록 보관→로그아웃→재설정→구 비밀번호 거부→새 비밀번호 로그인, 기기 기록/설정 보존 |
| 기존 Android 전투/기록/설정/보호 저장소 | 6개 통과: 고해상도 텍스처/효과/HUD·무료 전투/보호막·선택/권한·실제 파일/결과/해금·설정/음향·OS 보호 저장소 |
| 문서/민감 패턴/로컬 링크/runner 문법 | 통과: Markdown74개·앱 상대 링크100개·민감 패턴·Node 문법 |
| 일반 Android 개발 앱 | 시험 플래그 없는 debug APK 빌드·기존 ID의 `adb install -r` 업데이트 성공. 최종 인증 보호 코드 포함 확인, 프로세스/재실행 Status ok 확인. 첫 실행 대기 timeout 뒤 재조회했으며 화면/개인 기록은 읽지 않음 |
| iOS / 물리 휴대폰 / 실제 이메일 | 미실행 |

로컬 통합에서 정상 가입→미확인 데이터 거부→확인→로그인→재설정→구 비밀번호/구 세션 거부→새 비밀번호 로그인을 검사했다. 다른 계정 링크, 잘못된/재사용 코드, 비허용 복귀 주소, 중복 요청, 속도 제한, 기존 계정 기록 보존, A/B/미인증/만료/삭제 세션의 읽기·수정·삭제 거부와 유료 권한 변조도 검사했다. 테스트의 가상 구매/공급자 데이터는 실제 스토어/소셜 연동 성공이 아니다.

중단 후 재개 과정에서 가상 기기 미연결과 격리 테스트 환경의 LOCALAPPDATA 누락을 발견해 기존 가상 기기 재시작/전용 임시 경로로 해결했다. 실제 Android 시험에서 발견한 에뮬레이터 링크 경로 차이(`/emulator/action`)는 debug 로컬에만 허용하도록 고쳤다. 키보드에 가려진 시험 버튼/시험 보조 코드의 문제도 해결한 뒤 전체 흐름을 통과했다. 오래된 시험 앱의 debug 서명이 달라 `.integration` 패키지만 Flutter가 재설치했으며 일반 앱 ID/기록은 건드리지 않았다. 앱 보안/승인 설정을 완화하지 않았다.

인증 만료 시 이전 연결 상태/세션 정리, 초기화·로그인 중 로그아웃의 경합, 실패한 새 링크 뒤 이전 코드 잔존, 불필요한 작업 간 공통 재전송 제한을 수정했다. 계정 연결 중 다른 주소 가입을 누르면 먼저 로그아웃하도록 안내해 기존 연결을 보존하고, 새 로그인에서는 이전 확인 코드를 폐기한다. 설정 복구 후 준비 중 표시도 해제한다. SDK 인증 변경은 원래 네이티브 요청이 끝날 때까지 기다린다. Dart의 타임아웃만으로 요청을 취소했다고 취급하지 않으며 로그아웃 중 다음 계정 로그인을 차단한다. 앱 API의 네트워크 제한 시간은 25초이며 실제 서비스의 장기 오프라인/응답 유실은 별도 실기기 검사다.

Android debug 가상 전투 129프레임 관찰에서 디코드 텍스처 7,632,384 bytes, 효과 최대6, raster p50/p95 7.9/13.2ms, build p95 43.8ms였다. 짧은 에뮬레이터 시험 값이며 60fps/발열/물리 기기 성능을 보장하지 않는다. 기존 그래픽/입력 회귀 검사와 메모리 예산은 통과했다.

Node 로컬 실행은 24.21.0이고 운영 지정은 nodejs22이므로 실제 런타임 검증을 통과한 것으로 표시하지 않는다. 현재 Android 빌드는 통과하지만 FlutterFire의 KGP 사용에 대한 향후 Flutter 호환 경고와 JDK native-access 경고가 남는다. 경고를 숨기거나 보안/의존성을 강제 변경하지 않았으며 다음 SDK 업데이트 때 재확인한다.

## 외부 설정 대기와 직접 확인

클라우드 이메일 기능은 아래 준비를 확인하기 전 `AIRZERO_EMAIL_SECURITY_READY`가 없으면 503으로 닫힌다. 이 플래그는 실제 설정을 자동 검사하는 기능이 아니며 임의로 켜서 완료를 대신하면 안 된다.

1. 이 앱 전용 dev/prod Firebase 프로젝트·허용 앱/서명·Functions/Firestore 지역·IAM·기본 거부 규칙·HTTPS·App Check를 사용자가 설정/검증한다. 공개 client config만 앱에 전달한다. 서버 `AIRZERO_FIREBASE_WEB_API_KEY`는 공개 Firebase key이고 `AIRZERO_EMAIL_RATE_SECRET`은 32자 이상 서버 Secret Manager 전용 비밀이다. 관리자 자격증명/실제 비밀 파일은 만들지 않았다.
2. 이메일/비밀번호 provider, 강제 비밀번호 정책(최소15/최대4096·조합 강제 없음), 이메일 enumeration 보호, 공급자 로그인/메일 제한·자동 공격 방어를 확인한다. **클라이언트 직접 가입을 비활성화**해 서버 가입 정책을 우회하지 못하게 해야 한다. 필요한 유료 Identity Platform/reCAPTCHA 선택/가입은 대신 실행하지 않았다. [공식 비밀번호 인증](https://firebase.google.com/docs/auth/flutter/password-auth), [client permissions 구성](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v2/Config).
3. 승인된 메일 발신자/템플릿/도메인·쿼터·고정 `https://<project>.firebaseapp.com/__/auth/action`과 복귀 `.../__/auth/complete`를 확인한다. 기본 Firebase 웹 handler는 앱 서버의 추가 비밀번호 목록/세션 처리와 다를 수 있다. 운영 전에 이 경로를 승인된 custom handler/App Link로 연결하고 직접 공급자 경로의 정책 우회를 점검해야 한다. 현재 웹 handler/Hosting/자동 앱 복귀는 만들거나 배포하지 않았다. 새 URL을 임의로 허용하지 말고 코드 허용 목록도 함께 검토한다. 웹 쪽 `Referrer-Policy: no-referrer`, 제3자 분석/리소스 배제, URL query 접근 로그 가림도 이때 실제 확인한다. [공식 handler 구성](https://firebase.google.com/docs/auth/custom-email-handler).
4. 사용자가 소유한 개발용 메일 계정으로 수신/스팸함·재전송·미확인/중복/오입력·만료/재사용 링크·다른 계정 링크·비허용 복귀·요청 제한을 직접 확인한다. Auth Emulator는 OOB 코드의 시간 경과 만료를 재현하지 않으므로 **실제 만료/짧은 유효기간 검증은 미완료**다. 운영 코드의 만료/사용 여부는 Firebase 서버 검증에 위임한다.
5. 재설정/이메일 변경 전 두 테스트 기기에서 로그인하고 변경 후 두 기기의 구 세션이 거부되는지, 새 비밀번호 직접 로그인·완료 알림/메일 템플릿·자동 로그인 없음·게임 기록/설정 보존을 확인한다. 실제 완료 메일 전달/알림 템플릿은 설정 대기다. 실제 비밀번호 관리자·Android/iOS 복귀·오프라인/응답 유실도 확인한다. 실제 사용자에게 시험 메일을 보내지 않는다.

운영 미연결은 허용 규칙이나 가짜 성공으로 우회하지 않았다. 로컬 코드·권한 검사 완료와 외부 적용 완료는 별개다. 이번 단위 이후 소셜/결제/삭제/전체 동기화로 진행하지 않는다.

## 의존성·출처·비용/위치

공식 pub.dev의 `firebase_core 5.0.0`, `firebase_auth 7.0.0`, `firebase_app_check 0.5.0`을 고정하고 archive/유지관리자 소스·native build·lockfile을 검토한 뒤 추가했다. [FlutterFire 공식 소스](https://github.com/firebase/flutterfire), [Core](https://pub.dev/packages/firebase_core), [Auth](https://pub.dev/packages/firebase_auth), [App Check](https://pub.dev/packages/firebase_app_check). Analytics/광고/SMS/결제 SDK는 추가하지 않았다. 기존 서버 Admin/Functions 의존성을 재사용했다. 기존 `npm audit`의 운영 의존성 0건·개발 CLI 전이 의존성 7건(중간4/높음3)은 [6단계 기록](AUTH-BACKEND-RESULTS.md)과 같고 강제 override하지 않았다.

공통 비밀번호 거부 목록은 MIT 라이선스 [SecLists의 고정 10k 목록](https://github.com/danielmiessler/SecLists/blob/913b327317496d062bcc7cace524aaad8a693be2/Passwords/Common-Credentials/10k-most-common.txt)을 사용했다. 원문 SHA256 `68782d6a4a19a4768d5f15dd66bd534e7a33055cc755411e33f16d18c50fdcce`, 고유 값 10,001개의 SHA256만 `server/firebase/password-blocklist.json`에 담았다. 이 SHA는 거부 목록 비교용이며 계정 비밀번호 저장 방식이 아니다. [라이선스 사본](../server/firebase/password-blocklist.LICENSE.txt)을 유지했다. 흔한/일부 알려진 값의 제한된 목록으로 모든 유출 비밀번호를 탐지하지 않으며 목록 갱신·추가 공급자 방어 검토는 운영 전 남아 있다. 사용자 비밀번호를 외부 유출 조회 서비스로 보내지 않는다.

검사는 전부 로컬 demo 프로젝트다. Firebase Auth는 미국 처리이고 Firestore/Functions의 서울 후보와 동일 지역이라고 표시하지 않는다. 실제 지역은 사용자 확정 대기다. Functions 배포의 Blaze 준비, 인증 사용량/메일 제한, Firestore 요청/보관, App Check/reCAPTCHA/Secret Manager/빌드·네트워크 비용은 실제 선택/사용량에 따라 별도다. 새로운 플랜에 가입하거나 고정 원화 비용을 약속하지 않았다. [공식 가격](https://firebase.google.com/pricing), [공식 처리 위치](https://firebase.google.com/support/privacy), [기존 비용 설계](COSTS-AND-DECISIONS.md).
