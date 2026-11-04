# 8단계 개발용 원격 설정 결과

2026-10-27 후속: 사용자가 Apple 계정 로그인 완료와 유료 멤버십 없음·결제 절대 금지를 확인했다. 실제 Apple 콘솔 설정·capability·Mac/iPhone 인증은 미완료이며 `APPLE_READY=false`를 유지한다. 원격 UI 도구 미연결로 콘솔을 조작하지 않았고 가입/청구/키 생성을 하지 않았다. 로컬 9단계 결과는 [계정 관리 결과](ACCOUNT-MANAGEMENT-RESULTS.md), 아래는 이전 콘솔 작업 이력이다.

2026-10-19~20. 사용자가 원격 개발 설정을 요청하고, Firebase 약관·무료 개발 프로젝트 생성·본인 Google 연락처/테스트 계정 사용·카카오 개발자 가입·Google 클라이언트 3개와 카카오 개발 앱 생성을 각각 승인했다. 카카오 앱의 개발자/단체명은 사용자가 지정한 **케일**이다. 이후 사용자가 **무료 유지·가능한 설정과 로컬 검증 마무리**, 원하지 않은 결제 금지, 중요한 변경 전 확인을 명시했다. 이 선택을 현재 범위로 적용한다.

2026-10-20 저장 체크포인트: 사용자가 여기까지 저장하고 Apple 로그인 후 알려주겠다고 요청했다. 현재 소스·공개 개발 설정·검증 결과를 로컬 파일에 저장한 상태에서 추가 작업을 멈춘다. Apple 로그인 완료 안내를 받으면 이 지점부터 상태를 확인해 이어간다. 자동 재시도·예약 작업·결제·배포·commit/push는 하지 않는다.

**실제 앱 로그인 성공이나 8단계 전체 완료로 표시하지 않는다.** 개발 등록과 공개 설정 준비를 마쳤고, 아래 서버·기기 검증은 남아 있다. Apple은 마지막 순서이며 비밀번호/2단계 인증은 공식 사이트에서 사용자가 직접 확인한다. 스토어 등록/업로드/결제·유료 요금제·운영 DB·다른 앱은 변경하지 않는다.

## 개발자 콘솔에서 확인한 상태

| 대상 | 완료한 무료 설정 | 미완료/미검증 |
|---|---|---|
| Firebase | `AIRZERO STRIKE DEV` / `airzero-strike-dev`, 프로젝트 번호 `843748140344`, **Spark 무료**. Android/iOS 앱 1개씩 등록 | 결제 계정/Blaze 미연결. Auth 운영 정책·Firestore DB/지역·규칙·IAM·App Check·서버 배포 미적용 |
| Google | 같은 프로젝트의 `AIRZERO STRIKE Android DEV`, `AIRZERO STRIKE iOS DEV`, `AIRZERO STRIKE Server DEV` OAuth 클라이언트 3개. 외부 **테스트 중**, 승인받은 본인 계정 1개만 테스트 사용자로 등록 | 실제 Android/iOS 계정 선택·취소·토큰 검증·앱 복귀 미실행. 릴리즈/Play App Signing 서명 별도 |
| 카카오 | `AIRZERO STRIKE DEV`, App ID `1614509`, 케일, 엔터테인먼트 분류. 로그인 ON·OpenID Connect ON. 대표 Native Key에 Android 패키지/개발 키 해시와 iOS Bundle ID 저장·재조회 대조 | 실제 Talk 설치/미설치 OS 왕복·취소·동의 거절·서버 검증 미실행. 운영 전 연결 해제 웹훅/보관 정책 검증 필요 |
| Apple | 기존 native 구현·entitlements 유지, Firebase iOS/Google iOS/카카오 iOS 등록은 준비. 마지막 순서로 공식 로그인 창 열기 | 사용자가 비밀번호 확인이 필요해 **보류** 선택. Apple 개발자 로그인·capability·Team/프로비저닝·Mac 빌드·실제 iPhone 확인 대기. Apple 활성화는 false |

Android applicationId와 iOS Bundle ID는 모두 기존 `com.example.raikeopeu2026.dev`를 유지했다. App Store ID·Apple Team은 임의 입력하지 않았으며 스토어 가입/등록을 하지 않았다. Google의 AI agent 옵션·추가 API scope·프로덕션 게시를 선택하지 않았다. Firebase 프로젝트 생성에서 선택적 Analytics/Gemini/Google Developer Program 가입은 켜지 않았다.

Firebase 공개 앱 ID:

- Android: `1:843748140344:android:c55d41bf9cf7d1d79d0dcd`
- iOS: `1:843748140344:ios:d5be6b16df00e0399d0dcd`

현재 **공개 debug APK 인증서**에서 얻은 SHA-1/SHA-256을 Firebase Android 앱에 등록했다. 개인 키나 keystore 비밀번호를 읽지 않았다. Google Android SHA-1과 카카오 Base64 키 해시는 같은 개발 인증서의 digest를 각각 해당 형식으로 사용했다. 릴리즈/Play App Signing 인증서로 검증한 것은 아니다.

카카오 동의항목에서 닉네임·프로필 사진·친구·메시지·캘린더는 사용 안 함, 이메일·전화번호·이름·성별·생일 등은 권한 없음 상태를 확인했다. 추가 개인정보 수집·카카오싱크·비즈 앱·비즈월렛·유료 API를 신청하지 않았다. 회원식별과 OIDC 검증에 필요한 범위를 유지한다.

## 컴퓨터에 준비한 공개 설정

[config/README.md](../config/README.md)의 `config/.local-public/`에 Android/iOS 공개 구성과 서버 공개 대조표를 저장했다. 모바일 파일은 플랫폼별 Firebase 공개 API key/App ID와 Google 공개 Client ID·카카오 Native App Key만 포함한다. 서버 파일은 모든 provider READY가 false이며 배포 환경이나 Secret을 대신하지 않는다.

iOS는 `AuthPublic.xcconfig`가 선택적으로 읽는 `AuthPublic.local.xcconfig`에 공개 콜백만 저장했다. 기본 F5 전투·로컬 이메일 시험·일반 무료 게임 기록은 유지한다. 실제 서버 준비 전에는 이 파일로 빌드했다고 로그인이 연결됐다고 안내하지 않는다. 기본 소스의 미설정 값도 남겨 다른 개발 환경에서 성공을 가장하지 않는다.

공개 설정 폴더와 iOS 로컬 파일은 앱 `.gitignore`에 추가했다. Git 제외가 비밀 보호를 보장하지 않는다는 안내를 포함했다. 관리자 키·서비스 계정 키·Google Web client secret·카카오 Admin Key·HMAC 비밀·공급자 토큰·비밀번호는 이 파일에 넣지 않았다. Google 지원/연락처 이메일은 승인받은 콘솔 설정에만 사용하고 소스·문서에 복사하지 않았다. Firebase 공개 구성 다운로드 이벤트는 원격 브라우저에서 제한 시간 내 완료되지 않아 성공으로 기록하지 않았다. 대신 해당 프로젝트에서 Firebase가 자동 생성한 플랫폼별 **공개 SDK key**만 확인했다.

`asia-northeast3`은 기존 서버 코드의 계획된 엔드포인트 지역을 공개 설정에 맞춘 것이다. 실제 DB 생성·자료 위치 확인이나 Firebase Auth 처리 위치 확정을 의미하지 않는다.

## 무료 범위의 명확한 한계

Firebase Functions 화면에서 **결제 계정(Blaze) 필요**가 표시되는 것을 확인했다. [공식 요금표](https://firebase.google.com/pricing)도 함께 참고한다. 사용자가 무료 유지를 선택했으므로 업그레이드·결제수단·청구 계정·유료 서비스·서버 배포를 실행하지 않았다. 무료 사용량이나 홍보 크레딧을 무조건 비용 0원으로 설명하지 않는다. 예산 알림도 비용 차단 한도가 아니다.

이 앱의 소셜 인증은 서버 challenge → 공급자 검증 → 내부 UID → Firebase custom token → 앱 세션 순서다. 서버 없는 클라이언트 성공이나 직접 Firebase 소셜 로그인으로 우회하지 않는다. Spark에서 개발 앱 등록을 마친 상태와 실제 인증 서버가 연결된 상태는 다르다. App Check/IAM/규칙 미설정을 전체 허용이나 가짜 토큰으로 우회하지 않는다.

## 이번 확인과 다음 조건

콘솔 등록명/앱 ID/개발 서명, Google 테스트 계정 1개, 카카오 ON/OIDC ON/플랫폼 저장 값/최소 동의항목, 공개 설정 형식/앱 경계를 확인했다. 로컬 검사 최신 결과는 [SOCIAL-AUTH-RESULTS.md](SOCIAL-AUTH-RESULTS.md)의 원격 설정 후 재검증 부분에 기록한다. 과거 합성 proof/에뮬레이터 통과를 실제 공급자 로그인 성공으로 바꾸지 않는다.

최종 재검증은 분석 문제 없음·Flutter95개·서버 단위12개/통합23개·공개 설정 Android debug 빌드 통과다. APK의 기존 ID/카카오 callback/등록된 개발 인증서도 일치한다. 컴파일용 APK를 설치하거나 실제 계정으로 로그인하지 않았다. 문서78개·변경 소스 민감/개인 연락처 패턴·상대 링크83개 검사를 통과했다. Git 기반 제외/전체 민감 검사는 소유권 보호에 막혀 별도 미검증이며 보호를 완화하지 않았다.

Apple 비밀번호 확인 후에도 Mac/Xcode·실제 서명·iPhone 없이는 iOS native 검증이 완료되지 않는다. Apple Developer 유료 가입은 진행하지 않는다. 이후 실제 서버 연결 방식을 사용자가 결정할 때 비용·지역·권한·비밀 관리·배포 직전 변경을 설명하고 확인받는다. 결제·계정 삭제·전체 게임 동기화 등 다음 기능 개발은 시작하지 않는다.
