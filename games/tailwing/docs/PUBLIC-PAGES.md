# 지원·개인정보·삭제 페이지 준비 계획

입력한 Cloudflar는 Cloudflare Pages로 해석했다. 사용자 가입·Cloudflare 프로젝트·도메인 연결·배포·공개를 실행하지 않는다. 원본 new-app 생성기의 hosting enum에는 Cloudflare가 없으므로 지원하지 않는 값을 억지로 전달하거나 AWS/Netlify로 바꿔 기록하지 않고 문서를 직접 준비했다.

로컬 초안은 [pages/support.md](pages/support.md), [pages/privacy.md](pages/privacy.md), [pages/delete-account.md](pages/delete-account.md), [pages/terms.md](pages/terms.md)다. 현재는 비공개 기획 문안이고 HTML/요청 서버가 아니다. 다음 해당 단계에서 실제 SDK·운영자·연락처·보관 기간을 확정한 뒤 로컬 HTML로 만들고 링크/모바일/삭제 요청을 검증한다.

2026-10-18 서버 저장 변경을 반영해 계정 게임 기록 전송·다른 휴대폰 이어하기·동기화 대기/충돌·서버/기기 삭제 범위도 초안에 포함했다. 공개 문서 호스팅과 개인별 게임 저장 API/DB는 분리하며 게임 기록을 정적 사이트에 업로드하지 않는다.

## 공개 경로 설계

사용자가 확정할 도메인의 /games/tailwing/ 아래에 support/·privacy/·delete-account/·terms/를 계획한다. 현재 URL이 존재하거나 작동한다고 표시하지 않는다. 앱명·개발자 정보·문의 방법과 실제 요청 경로를 채우기 전에는 공개 초안/스토어 제출 URL로 사용하지 않는다.

Cloudflare Pages는 정적 HTML을 받을 수 있다. 실제 공개는 사용자가 로컬 검증 산출물만 직접 업로드하는 흐름을 우선 고려한다. 자동 Git 배포를 지금 켜지 않는다. Direct Upload와 Git 통합은 프로젝트 방식에 차이가 있으므로 공개 시 사용자가 선택한다. [Cloudflare 정적 HTML](https://developers.cloudflare.com/pages/framework-guides/deploy-anything/), [Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/).

계정 삭제 페이지의 안내만으로 삭제 기능을 충족한 것으로 표시하지 않는다. 사용자가 앱을 재설치하지 않고 요청할 수 있는 보호된 웹/지원 경로를 9단계에 구현·검증한다. 인증/본인 확인·요청 제한·처리 상태·세션 철회/데이터 삭제는 서버가 수행하며, 공개 정적 파일에 토큰·거래·개인 데이터를 넣지 않는다. 지금 문의 메일이나 실사용자에게 메시지를 보내지 않는다.

기존 정적 생성기는 앱 docs/index.html을 대상으로 하므로 현재 Markdown 초안은 배포 산출물로 복사하지 않는다. HTML 도입 단계에서는 내부 설계/비밀 자료와 공개 파일을 분리하고 허용 파일만 전용 출력에 모은다. 출력 경계·소유 표시/해시·링크/비밀/데이터 파일 방어를 유지한다. 전체 docs나 저장소를 Cloudflare 업로드 폴더로 지정하지 않는다.

AWS를 선택하지 않았으므로 AWS 리소스·Terraform init/plan/apply는 계획 대상이 아니다. 루트 CI의 Terraform fmt는 원본 참고 구성 문법/포맷 검사용 의존성일 뿐 앱 인프라를 AWS로 선택한 것이 아니다.
