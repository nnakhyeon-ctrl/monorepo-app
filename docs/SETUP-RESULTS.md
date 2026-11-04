# 2단계 준비 결과

확인일: 2026-10-17 (한국 시간). 현재 단계는 개발 도구와 저장소 준비다. 사용자가 마지막으로 앱 생성·실행 대신 2단계까지만 완료하도록 선택했다.

## 작업 경로와 저장소

- 개발 방식: Flutter
- 작업 경로: C:/Users/user/Desktop/Smart Automation/6. App/monorepo
- 저장소 루트: 위 경로의 .git 한 개. 앱 내부에 중첩 .git을 만들지 않음
- 로컬 브랜치: main. 커밋·추적 파일 없음
- origin: https://github.com/nnakhyeon-ctrl/monorepo-app.git
- 원격 조회 성공, 당시 HEAD·브랜치 ref 없음. 기존 원격 내용을 덮어쓰지 않음
- commit·push·저장소 공개·스토어 작업·호스팅·클라우드 작업 미실행

원본은 [공개 템플릿](https://github.com/limsangjin12/app-templates)의 커밋 9d9867935af7f10e621f2ee5f89cf2a2132c4057이다. 원본에 push하지 않고 원본 LICENSE를 유지했다.

원본 보존 폴더: C:/Users/Public/Documents/ESTsoft/CreatorTemp/monorepo-stage2-template-20261017

- 원본 clone 및 audit/ 스냅샷 유지 (132개 파일)
- ZIP: template-9d986793.zip
- ZIP SHA256: 783EB399820E9FF2BEBB928537F6374E17D89B617D3AFB82A03F2357FAC020E4
- 압축 경로·중복·링크·특수 파일·용량 검사 후 기존 파일과 충돌 없이 복사
- 기존 Untitled-1.txt 및 .vscode/settings.json은 초기 SHA256과 일치

## 개발 도구

| 항목 | 확인 결과 |
|---|---|
| OS / 셸 | Windows 11 x64 / PowerShell |
| Git / Git Bash | 2.56.0.windows.2 / 5.3.15 |
| Node / npm.cmd | 24.21.0 / 11.19.0 |
| Flutter / Dart | stable 3.47.7 / 3.13.5, C:/Users/user/flutter |
| Android Studio | 실행 파일 존재, AI-262.9437.185.2621.16467767 |
| JDK | Android Studio 내장 JBR OpenJDK 25.0.3 |
| Android SDK | C:/Users/user/AppData/Local/Android/Sdk, API 36·build-tools 36.0.0 등 준비 |
| 에뮬레이터 | Flutter devices에서 sdk gphone64 x86 64 / android-x64 / supported 확인 |
| Terraform | 원본 CI 고정 버전 1.9.8, .tools/terraform/1.9.8/에 로컬 준비 |

최종 flutter --suppress-analytics doctor에서 Flutter·Windows·Android toolchain·Chrome·연결 장치·네트워크가 정상이다. Visual Studio만 미설치로 표시된다. Windows 데스크톱 빌드를 선택하지 않았으므로 추가 설치하지 않았다. iOS/macOS 빌드는 Mac/Xcode가 필요하고 클라우드 빌드는 선택하지 않았다.

Terraform은 [HashiCorp 공식 배포처](https://releases.hashicorp.com/terraform/1.9.8/)에서 Windows x64 ZIP과 SHA256SUMS를 내려받아 일치 여부를 확인한 뒤 압축 경계를 검증해 준비했다. ZIP SHA256은 2667DE56106BC6707968286357E29C20F8DBBB2F429EF57099B04994F82D9684다. 현재는 fmt 검사에만 쓰며 AWS 선택이나 init·provider 다운로드·plan·apply를 의미하지 않는다. 전역 PATH는 변경하지 않았다.

제한 셸에서 사용자 홈 경로가 누락되어 첫 장치 조회가 완료되지 않았다. 그 작업은 중지하고 실제 Android 사용자 경로를 지정해 다시 조회했으며 ADB와 Flutter에서 에뮬레이터 연결을 확인했다. 시스템 실행 정책이나 보안 설정은 낮추지 않았다.

## 패키지와 생성기 검토

- 루트 package.json은 외부 의존성·설치 hook·lockfile이 없다. npm install 없이 Node 기본 모듈로 검사한다.
- apps-deployment/flutter/scripts와 ios/scripts는 package.json 및 lockfile v3를 검토했다. 레지스트리 출처와 설치 hook을 확인했고 지금 필요 없어 설치하지 않았다.
- infra/scripts는 별도 배포·외부 API용 의존성을 갖고 lockfile은 없다. 설치·실행하지 않았다. 이후 사용 전에 lockfile과 API 작업 범위를 별도 검토해야 한다.
- Flutter 앱 폴더·pubspec.yaml·lib/main.dart는 없다. Dart 의존성·앱 lockfile·앱 빌드는 현재 해당 없음이다. npm workspace·추가 monorepo 도구·공유 Dart 코드를 강제하지 않았다.
- new-app --help 및 실제 코드를 대조했다. 허용 플랫폼은 flutter·ios·macos이며 문서·설정 7개만 생성한다. React Native를 지원하는 값으로 가장하지 않는다.
- 설치된 Flutter create --help도 대조했다. Flutter 생성기의 --platforms 값은 ios·android·windows·linux·macos·web 등이며 flutter라는 플랫폼 값은 없다. 실제 앱 소스 생성은 별도 단계다.
- 카테고리/앱 경로·식별자·호스팅·boolean·중복 옵션을 검증하고 셸·HTML 문맥별 escaping을 적용했다. 기존 폴더 덮어쓰기와 링크 경로를 방어한다.
- 정적 사이트는 전용 출력 이름, 소유 표시·목록·해시, 링크·비밀·데이터 파일 검사를 거친다. 카테고리/앱별 공개 경로를 보존하며 사용자 수정 파일을 자동 삭제하지 않는다.
- check-env는 기본적으로 설정을 source하지 않는다. 명시적 검토 옵션에서만 Bash로 실행하고 허용 변수의 설정 유무·키 파일 존재만 표시한다. 전체 환경변수를 출력하지 않는다. 템플릿 설정과 연결된 shared.config.sh를 검토했으며 실제 앱 설정 실행은 하지 않았다.

## 규칙과 제외 설정

루트·앱 템플릿·배포 공통 AGENTS.md와 쌍을 이룬 Codex/Claude skill에 사용자 범위를 반영했다. CLAUDE.md의 AGENTS.md 참조를 유지했다. 자동 commit·push와 스토어 API 실행 지시를 제거하거나 사용자 수동 작업이 우선하도록 정리했다.

.gitignore는 환경 파일·서명·키·실제 데이터·로그·캡처·로컬 도구를 제외한다. 가상 경로를 git check-ignore로 확인하고 앱 pubspec.lock 및 배포 package-lock.json은 제외되지 않도록 검사한다. 현재 Git index는 비어 있다. 추적 중인 비밀이 있는데 ignore만 추가한 상태가 아니다.

AI 제외는 .codex/config.toml과 .claude/settings.json에 별도 준비했다. Codex CLI 설정 시작과 Claude JSON 문법 확인은 성공했다. 다만 현재 관리형 legacy sandbox에서 새 Codex deny 프로필의 실제 적용, Claude 런타임, 가상 canary를 통한 OS 차단은 미확인이다. 실제 비밀을 넣지 않는다. 구체적인 적용 한계는 AI-EXCLUSIONS.md에 기록했다.

## 실행 결과

| 검사 | 결과 |
|---|---|
| npm.cmd run ci | 통과: 문서·민감정보/추적 파일·JavaScript·Bash·Terraform·회귀 테스트 |
| Node JavaScript 문법 | 50개 대상 통과 |
| Git Bash 문법 | 16개 대상 통과 |
| Terraform fmt -check -recursive infra/aws | 통과, 외부 인프라 연결 없음 |
| 생성기 회귀 테스트 | 9개: 경로·입력 escaping·덮어쓰기·출력 소유권·비밀 파일·junction·환경 로드·Git 제외 |
| Flutter doctor / devices | Android 개발 준비 및 실행 중인 에뮬레이터 확인 |
| 실제 앱 check-env·flutter analyze/test/build/run | 앱 없음으로 미실행 |
| F5 launch.json | 앱 생성·실행 보류 선택에 따라 구성하지 않음 |
| shellcheck / Linux·macOS에서 CI 실행 | 미실행, Git Bash -n을 shellcheck로 표시하지 않음 |
| GitHub Actions 원격 실행 / 스토어·호스팅·AWS | 미실행 |

회귀 테스트는 .test-tmp 아래 가상 문서 fixture만 생성하고 삭제한다. 실제 Flutter 앱이나 스토어 자료를 생성하지 않는다. 정적 사이트 테스트도 임시 로컬 폴더만 사용하며 공개 산출물을 전송하지 않았다.

2단계 이후 실제 앱 이름·목적·기능·유료 방식·식별자·호스팅·로그인/결제 설계를 사용자가 별도로 전달하면 다음 단계를 시작한다.
