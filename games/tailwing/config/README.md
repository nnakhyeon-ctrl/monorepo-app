# 개발용 공개 인증 설정

10단계 공개 점검: `node tool/check_billing_readiness.mjs`는 `billing.public.example.json` 또는 선택적인 `.local-public/billing.dev.public.json`의 상품 ID/정책 주소 형식과 누락을 값 노출 없이 확인한다. 현재는 ID7개·주소4개 미설정, 구매 비활성 예시만 있다. 예시/점검 파일은 서버 런타임/배포 입력이 아니며 Secret을 넣지 않는다. 실제 콘솔·계정/결제 검증은 별도다. 앱의 공개 정책 주소 빌드 설정과 직접 입력 순서는 [결제 준비](../docs/BILLING-SETUP.md)를 따른다. 기존 인증 공개 파일과 READY는 변경하지 않았다.

2026-10-27: 기존 공개 파일/콜백의 오프라인 대조16개 통과. 앱 폴더에서 `node tool/check_auth_readiness.mjs`로 값 출력 없이 다시 확인할 수 있다. 이 도구의 PASS는 콘솔·배포·실제 로그인·기기 검증 완료가 아니다. 접속 위치와 확인/입력 항목은 [실제 연결 준비 안내](../docs/ACCOUNT-LIVE-SETUP.md)를 따른다. 공개 설정 파일이나 준비 플래그는 이번에 변경하지 않았다.

`.local-public/`은 이 컴퓨터의 AIRZERO STRIKE 개발 등록에서 확인한 **공개 클라이언트 설정만** 담는다. 일반 소스와 구분하는 Git 제외 로컬 폴더다. Git 제외는 접근 통제나 비밀 저장소가 아니다. 비밀번호·토큰·client secret·서비스 계정 JSON·서명 개인 키·HMAC 비밀은 이 폴더에 넣지 않는다.

- `android.dev.public.json`, `ios.dev.public.json`: 플랫폼별 Firebase 공개 구성·Google 공개 Client ID·카카오 Native App Key. Apple 활성화는 false다.
- `server.dev.public.json`: 향후 서버 설정에 대조할 공개 식별자이며 배포 파일이나 완성된 서버 환경이 아니다. 모든 provider READY는 false다. 서버 전용 비밀·서비스 계정/IAM은 포함하지 않는다.
- iOS의 `ios/Flutter/AuthPublic.local.xcconfig`는 공개 콜백 스킴만 담으며 기본 `AuthPublic.xcconfig`에서 선택적으로 읽는다.

2026-10-20 현재 Firebase는 무료 Spark다. Functions·Firestore·App Check·실제 인증 서버를 배포/적용하지 않았다. `asia-northeast3`은 기존 코드의 계획된 엔드포인트 지역이며 DB 생성/위치 확인을 의미하지 않는다. 공개 구성 파일 준비나 빌드 성공을 실제 로그인 성공으로 표시하지 않는다.

기본 F5 전투와 가상 데이터용 이메일 로컬 시험은 그대로 사용한다. 실제 서버 준비 후에만 다음처럼 플랫폼에 맞는 파일로 빌드/실행한다.

```powershell
flutter run --dart-define-from-file=config/.local-public/android.dev.public.json
```

iOS는 Mac/Xcode·실제 서명/프로비저닝·App Check·물리 기기 검증이 별도로 필요하다. Apple 비밀번호는 공식 사이트에 사용자가 직접 입력한다. 현재 상태와 남은 조건은 [원격 설정 결과](../docs/SOCIAL-REMOTE-SETUP.md)를 따른다.
