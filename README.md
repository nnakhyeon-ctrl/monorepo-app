# Flutter 앱 작업 저장소

2026-11-05 후속 캐릭터/아이템 개선: 사용자 요청으로 오류 검증·수정, 기존 세라 원화3장/12종 역할·조종 팁, 새 스킬3종/아이템3종을 추가했다. Flutter237·서버21/가상44·정적 분석/루트 검사를 통과했다. [최신 결과](games/tailwing/docs/CHARACTER-ITEM-RESULTS-2026-11-05.md)를 우선한다. 원본/12종·무료3종·기록/구매 경계를 보존하고 GitHub 저장하며 스토어/서버/페이지 배포는 하지 않는다.

2026-11-05 사용자 명시 재개: 첨부 게임은 일반적인 탄막/가독성 참고만 사용하고 테일윙의 독자 기체 동작·적 7유형·고급 스킬 6종·HUD·검증 기반 구독 해금을 구현/검사한다. 이번 검토 결과의 로컬 commit 및 nnakhyeon-ctrl/monorepo-app GitHub 저장을 허용했다. [최신 결과](games/tailwing/docs/COMBAT-EXPANSION-2026-11-05.md)를 우선하며 아래 11월 4일 중단은 과거 기록이다. 무료 3종·방패 수치·앱 ID/데이터/구매 경계는 보존하며 스토어/서버/페이지 배포는 하지 않는다.

테일윙 최신 12·13단계는 [로컬 출시 자료](games/tailwing/docs/release-prep-2026-11-04/index.html)·[검증/미검증 결과](games/tailwing/docs/STAGE12-13-2026-11-04.md)를 따른다. 서명 제출 파일·실서비스/공식 테스트는 미완료이며 만족할 때까지 계속 편집한다. 최신 보안 감사 moderate 전체16/production6을 대기로 기록했다. 게시/배포는 하지 않는다.

현재 앱은 **테일윙 · TAILWING**, 폴더는 `games/tailwing`, 작업공간 파일은 `tailwing-codex.code-workspace`다. 기존 GitHub `main`에 [전체 소스 저장](https://github.com/nnakhyeon-ctrl/monorepo-app/tree/main/games/tailwing)을 완료했다. [이름 변경·검증 결과](games/tailwing/docs/TAILWING-RENAME-2026-11-04.md)를 따른다. 아래 이전 이름/인증 실패 문구는 당시 이력이다.

2026-11-04 전체 검증 후속은 [테일윙 결과](games/tailwing/docs/VERIFICATION-2026-11-04.md)를 따른다. 전체 Flutter 185개·서버 단위 21개/demo 43개·루트 CI 통과. 사용자 요청으로 기존 GitHub에 검토된 소스/자산/문서를 저장하며 로컬 SDK·비밀·빌드 캐시는 제외한다.

2026-11-04 테일윙 재개: [중단 지점·Git/GitHub·현재 PC 복구](games/tailwing/docs/RESUME-2026-11-04.md). 최신 대상은 같은 `games/tailwing/` 앱이다. 기존 디자인 적용과 미검증 Android 실행/성능을 구분한다.

2026-10-20 AIRZERO STRIKE의 최신 원격 후속은 [개발 등록 결과](games/tailwing/docs/SOCIAL-REMOTE-SETUP.md)다. 승인받은 무료 Firebase 프로젝트·Google 클라이언트 3개·카카오 플랫폼/OIDC·공개 설정을 준비했다. 무료 Spark 유지·원하지 않은 결제 금지·중요 변경 전 확인을 적용한다. 실제 서버 로그인·Apple/iOS native는 미검증이며 Apple은 마지막이다. 아래는 이전 로컬 단계의 이력이다.

AIRZERO STRIKE 최신 요청은 [8단계 소셜 로그인](games/tailwing/docs/SOCIAL-AUTH-RESULTS.md)이다. 사용자가 선택한 로컬 우선 범위로 Google·카카오·iOS Apple을 기존 인증에 연결하고 자동 병합/기록 손실을 막는다. 실제 공급자 등록/로그인·운영 적용은 대기이며 [사용자 설정 순서](games/tailwing/docs/SOCIAL-SETUP.md)를 따른다. 아래 이전 단계의 소셜 제한은 당시 이력이다. 다른 앱·가입/배포·commit/push는 진행하지 않는다.

AIRZERO STRIKE의 최신 작업은 [7단계 이메일 인증](games/tailwing/docs/EMAIL-AUTH-RESULTS.md)이다. 기존 Firebase/계정 화면에 공식 SDK를 연결하며 무료 기기 플레이·기록/설정을 유지한다. 로컬 검증과 실제 메일/앱 복귀/운영 설정 대기를 구분하고 클라우드/스토어 배포는 하지 않는다. 아래 기본 화면/SDK 미연결 설명은 이전 작업 이력이다.

최신 변경은 AIRZERO STRIKE의 실제 무료 전투·15탄·기기 기록 저장·유료 선택 능력·협동 시험 구현입니다. 수익 모델은 기본 무료+추가 콘텐츠 월간/연간 구독이며 가격은 관리자 최종 설정 대기입니다. 완료/검증/외부 연동 대기는 [현재 실행 기록](games/tailwing/docs/PLAYABLE-RESULTS.md)과 [출시 준비표](games/tailwing/docs/RELEASE-READINESS.md)를 확인하세요.

사용자가 새 앱 이름을 ‘AIRZERO STRIKE’로 선택했습니다. 작업 폴더는 games/tailwing이며 메인 타이틀·앱 표시명·F5 설정·문서 경로를 맞췄습니다. 기존 라이커프 시리즈 2026·스톰윙과 같은 앱이며 개발 식별자는 유지합니다. 출시 명칭·상표 가용성은 미확인입니다.

Windows 11에서 Flutter 개발을 위한 2단계 준비와 3단계 계획을 마치고 [AIRZERO STRIKE](games/tailwing/README.md)의 4단계 실제 Flutter 프로젝트·기본 화면을 준비했습니다. 원격은 [사용자 저장소](https://github.com/nnakhyeon-ctrl/monorepo-app)이며 commit·push는 하지 않았습니다. Untitled-1.txt는 기존 빈 파일입니다.

## 현재 구조

- scripts/: 루트 Node 검사 도구와 문서 생성기 (외부 npm 의존성 없음)
- templates/: 앱 README·AGENTS·CLAUDE·ROADMAP·설정·HTML 템플릿
- apps-deployment/: 보존된 배포 참고 도구, 현재 실행하지 않음
- infra/: 호스팅 참고 구성, 선택·공개·인프라 생성 없음
- docs/SETUP-RESULTS.md: 환경·검사 결과와 미실행 항목
- docs/AI-EXCLUSIONS.md: Git 제외와 AI 접근 제한의 차이
- games/tailwing/: 실제 Android/iOS Flutter 프로젝트, 격납고 첫 화면과 계정·이용권·기록 안내 화면. 핵심 게임과 실제 서비스 연결은 이후 단계

앱별 pubspec.yaml·pubspec.lock과 루트 Node 도구를 분리합니다. npm workspace·Melos·공유 Dart 패키지는 강제하지 않습니다. 배포용 Node 패키지는 별도 폴더에 있고 현재 설치하지 않았습니다.

앱 실행과 F5 안내, 검증 결과는 [4단계 기록](games/tailwing/docs/STAGE4-RESULTS.md)을 따릅니다. VS Code 실행 구성은 .vscode/launch.json에 있으며 기존 settings.json은 보존했습니다.

## Windows에서 검사

PowerShell 터미널에서 저장소 루트 기준으로 실행합니다. npm.ps1 대신 npm.cmd를 사용하며 실행 정책을 바꾸지 않습니다.

```powershell
npm.cmd run ci
node scripts/new-app.mjs --help
```

CI는 문서·민감정보/추적 파일·JavaScript 문법·Git Bash 문법·Terraform 포맷·생성기 회귀 테스트를 포함합니다. find/xargs에 의존하지 않고 각 파일을 argv로 전달합니다. 도구가 없거나 검사가 실패하면 실패로 보고합니다.

Terraform은 원본 CI와 같은 1.9.8을 .tools/terraform/1.9.8/에 로컬로 준비했습니다. AWS 선택을 뜻하지 않으며 fmt만 실행합니다. 전역 PATH·인프라·클라우드 계정은 바꾸지 않습니다. .tools는 Git에서 제외됩니다.

## 다음 단계의 앱 경계

현재 생성기 지원 값은 flutter·ios·macos입니다. new-app은 문서·설정 7개만 만듭니다. 실제 Flutter 소스는 별도 flutter create로 만들고 앱 폴더에서 Dart 의존성과 빌드를 관리합니다. iOS/macOS 빌드는 Mac/Xcode가 필요합니다. React Native/Expo는 이 생성기에 지원하지 않는 값을 넘기지 말고 문서를 재사용한 뒤 별도 공식 생성기와 빌드 구성을 사용해야 합니다.

경로는 단일 kebab-case 카테고리/앱 이름, 식별자는 소문자 reverse-DNS, 호스팅은 undecided·netlify·vercel·aws만 허용합니다. 기본 com.example 식별자는 설명용이며 실제 배포 전에 앱별로 확정해야 합니다. --force=true는 지정된 템플릿 7개를 덮어쓰므로 기존 앱에는 신중히 사용합니다.

check-env는 배포 설정 검사이며 현재 단계의 필수 검사가 아닙니다. 기본 실행은 설정 존재만 확인합니다. 모든 설정과 source 파일을 먼저 읽은 후 명시적으로 --load-reviewed-config를 주어야 Bash로 로드하며, 값 대신 설정 유무와 파일 존재만 출력합니다. 앱별 키를 지금 만들거나 입력하지 않습니다.

정적 사이트는 공개용으로 직접 검토한 앱 docs만 모읍니다. 출력 경로는 public-site 또는 public-site-이름만 허용하고 소유 표시·목록·해시가 일치한 이전 출력만 교체합니다. 비밀·데이터·로그·링크 파일을 거부하며 공개 URL 경로는 /<category>/<app-name>/입니다. 이미지·문장에 실제 개인정보가 없는지도 사람이 확인해야 합니다. 이 명령은 로컬 생성만 수행합니다.

스토어 등록·업로드·테스트 배포·심사 제출·공개는 사용자가 직접 수행합니다. Git commit·push도 자동 실행하지 않습니다. 다음 단계는 사용자가 별도로 전달할 때 시작합니다.

## 원본 보존

[원본 템플릿](https://github.com/limsangjin12/app-templates)을 스냅샷 9d9867935af7f10e621f2ee5f89cf2a2132c4057에서 가져왔습니다. 원본 ZIP·복제본은 작업 폴더 밖 CreatorTemp에 보존했습니다. 로컬 origin은 사용자 저장소만 가리킵니다. 원본 LICENSE를 유지합니다. 보존된 참고 문서보다 AGENTS.md와 사용자 제한을 우선합니다.
