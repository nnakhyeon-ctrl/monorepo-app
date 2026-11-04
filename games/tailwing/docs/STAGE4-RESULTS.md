# 4단계 실제 프로젝트·기본 화면 기록

이 문서는 최초 4단계 완료 당시의 이력이다. 최신 기본 무료/월간·연간 구독 변경과 추가 화면은 [UPGRADE-RESULTS.md](UPGRADE-RESULTS.md)를 우선한다.

작업일: 2026-10-18. 대상은 games/tailwing 하나다. 기존 계획을 보존하며 실제 Flutter 프로젝트와 기본 화면까지만 구현했다. 5단계 게임과 실제 인증·서버 저장·결제는 시작하지 않았다.

## 소스와 도구

- Flutter 3.47.7 stable / Dart 3.13.5, Windows 11 PowerShell. Android Studio의 JBR 25.0.3, Android SDK 36, Gradle 9.3.1 / AGP 9.1.0.
- 공식 flutter create를 저장소의 무시된 임시 폴더에 --empty --no-pub --platforms=android,ios로 실행하고 기존 파일 충돌을 확인해 소스만 병합했다. 생성 전 앱 문서 19개의 해시를 기록했고 README 등 기존 문서를 덮어쓰지 않았다. 이후 현재 상태 문서는 의도적으로 갱신했다.
- pubspec 이름 raikeopeu2026, 버전 0.1.0+1. 런타임은 Flutter/Flutter localizations SDK만 사용한다. flutter_test·integration_test SDK와 고정 flutter_lints 6.0.0은 개발용이다. pubspec.lock의 hosted 항목은 HTTPS pub.dev와 SHA256을 사용한다. 외부 인증/결제/분석/광고/게임 엔진/보안 저장 플러그인은 아직 설치하지 않았다.
- Gradle 공식 HTTPS 배포의 SHA256을 wrapper에 지정했다. 의존성 강제 갱신·스크립트/실행 정책 완화·루트 npm 설치는 하지 않았다.
- Android namespace com.example.raikeopeu2026, applicationId와 iOS Bundle ID com.example.raikeopeu2026.dev. 콘솔 미등록 개발용 값이다. 배포 식별자·서명·상품·OAuth 클라이언트는 별도로 확정한다. Android release에 debug 서명을 자동 적용하지 않는다.
- 현재 생성기 기본값은 Android minSdk 24 / targetSdk 36, iOS deployment target 15.0이다. 실제 출시 지원 하한을 사용자와 최종 확정한 값은 아니며 이후 SDK·기기 검증에 맞춰 확정한다.
- 중첩 .git·공용 서버 DB·다른 앱 이용권 공유 없음. 앱 Dart 의존성과 루트 Node 도구를 분리했다. 기존 빈 Untitled-1.txt와 .vscode/settings.json은 보존한다.

## 기본 화면과 화면 이동

첫 화면은 어두운 남색·회색 격납고, 청록색 포인트, 중앙 전투기 그림과 게임 제목, 큰 게임 시작 버튼으로 구성했다. 새 이미지와 출처/최종 프롬프트는 [ASSET-SOURCES.md](ASSET-SOURCES.md)에 있다. 게임 시작은 구매 전 안내·취소·계정 연결·이용권 확인으로 연결되며 실제 게임을 열지 않는다.

네이티브 시작 배경도 남색으로 맞추고 첫 화면의 상태 표시줄을 밝게 지정했다. Android 색상은 리소스 참조로 연결했으며 최종 APK에서 재빌드했다. iOS 시작 배경 수정은 XML 구성까지이며 Mac에서 실제 표시를 확인해야 한다.

| 경로 | 화면·현재 동작 |
|---|---|
| / | 격납고 분위기 첫 화면, 게임 시작 전 안내 |
| /hangar | 기체·영구 강화 안내와 데이터 준비 빈 상태 |
| /account | 이메일/소셜 선택, Google·Kakao 및 iOS Apple 준비 버튼 |
| /account/email | 이메일 ID 로그인 폼·가입/복구/도움·하단 소셜 |
| /account/register | 이메일 가입 폼·비밀번호 확인·개별/전체 필수 동의 |
| /account/verify | 이메일 확인·재전송 준비 상태 |
| /account/recovery | 이메일 형식 검사·계정 존재를 밝히지 않는 동일 복구 안내 |
| /account/help | 계정 찾기 도움, 타인 이메일/아이디 조회 없음 |
| /account/logout | 미동기화 기록 주의·취소/확인·현재 세션 없음 안내 |
| /account/delete | 삭제 범위/구매 환불 구분·취소/확인·실제 삭제 미실행 |
| /entitlement | 1회 구매·가격 미정·구매 여부 미확인·이용권 확인 준비 |
| /entitlement/restore | 구매 복원과 게임 기록 불러오기 구분·복원 준비 |
| /records | 같은 계정 서버 이어하기 안내·미연결 상태, 가짜 기록 없음 |
| /settings | 계정·기록·이용권·전환 효과 줄이기·로그아웃/삭제/안내 |
| /support | 지원·구매/계정 복구 안내, 실제 연락처는 미정 |
| /legal/terms | 이용약관 로컬 초안 |
| /legal/privacy | 개인정보·삭제 로컬 초안 |
| /legal/payment | 1회 구매·환불·복원 로컬 초안 |

18개 경로만 허용하며 예기치 않은 route arguments·외부 경로는 고정 오류 안내로 보낸다. 입력 경로를 오류 화면에 그대로 노출하지 않는다. 네이티브 자동 딥링크는 껐고 WebView·외부 URL 실행·파일 가져오기는 도입하지 않았다. 실제 이메일 링크/소셜 콜백은 이후 단계에서 허용 호스트·스킴·state/nonce 등을 검증해 추가한다.

## 폼·접근성·연결 상태

- 계정 화면은 흰 배경·검은 제목/기본 버튼·밑줄 필드·가입/복구 링크·공식 소셜 버튼을 사용한다. 이메일만 ID로 쓰고 전화번호·SMS·별도 아이디는 받지 않는다.
- 라벨·입력 순서·이메일 키보드·자동완성/password autofill hints·기본 붙여넣기/선택 메뉴·비밀번호 가림/표시를 제공한다. 가입 12자 이상은 현재 UI의 잠정 기준이며 실제 인증 공급자 정책과 이후 일치시킨다. 미연결 인증은 암호 관리자에 성공한 가입으로 저장하지 않는다.
- 필수 안내 2개와 전체 동의는 기본 체크하지 않는다. 각각 전문을 열 수 있고 돌아와도 폼 상태를 유지한다. 현재 선택 동의 수집이 없어 선택 항목을 임의로 추가하지 않았다.
- 주요 버튼은 최소 48dp 이상 터치 영역, 스크롤·키보드 회피·넓은 화면 최대 폭·글자 확대·오류 라벨/상태 읽기·이미지 설명을 제공한다. 화면 전환은 짧은 fade이고 OS 애니메이션 끄기 또는 전환 효과 줄이기를 따른다. 설정은 이 실행의 메모리에서만 유지한다.
- ConnectionGateway는 자격증명을 받지 않으며 기본 구현은 미연결만 반환한다. 로딩 때 중복 입력을 막고 실패 상세·예외/요청 내용을 사용자나 로그에 출력하지 않는다. 인증/구매 성공이나 이용권을 만드는 코드·가상 계정·우회 플래그는 디버그/릴리즈 모두 없다. 테스트의 대기/실패 gateway는 test 폴더에만 둔다.

## 개인정보·보호 저장소 검토

현재 이메일/비밀번호는 폼 입력 중 메모리에만 있고 네트워크·DB·파일·로그·캐시에 쓰지 않는다. 제출 전송 대신 준비 안내를 띄우며 비밀번호 controller를 비운다. 화면 종료 시 controller를 해제한다. Dart 문자열 메모리의 물리적 덮어쓰기까지 보장한다는 뜻은 아니다. 실제 계정 정보로 시험하지 않는다.

[flutter_secure_storage 공식 패키지](https://pub.dev/packages/flutter_secure_storage)의 iOS Keychain·Android 보호 저장 방식을 검토했다. 현재 보관할 토큰이 없어 설치하지 않았다. 6단계에 Auth SDK의 실제 세션 저장·삭제·백업·키체인 잔존 동작을 먼저 대조하고 앱이 직접 보관할 최소 비밀에 검증된 보호 저장소를 적용한다. SharedPreferences나 평문 파일에 세션을 넣지 않는다. 서버 서명 이용권 캐시도 클라이언트 boolean으로 대체하지 않는다.

Android는 cleartext 통신·자동 백업/기기 전송을 제한하고 release의 FLAG_SECURE를 적용하도록 구성했다. debug에서만 가상 데이터 화면 확인을 허용한다. iOS는 ATS 임의 통신 허용·파일 공유를 끄고 앱이 비활성/백그라운드일 때 Flutter 개인정보 가림 화면을 표시한다. 인증서 검증 우회 코드는 없다. 현재 서비스 목적지는 없으며 이후 허용된 HTTPS 목적지만 연결한다. 기본 화면에서 민감 OS 권한은 요청하지 않는다. 최종 병합 manifest와 실기기 최근 앱/캡처 보호는 서비스 연결 후 다시 검증해야 한다. iOS 스크린샷을 완전히 차단한다고 보장하지 않는다.

개발 도구의 디버그 서비스 통신과 향후 운영 SDK 데이터 전송은 구분한다. 시스템 자동완성/키보드의 동작까지 앱이 통제한다고 하지 않는다. 실제 SDK가 없다는 사실을 앞으로도 데이터 수집이 없다는 주장으로 확대하지 않는다. 향후 처리표는 [DATA-PROCESSING.md](DATA-PROCESSING.md)를 따른다.

## PowerShell 실행과 F5

저장소를 VS Code에서 열고 상태 표시줄의 기기 선택에서 실행 중인 Android 에뮬레이터를 선택한다. 실행 및 디버그에서 **라이커프 2026 · Android 기본 화면** 구성을 고르고 F5를 누른다. 구성 파일은 저장소 루트 .vscode/launch.json이며 앱 cwd와 lib/main.dart를 지정했다. 기기 ID를 고정하지 않았고 기존 settings.json을 바꾸지 않았다.

로컬 VS Code의 Dart·Flutter 확장 3.144.0 설치도 확인했다.

```powershell
Set-Location -LiteralPath 'C:\Users\user\Desktop\Smart Automation\6. App\monorepo\games\tailwing'
flutter --suppress-analytics pub get
flutter --suppress-analytics analyze
flutter --suppress-analytics test
flutter --suppress-analytics devices
flutter --suppress-analytics run -d <위에서 확인한 Android 기기 ID>
```

실제 기기 ID로 마지막 명령의 자리표시자를 바꾼다. 현재 통합 검사 명령은 앱 폴더에서 flutter --suppress-analytics test integration_test/screen_flow_test.dart -d <Android 기기 ID> --dart-define=AIRZERO_INTEGRATION=true --no-uninstall 이다. 검사 전용 앱 ID와 자동 삭제 방지 옵션의 이유는 [최신 실행 기록](PLAYABLE-RESULTS.md)을 따른다. 빌드만 확인하려면 flutter --suppress-analytics build apk --debug다. 동시에 네이티브 빌드는 하나씩 실행했다.

iOS 소스는 생성했지만 이 Windows 환경에서는 Xcode 빌드/실행을 하지 못한다. Mac에서 서명/실제 Bundle ID와 SDK 최소 버전을 확인한 뒤 flutter analyze, flutter test, flutter build ios --simulator 및 같은 통합 검사를 별도로 실행해야 한다. VS Code F5 구성 파일의 연결을 준비한 것이며 IDE에서 F5 키를 직접 누른 검증과 CLI 실행은 구분한다.

## 검증 결과

| 검사 | 결과 |
|---|---|
| dart format lib test integration_test | 통과, 추가 포맷 변경 없음 |
| flutter analyze | 통과, No issues found |
| flutter test | 통과, 위젯 검사 11개 |
| 위젯 검증 범위 | 시작/취소·18경로·로그인 입력/자동완성/가림·가입 필수 동의·복구 동일 응답·320×568/글자 2배/키보드·로딩/중복 차단/오류 가림·미연결 복원·백그라운드 가림·iOS Apple 준비 버튼·라벨/터치 영역/글자 대비 |
| Android debug APK | 통과, build/app/outputs/flutter-apk/app-debug.apk 생성. 최초 빌드 555.7초 (공식 Gradle/의존성 준비 포함) |
| Android 에뮬레이터 통합 화면 이동 | 통과, sdk gphone64 x86 64 (android-x64). 시작 안내→계정→로그인 폼/비밀번호 표시→가입/미체크 동의→약관→뒤로가기→Google/Kakao 준비 안내→이용권/복원→기록 연결 준비, 1개 흐름 검사 |
| Android 실행 화면 확인 | 통과, 최종 lib/main.dart 앱 설치·새 시작 Status: ok. 1080×2400 에뮬레이터에서 제목·전투기 그림·시작 버튼·메뉴·시작 안내·기록 빈 상태를 직접 확인 |
| iOS Xcode 빌드/실행 | 미실행, Windows 제한 |
| 루트 npm.cmd run ci | 통과, Markdown 62개·민감정보/추적 검사·JavaScript 50개·Bash 16개·Terraform fmt·회귀 검사 9개 |
| 원본 파일/설정·의존성 출처·XML | 기존 사용자 파일 SHA256 일치, F5 JSON·네이티브 XML 구문 정상, hosted 출처 HTTPS pub.dev 확인 |

검사 중 테스트의 스크롤 후 프레임 대기·semantics handle 해제·공식 iOS 플랫폼 variant 정리를 고쳤다. 통합 테스트의 영문 Back 툴팁 가정도 한국어 화면의 실제 BackButton 선택으로 바꿨다. 제품 화면 검사를 삭제해 통과시키지 않았다. 최초 SDK XML 버전 차이 경고와 Java 25 Gradle 네이티브 라이브러리 경고가 있었으나 APK 빌드는 성공했다. 경고를 숨기거나 보안을 완화하지 않았다. 실제 계정·테스트 메일·실제 구매·운영 서버·외부 공개·스토어 작업은 하지 않았다.

통합 검사 이후 에뮬레이터 프로세스가 종료되어 한 번 실행에 실패했다. 원인은 확정하지 않았다. AVD 데이터 삭제 없이 snapshot 로드를 건너뛴 콜드 부팅으로 재연결했고 최종 APK의 Flutter 실행 및 Android 공식 adb 재설치/새 시작을 확인했다. 마지막 앱은 첫 화면으로 열어 두었다. 시작 색상 조정 중 발견한 drawable 색상 참조 오류는 정식 color 리소스를 추가해 수정하고 APK 재빌드로 확인했다.

기기 확인 캡처는 저장소의 무시된 .test-tmp/stage4-captures/에만 두며 공개 자산·제출용 이미지로 사용하지 않는다. 최종 home.png는 새로 시작한 앱 첫 화면이며 실제 계정·개인 데이터가 없다. 배포용 앱 아이콘·스토어 캡처는 12단계 작업이다. 최종 APK의 kernel에서도 통합 테스트 케이스 문자열이 포함되지 않음을 확인했다.

## 다음 단위

여기서 4단계를 멈춘다. 다음은 사용자 5단계 지시 후 viewport·입력·자동 사격·기본 적/충돌부터 작은 단위로 구현한다. Flame은 그때 공식 호환/출처/lockfile을 검토한다. 실제 인증(6~9단계), 같은 계정 두 기기 동기화(6단계 기반 이후), 구매/복원(10단계)은 별도 진행한다. 가격·출시 국가·지원 OS 하한·기체/스테이지 최종 수·배포 식별자·공개 운영자/지원 연락처는 미정이다.

공식 절차 참고: [프로젝트 생성](https://docs.flutter.dev/reference/create-new-app), [접근성](https://docs.flutter.dev/ui/accessibility), [통합 검사](https://docs.flutter.dev/testing/integration-tests), [VS Code 실행](https://docs.flutter.dev/tools/vs-code). 아키텍처와 미정 외부 준비는 기존 3단계 문서를 유지한다.
