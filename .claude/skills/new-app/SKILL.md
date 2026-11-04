---
name: new-app
description: 확인된 단계에서 앱 문서와 설정만 준비하는 생성기를 안내한다.
---

# 새 앱 문서 준비

루트 AGENTS.md를 먼저 따른다. 현재 2단계에서는 실제 앱을 만들지 않는다. 다음 단계 지시가 오면 앱 이름·카테고리·식별자·플랫폼을 확정한다.

node scripts/new-app.mjs --help로 허용 값을 확인한다. 플랫폼은 flutter·ios·macos만 지원하며 문서·설정 7개만 생성한다. 실제 Flutter/네이티브 소스는 별도 생성기와 빌드 설정이 필요하다. React Native는 지원하지 않는 플랫폼 값을 넘기지 않는다.

PowerShell에서는 명령을 한 줄과 안전한 인자로 전달하고 셸 문법을 섞지 않는다. 입력 텍스트는 HTML/셸 문맥에 맞게 escape한다. 기존 앱에는 명시적 검토 없이 --force를 사용하지 않는다.

앱별 README·AGENTS·CLAUDE·ROADMAP을 유지하고 앱 경계를 분리한다. 배포 키·실제 데이터는 저장소 밖에 둔다. check-env는 기본적으로 설정을 실행하지 않으며 source 대상까지 검토한 뒤에만 --load-reviewed-config로 검사한다.

실제 앱 생성·기능 구현은 사용자가 해당 단계를 요청한 경우에만 진행한다. 스토어 작업은 사용자가 직접 수행한다.