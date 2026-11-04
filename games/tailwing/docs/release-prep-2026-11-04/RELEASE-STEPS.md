# 사용자 직접 서명 빌드·실행 검사

## Android — 지금은 조건 미준비

1. Android Studio에서 SDK/Platform Tools/API 36 이상·프로젝트가 사용하는 build-tools/NDK/JBR을 준비한다. 현재 프로젝트는 Flutter 기본 target 36·NDK 28.2 계열을 참조하며 실제 컴파일은 아직 하지 못했다. 서명된 과거 앱이 있다면 같은 applicationId·업로드 키/Play 서명과 최고 versionCode를 먼저 비교한다. 이름 변경 때문에 앱 ID/키/저장 namespace를 새로 만들지 않는다.
2. 기존 업로드 키와 비밀 속성 파일을 **저장소 밖 사용자 보안 위치**에 준비한다. `TAILWING_SIGNING_PROPERTIES`에는 해당 속성 파일의 경로만 설정한다. 준비 도구는 경로 설정/존재 여부만 검사하고 내용을 열지 않는다. 실제 암호/키/인증서/토큰을 채팅이나 Git에 넣지 않는다.
3. 현재 `android/app/build.gradle.kts`의 release signing은 연결 전이다. 이 환경 변수는 준비 점검용이며 **설정만으로 자동 서명되지 않는다**. 소유자가 [Flutter 공식 서명 절차](https://docs.flutter.dev/deployment/android)에 따라 외부 파일의 `storeFile`, `keyAlias`, `storePassword`, `keyPassword`를 release signingConfig에 연결해야 한다. debug signing fallback/비밀 하드코딩/콘솔 출력을 넣지 않는다. 이 native 변경 후 관련 빌드/로그인 인증서·콜백을 다시 검사한다.
4. 실제 환경을 정하고 공개 Firebase/App Check/OAuth/상품/정책 값만 검토된 파일에 준비한다. 개발 기본 ID가 실제 출시 대상과 같은지 소유자가 확인해야 한다. 미정 값을 임의 생성하지 않았다. 공개 설정도 앱/환경별로 분리하고 서버 비밀은 dart-define에 넣지 않는다. 현재 가격/상품/URL 미정·구매 잠금을 해제하지 않는다.
5. 현재 `0.1.0+1`을 유지했다. 실제 Play 최고 빌드보다 큰 번호를 소유자가 결정한 뒤 아래 버전 값을 조정한다. `AIRZERO_INTEGRATION`, `AIRZERO_AUTH_EMULATOR`, 연구소/모의 이용권을 제출 빌드에 넣지 않는다. 오래된 미서명 APK를 대신 제출하지 않는다.

```powershell
Set-Location -LiteralPath 'C:\Users\nnakh\OneDrive\Desktop\App\monorepo\games\tailwing'
# 서명 연결·실제 공개 설정/운영 검증을 마친 뒤 본인 PC에서 실행
& ..\..\flutter\bin\flutter.bat build appbundle --release --target lib/main.dart --build-name 0.1.0 --build-number 1
Get-ChildItem -LiteralPath '.\build\app\outputs\bundle\release' -Filter '*.aab'
# 실제 생성 파일을 지정해 Get-FileHash -Algorithm SHA256으로 기록
```

출력은 Flutter 버전별 실제 로그/파일 이름을 확인한다. 예상 폴더는 `build/app/outputs/bundle/release/`이며 파일이 있다고 서명/제출 가능으로 판정하지 않는다. 기존 APK용 검사 도구를 AAB에 그대로 적용하지 않는다. AAB의 서명/JAR 검증과 인증서 지문·manifest·환경·버전·권한·16KB 설정을 확인하고, 공식 bundletool로 생성한 설치 APK를 실제 장비에서 검사한다. 키/암호를 명령줄/검사 결과에 출력하지 않는다. [Flutter AAB 준비/테스트](https://docs.flutter.dev/deployment/android).

확인할 실행: 새 실행/업데이트 시 기존 기록 보존, 무료 홈→선택→전투→결과, 보호막 종료/구독 만료, 앱 백그라운드/복귀, 실제 이메일·Google/Kakao 콜백/세션, 구매 잠금/복원/환불 조건·개인정보 안내. Play 배포 앱 서명은 업로드 키와 구분하므로 로그인 인증서 등록과 실제 스토어 경로를 소유자가 재확인한다. 공식 내부 테스트/라이선스 테스트 업로드는 소유자 직접이다.

## iOS — Mac/서명 준비 후 본인 직접

현재 Windows에서 Archive/IPA를 만들거나 iOS 실행을 검증하지 않았다. 클라우드 빌드 환경도 선택/가입/업로드하지 않았다. Mac·현행 Xcode/SDK·사용자의 Team/서명·프로비저닝/기존 Bundle ID와 Apple 기능/Privacy Manifest/URL scheme을 준비해야 한다. 유료 멤버십을 대신 가입하지 않는다.

Mac에서 `flutter doctor -v` 확인 → `ios/Runner.xcworkspace`의 기존 Bundle/Team·서명·callback/entitlement·개인정보 선언 점검 → 실제 iPhone에서 기본 흐름/로그인/구독 Sandbox 확인 → 사용자 공개 설정으로 `flutter build ipa --release --target lib/main.dart` 순서다. Archive는 보통 `build/ios/archive/`, IPA는 `build/ios/ipa/`에 생성된다. Xcode Organizer의 검증/Export 후 버전/서명/프로비저닝/실행/SHA를 기록한다. Windows/Android 통과를 대신 쓰지 않는다. [Flutter iOS 공식 준비](https://docs.flutter.dev/deployment/ios).

App Store Connect 업로드/TestFlight/심사 제출은 이 절차에 포함해 실행하지 않았다. 사용자 직접 확인표를 따른다.
