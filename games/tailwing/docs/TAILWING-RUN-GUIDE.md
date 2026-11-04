# 테일윙 직접 실행·다음 준비 순서

2026-10-30 최신 디자인: [전후 화면·음악](tailwing/design-pass-01/index.html)·[결과/미검증](TAILWING-DESIGN-PASS-RESULTS.md). 아래 APK 경로의 preview를 갱신했다. 홈의 버튼 명칭은 이제 **‘출격’**이며,토끼/거북이의 새 탑승 모습과 캐릭터3열 카드를 확인할 수 있다. 음악은 환경설정의 배경음 미리 듣기/음량과 실제 전투에서 확인한다. 그 밖의12종 고유 기술은 기존 debug 연구소에서 무기록으로 시험하며 일반 게임의 구매 잠금은 유지된다. 이전 release-inspection은 새 디자인 적용 전 이력이다.

2026-10-30 KST. 개발용 로컬 안내다. 앱 ID/서명/상품·기존 자료를 바꾸지 않고, 과금/배포/등록·실사용자 삭제는 하지 않는다. [현재 결과와12종 표](TAILWING-FOLLOWUP-RESULTS.md)를 함께 본다.

## 지금 직접 할 첫 작업

**테스트할 Android 휴대폰을 USB로 PC에 연결하고 USB 디버깅을 허용한다.** 테스트 폰이 없으면 Android Studio → Device Manager에서 기존 `Medium_Phone_API_37.0` 가상 기기를 실행해 먼저 외형/기능을 확인한다. 유료 클라우드 기기나 새 서비스를 신청할 필요는 없다.

1. 폰 설정의 ‘휴대전화 정보/소프트웨어 정보 → 빌드 번호’를 통해 개발자 옵션을 열고 USB 디버깅을 켠다. 메뉴 이름은 제조사별로 다를 수 있다.
2. 데이터 통신 USB 케이블로 연결하고 폰의 **본인 PC USB 디버깅 허용**을 확인한다. Windows에서 감지되지 않으면 제조사 공식 ADB 드라이버/케이블을 확인한다. 비밀번호/인증번호를 채팅에 보내지 않는다. [Android 공식 연결 안내](https://developer.android.com/studio/run/device).
3. 아래 `devices` 결과에서 본인 기기의 상태가 `device`인지 확인한다. `unauthorized`면 폰의 허용 화면을 먼저 확인한다. 기기 ID는 본인 PC에서만 사용하고 채팅에 복사할 필요가 없다.

```powershell
Set-Location -LiteralPath 'C:\Users\nnakh\OneDrive\Desktop\App\monorepo\games\tailwing'
$tailwingAdb = 'C:\Users\nnakh\AppData\Local\Android\Sdk\platform-tools\adb.exe'
& $tailwingAdb devices
```

## 개발 APK 설치·실행

파일: `build/tailwing-preview/tailwing-preview-debug.apk`. [현재 크기/SHA-256/소스 지문](tailwing/BUILDS.json)의 `preview`를 확인한다. 일반 `lib/main.dart`이지만 별도 **`com.example.raikeopeu2026.dev.integration`** ID의 debug 앱이다. 일반 앱 `.dev`에 덮지 않는다. 미서명 `tailwing-inspection-unsigned.apk`는 설치용이 아니다.

아래 `<본인 기기 ID>`를 위 출력에 나온 값으로 바꾼다. 설치 실패 시 **제거/데이터 초기화로 우회하지 않고 멈춘다**. 특히 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`은 서명이 다른 경우이므로 기존 앱/키를 지우지 말고 해당 오류 종류만 알려준다.

```powershell
$tailwingDevice = '<본인 기기 ID>'
& $tailwingAdb -s $tailwingDevice install -r '.\build\tailwing-preview\tailwing-preview-debug.apk'
if ($LASTEXITCODE -ne 0) { throw '설치 실패: 제거하거나 초기화하지 말고 오류 종류를 확인하세요.' }
& $tailwingAdb -s $tailwingDevice shell am start -n 'com.example.raikeopeu2026.dev.integration/com.example.raikeopeu2026.MainActivity'
```

코드 수정 후 개발 APK 재생성은 앱 폴더에서 `node tool/build_tailwing_apk.mjs preview`다. 새 서명 키/인증서/환경 비밀·과금 SDK 설정을 만들지 않는다. 빌드만 수행하며 자동 설치/공개하지 않는다. PowerShell 실행 정책을 완화할 필요 없이 `.bat`/Node 도구를 사용한다.

## 12종을 보는 방법

- 홈에서 토끼/여우/거북이 무료 선택→게임 시작으로 정상 무료 게임을 확인한다. 기본 사격/보호막은 구독 없이 동작한다.
- 홈을 아래로 내려 **‘개발 연구소 · 캐릭터 전투 미리보기’**를 연다.12종 선택 버튼·기체·기술 버튼·다시 시작·작전 선택을 시험한다. 스크롤은 기체 조작 영역 바깥에서 한다. 전투 영역을 드래그하면 기체를 움직인다.
- 연구소는 **무기록·무구매**다. 일반 계정 이용권/구매/기록을 주지 않고, release에서는 진입을 열지 않는다. 정상 격납고의 구독 콘텐츠가 잠긴 상태는 의도된 동작이다. 무료 캐릭터3종의 고유 기술도 정상 게임에서는 구독 전용이다.
- 각 종에서 기술 사용→종료→종 전환→다시 시작을 확인한다. 거북이는 전방 차단만, 다람쥐는 설치물 종료, 개구리는 새 조준만 유도되는지 본다. 이미 발사된 탄이 바뀌지 않아야 한다. 무적을 임의로 기대하지 않는다.
- 정상 무료 게임에서 일시정지/복귀·보스·결과 기록·재도전·재실행을 본다. 다른 계정 전환/실제 탈퇴·구매는 서버 미연결 상태에서 억지로 실행하지 않는다.

**debug 실행은 실기기 성능 통과가 아니다.** 프레임/발열/입력 지연은 소유 기기에서 별도 profile/release·반복 실행/장시간 검사해야 한다. 현재 profile에 `.integration` 접미사가 자동 적용된다고 가정하지 않는다. 별도 ID/서명/시험 격리 경계를 먼저 검토하여 일반 앱을 덮지 않아야 한다. 실기기 검사 전 모델명/OS/화면·검사 시간/실패 지점만 기록하고 개인정보/토큰이 있는 화면이나 전체 로그를 공유하지 않는다.

## 실제 연결의 우선순위와 선행 조건

| 순서 | 다음 일 | 현재 막힌 이유/해결 조건 |
|---|---|---|
| P0. Android 직접 확인 | 위 개발 APK/12종·무료1탄·재시작을 테스트 폰에서 확인 | 현재 물리 기기 미연결. 기능과 성능을 나눠 기록 |
| P1. 기존 개발 설정 확인 | Firebase 기존 프로젝트/Android·iOS ID/서명,Google·카카오 클라이언트/최소 동의/콜백 대조 | 이미 등록한 값을 재사용. 콘솔은 이번에 원격 조작하지 않음. 신규 프로젝트/키 만들지 않음 |
| P1. 실제 서버 결정/준비 | 인증 UID·세션/App Check·기본 거부 규칙/IAM·Secrets·사용자별 데이터·구매 검증 API | 현재 Functions 배포는 Blaze 조건. 무료 유지 요청으로 배포/요금 전환 대기. 대안은 별도 구조/비용 검토가 먼저이며 임시 해금/전체 허용 규칙은 금지 |
| P2. 로그인 실연동 | Google/카카오/이메일의 실제 OS 왕복·취소·만료·A/B/게스트·재인증/삭제 재검증 | 실제 서버/서명/콜백·본인 개발 계정·기기 선행. 로컬 가상 proof를 실로그인으로 대체하지 않음 |
| P2. 공개 지원/정책/삭제 | 운영자·지원처·처리 지역/기간/보관 예외와 HTTPS 주소,실제 인증/재인증·삭제 처리 worker/재시도 | 비공개 HTML만으로 삭제 접수 완료가 아님. 웹 Auth/App Check/API/worker 추가 연결과 서버 선행. 공개는 사용자 직접 단계 |
| P3. 스토어 구독 시험 | 소유자가 기존 앱의 상품 ID/월·연 조건/국가·현지 가격·테스터·서버 알림/API 권한 확정 | ID7개/URL4개 미정·구매 잠금. Play 라이선스 테스터/테스트 결제수단,Apple Sandbox만 사용. 실제 청구/등록/업로드는 이 작업에서 안 함 |
| P3. Apple/iOS | Mac/지원 Xcode/iPhone·서명/프로비저닝·Apple capability·실제 callback/서버 검증 | Apple 계정 로그인만 완료,유료 멤버십/장비 없음. 새 유료 가입은 하지 않음. Mac이 있다면 무료 Personal Team의 기본 UI 시험 가능성을 기존 entitlements/ID와 대조하되 고급 인증/스토어 검증과 구분 |
| P4. 통합/출시 자료 | 관련 기능→11단계 영향 검사→12단계 서명 파일/실제 캡처/소개/개인정보 공개/심사 접근 방법 | 실연동/장비/서명·경고가 남으면 최종 검증/제출 완료 표시 금지 |

Functions의 배포 요금제 조건은 [Firebase 공식 안내](https://firebase.google.com/docs/functions/get-started#about_this_tutorial), 무료 Apple 계정/Personal Team과 고급 기능·배포의 차이는 [Apple 공식 안내](https://developer.apple.com/help/account/basics/about-your-developer-account)를 따른다. 무료 개인 팀이 현재 프로젝트의 모든 entitlement/로그인/스토어 기능을 지원한다고 약속하지 않는다.

## 첫 콘솔 확인은 값 비교만

[Firebase 일반 설정](https://console.firebase.google.com/project/airzero-strike-dev/settings/general) → 기존 `AIRZERO STRIKE DEV`/프로젝트 ID `airzero-strike-dev` → ‘내 앱’의 Android/iOS 식별자 **`com.example.raikeopeu2026.dev`** → 현재 Spark 표시를 본다. 입력/저장/새 앱 생성은 필요 없다. 개발 인증서 지문은 본인 PC에서 기존 값과만 비교한다. 서비스 계정 JSON/개인 키는 내려받거나 채팅에 보내지 않는다. 결제수단·Blaze·배포 버튼을 누르지 않는다.

이후 Google 기존 클라이언트/카카오1614509와 서버·공개 웹·스토어 입력 항목은 [외부 설정 순서](EXTERNAL-SETUP-ORDER.md)·[계정 실제 연결](ACCOUNT-LIVE-SETUP.md)·[결제 준비](BILLING-SETUP.md)에 보존한다. 앱 표시명을 바꿨다는 이유로 앱/상품 ID·서명·소유 귀속을 새로 만들지 않는다.
