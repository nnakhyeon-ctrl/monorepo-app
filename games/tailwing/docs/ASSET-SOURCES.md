# 기본 화면 자산 출처

## 테일윙 12종·탑승 기체·SF 월드 — 2026-10-29 최신

현재 홈/캐릭터/실전은 새 `assets/tailwing/` 27개 PNG와 자체 Flutter 효과를 사용한다. [원본·제작/수정 이력·사용 조건 확인 상태](tailwing/ASSET-SOURCES.md), [정확한 프롬프트](TAILWING-ART-JOBS.json), [런타임 해시/규격](TAILWING-ASSET-INVENTORY.json), [실제 화면](tailwing/index.html)을 따른다. 내장 imagegen의 AI 생성 자산이며 첨부 상용 게임 이미지를 도구 입력/추출/트레이싱하지 않았다. 곰/수달 수정 입력도 자체 생성 원본만 사용했다. 기존 그림은 호환/제작 이력으로 보존한다. 아래 ‘현재’라는 표현은 각 과거 단위 당시의 상태다. 외부 권리/상표/독점성을 검증 완료로 표시하지 않는다.

## 실제 항공 전투 그래픽 — 2026-10-19 최신

사용자의 최신 ‘기존 항공기/세계관 유지·고해상도 실제 플레이’ 요청에 맞춘 자산이다. 내장 image_gen 모드로 직접 제작했고 아래 원본은 ~/.codex/generated_images/01a1495d-1cc0-7f13-9c55-c05f365743f8/에 보존했다. 오로라는 기존 자체 제작 aurora_player.png를 편집 대상으로 사용했고 나머지는 신규 생성했다. 참조 이미지·상용 게임 픽셀/도형·기체 명칭/국기·문구·워터마크는 복제하지 않았다. 리소스 다운로드·CLI/API 키·새 패키지 없음. PNG를 그대로 복사했으며 원본 후처리/재인코딩은 하지 않았다.

| assets/images 파일 | 원본 PNG 크기·투명 | 생성 원본 파일 | SHA256 |
|---|---|---|---|
| aurora_aviation_hd.png | 1254×1254·투명 | exec-ce7bb94a-3d62-4d5a-8a5f-ffa093f96e1e.png | 4E3F7ECBC8A532B1EDE85FCB9119DD347BB7E2160D69BBAE383FCCD6542A7B84 |
| dawn_coast_hd.png | 1024×1536·불투명 | exec-c43cc99a-a082-4619-a7dc-80dbe3c26be6.png | F41EE825536CA74014894BB2A59DC22C74E9515F7C6B95E1F122F10ABB6A4849 |
| enemy_aviation_atlas.png | 1254×1254·투명·2×2 셀 | exec-8b23512c-d89b-4bf8-99b5-b6e64ba95ca8.png | 03A30F686E8E07FAD2286E131A849ADD52A127C104EAE800D9310A625E6F5B6F |
| explosion_hd_atlas.png | 1774×887·투명·4×2 프레임 | exec-cb1d9dd8-4174-4570-8f35-6f5b91771490.png | 8619801CC878E94C1920C96397588D7B5114C9FAFDFDAC5EF1AF4F0FE141A4A8 |
| cloud_bank_hd.png | 1254×1254·투명 | exec-0bef1917-22a8-4888-a87f-9f5acce2d454.png | 28CFA7F70406C63A69C159814847DF035E3B7A762C5A89DA2BD7DDEEF9EDABF0 |

현재 대표/무료 실제 기체는 aurora_aviation_hd.png이며 기존 쌍동체·프로펠러 형태를 유지한다. 기존 vector_mk2/safeguard_mk2는 유지한다. 적 3종·지휘 폭격기는 아틀라스에서 UV로 읽는다. 전투 효과/보호막/디지털 패널 코드는 직접 작성한 Flutter Canvas/위젯이다. 최종 생성 프롬프트는 [AVIATION-ASSET-PROMPTS.md](AVIATION-ASSET-PROMPTS.md), 적용·검증 범위는 [AVIATION-GRAPHICS-RESULTS.md](AVIATION-GRAPHICS-RESULTS.md)에 기록한다.

사용 조건 확인(2026-10-19): [OpenAI 이용약관 Content](https://openai.com/policies/terms-of-use/)와 [서비스 계약 4절](https://openai.com/policies/services-agreement/)은 적용 법률 범위에서 사용자와 OpenAI 사이의 출력 소유를 사용자에게 귀속시키고, 입력 권한과 출력 사용 검토는 사용자 책임으로 정한다. 이 조건에 따라 앱에 사용할 자체 생성 출력이며 외부 리소스의 재배포 라이선스를 전제하지 않는다. 생성 결과의 독점성·제3자 권리 불침해를 별도 보장받은 것으로 표시하지 않는다. 레퍼런스의 제3자 상표·로고·실제 무기 명칭은 신규 자산에 넣지 않았다.

## 5단계 미래형 기체 — 2026-10-19

내장 image_gen으로 별도 신규 생성한 투명 PNG3종이다. 원본은 ~/.codex/generated_images/01a1495d-1cc0-7f13-9c55-c05f365743f8/에 보존하고 아래 앱 경로에 그대로 복사했다. 후처리/재인코딩·기존 이미지 덮어쓰기 없음. 최종 프롬프트는 [LOADOUT-ASSET-PROMPTS.md](LOADOUT-ASSET-PROMPTS.md)에 있다.

| 앱 경로 assets/images/ | 생성 원본 파일 | SHA256 |
|---|---|---|
| aurora_mk2.png | exec-439a29c2-b232-4176-9ada-96cc73a607d8.png | 98C8ADBE75564788F93AF229862FB505F6C041A468601127E057A6F41B44151E |
| vector_mk2.png | exec-19428076-dc92-4337-beb5-fea64aaa50a5.png | 6E2C3E82FF9EA86BBC954A8683A758EE6B6892083E430660C92AC8C86D6AA963 |
| safeguard_mk2.png | exec-47f0bdf6-31b0-45f6-950d-4252db4938dc.png | F48842CA41852DB5CF60B046126A942B285B49AD99809F0B6577B14CE031B17F |

실제 전투용 3종 모두 앞쪽이 위인 탑뷰다. Flutter에서 폭256으로 디코딩하고 투명 가장자리와 중앙 불투명 부분을 검사했다. 스킬/출격 배경은 독자적인 Canvas 벡터 그림이다. 아래의 이전 아트와 음원은 제작 이력으로 보존한다.

## 2026-10-19 로컬 음향 자산

`tool/make_audio.dart`로 직접 합성한 22,050Hz/16bit mono PCM WAV다. 원본 음악/샘플 다운로드·상용 게임 음원 복사·외부 API를 사용하지 않았다. 전투 배경음8초 루프와 사격/피격/스킬/클리어 효과음, 약404KB다. 기기 음질·루프/볼륨 균형은 추가 청취 조정 대상이다.

| assets/audio 파일 | SHA256 |
|---|---|
| flight_loop.wav | 904B12B3AE9FD588576504485CECBD05B5064EB6CBEF513F310E44684A3BF2E5 |
| shot.wav | E917DD467A637643D2A092AC01865F6261DE140321AEFB63269AAF41102278CE |
| hit.wav | 83A26935848B8AC9119C70815D570E9AD09C99079ADF97F1BC8826BF1ECF8357 |
| skill.wav | 4609C88E473DE3E8EF8423BB940A34051EC8D20C43D2202105F2ECEAB4602007 |
| clear.wav | F884256ED7ED12C8A4BE265AFED70CD43E200248A478BB3C09EE3A689641C9DC |

아래는 이전 이미지 생성 이력이다. 현재 첫 화면/전투 사용 파일은 상단 최신 절을 따르며 이전 파일과 키 아트는 보존한다.

이전 메인 화면에서 사용한 assets/images/flight_hero_v2.png와 assets/images/hangar_hero.png는 삭제하거나 덮어쓰지 않고 보존한다. 생성 방식·프롬프트는 아래 ‘메인 화면 새 비행 이미지’에 기록한다. 앞선 메뉴 단계의 aurora_player.png도 보존하며 최신 출격 준비 화면/전투는 위의 *_mk2.png를 사용한다.

전투/장비 구성안의 아트는 lib/features/concept_art.dart에 직접 작성한 Flutter CustomPainter 벡터다. AircraftPainter·BattleConceptPainter는 새 기체/공중 요새/탄환/예고를 그리고, 분류 아이콘은 Flutter Material Icons를 사용한다. 첨부 게임의 스프라이트·초상·국기·UI 장식·게임명을 복사하지 않았다. 해당 벡터 개편 당시에는 추가 bitmap 생성 도구/이미지 편집/SDK 설치를 사용하지 않았다.

2026-10-18, 4단계 기본 화면용 자산이다. 기존 상용 게임의 이미지·스프라이트·로고·음원은 가져오지 않았다. 향후 출시 명칭·기체 명칭·상표와 모든 추가 자산의 사용 조건은 12단계 전에 확인한다.

| 파일 | 출처·사용 |
|---|---|
| assets/images/flight_hero_v2.png | 내장 image_gen 도구로 새로 생성한 구름 속 전투기 비행 장면. 현재 메인 화면에 사용. 원본을 별도로 보존하고 프로젝트에 복사 |
| assets/images/hangar_hero.png | 최초 첫 화면의 격납고 키 아트. 기존 게임 스크린샷을 편집·복제하지 않았으며 이번 개편에서도 파일은 그대로 보존 |
| assets/brand/google_g.png | [Google 공식 자산](https://developers.google.com/static/identity/images/g-logo.png). Google 버튼의 G 표시, 색상/비율 유지. SHA256 D1CE9C2AF0B10A7333ABC99BC706F9A6A199E5B65BF3E3009624F076B8638E6A |
| assets/brand/kakao_login_official.svg | [Kakao 공식 로그인 SVG](https://developers.kakao.com/tool/images/resource/preview/login-complete-ko.svg). 스크립트·외부 참조·foreignObject가 없음을 확인. 런타임 SVG 라이브러리는 설치하지 않고 공식 심벌 path를 동일 기하로 CustomPainter에 옮김 |
| iOS Apple 버튼 | Flutter Material Icons의 Apple 심벌, 검은 버튼/흰 심벌·공급자 이름. iOS에서만 표시하며 실제 인증은 미연결. 실제 연동 단계에 공급자 공식 버튼/동작과 다시 대조 |
| 앱 아이콘·네이티브 시작 화면 | Flutter 공식 생성기의 기본 자산. 출시용 아트 완성으로 표시하지 않음 |

공식 버튼은 [Google 브랜드 지침](https://developers.google.com/identity/branding-guidelines), [Kakao 디자인 지침](https://developers.kakao.com/docs/ko/kakaologin/design-guide)에 맞춰 색상·이름·심벌을 유지했다. 소셜 버튼은 현재 연결 준비 안내만 표시하며 인증 성공을 흉내 내지 않는다.

격납고 이미지 SHA256: DE8A51D8BDC2D5C620857705B8BB8944D29334FABF796A515F9809B42B5B98C0.

## 최초 격납고 이미지 생성 방식과 프롬프트

내장 이미지 생성 도구를 사용했으며 API 키·별도 생성 CLI·외부 계정은 사용하지 않았다. 프로젝트에 저장한 최종 파일은 assets/images/hangar_hero.png다. 아래가 도구에 전달한 최종 프롬프트다.

```text
Use case: stylized-concept. Asset type: portrait mobile flight shooting game home-screen hangar hero artwork, not a UI mockup. Create a polished original P-38-inspired twin-boom propeller fighter parked in a spacious aircraft hangar, nose facing the viewer, slightly elevated front three-quarter view. The aircraft should read as a WWII-era twin propeller, twin-boom silhouette, clean unmarked silver-gray metal, restrained teal instrument lighting and subtle floor reflections. Dark navy and charcoal hangar walls, quiet cyan/teal guide lights, calm industrial atmosphere, symmetrical structural lines, no people, no combat, no fire, no smoke, no excessive glow. Aircraft centered in the middle of the portrait composition, wings fully in view with generous margins. Top 22 percent dark uncluttered negative space for a title that the app will render, bottom 28 percent dark quiet negative space for a button rendered by the app. Crisp detailed 2D painted game key art, controlled high contrast, sophisticated military aviation illustration. No text, no letters, no numerals, no logos, no real insignia, no emblems, no watermark, no UI controls. Original artwork, do not reproduce any existing game assets.
```

게임 제목·메뉴·버튼은 이미지에 합성하지 않고 실제 Flutter 텍스트/버튼으로 표시해 화면 크기·글자 확대·보조 기술을 지원한다. 생성 결과의 좌우 날개 끝에는 여유가 적으므로 게임 내 실제 기체 스프라이트로 재사용하지 않는다. 화면용 그림과 향후 충돌/조작용 게임 자산은 별개다.


## 메인 화면 새 비행 이미지

2026-10-18 imagegen 스킬의 기본 내장 image_gen 모드를 사용했다. CLI/API 키/별도 SDK 설치 없이 새로운 장면을 생성했다. 첨부된 현재 앱 캡처는 레이아웃 개선 참고이며 생성 도구에 편집 대상으로 전달하지 않았다. 상용 게임 자산·문구·로고·국기·캐릭터는 입력하지 않았다.

- 프로젝트 경로: assets/images/flight_hero_v2.png (1536×1024 PNG)
- SHA256: 76D174EFD9C31F36AA6651C17D662D4ACF794079855B20788422B84DBA473DD2
- 원본 위치: ~/.codex/generated_images/01a1495d-1cc0-7f13-9c55-c05f365743f8/exec-2092c5c6-921e-4ffe-a47d-954e3d21ca5c.png. 원본은 이동/삭제하지 않고 복사했다.
- 확인: 전체 기체·두 프로펠러·새벽 구름·남색/청록/호박색 빛, 글자/국기/수치 없음. 실제 화면은 전체 날개가 보이도록 contain 비율과 코드의 가장자리 그라데이션을 사용한다. 파일 자체의 후처리·재인코딩은 하지 않았다.
- 이름·상표/최종 출시 자료 검토는 별도이며 특정 게임의 후속작·공식 자산으로 표시하지 않는다.

최종 생성 프롬프트:

```text
Use case: stylized-concept.
Asset type: original hero illustration for a polished portrait mobile arcade flight shooter home screen. Generate only the artwork, not a UI screenshot.
Primary request: a compelling, clean cinematic flight scene that makes the player want to launch, with a single original twin-boom, twin-propeller silver fighter inspired by the structural era of WWII aircraft but with its own contemporary game design. Three-quarter front view from slightly above; the complete aircraft banks upward toward the viewer through layered storm clouds. The whole wingspan and both tail booms must be visible, strong readable silhouette at mobile size, restrained teal accents on metal and a warm amber rim light. Two naturally blurred propeller discs, crisp main airframe. No fire jets or rocket exhaust: it is propeller driven.
Scene/backdrop: deep midnight navy cloud canyon opening into a thin warm dawn horizon, a few subtle teal light streaks to suggest velocity. Atmospheric, spacious, inviting and focused, no clutter. The airframe should occupy the central 65 percent of the width with room around the wings; clouds fade into nearly solid navy at the outer edges so the art blends into an app background #09131E. Central crop must retain the entire plane.
Style/medium: high quality original 3D game key art with painterly atmosphere, realistic metal materials and intentional simple shapes, cinematic lighting, elegant and energetic rather than busy.
Composition/framing: landscape 3:2 composition, ideally 1536x1024. Central hero aircraft, clear depth and upward momentum, no other characters or aircraft. No text, letters, emblems, flags, insignia, numbers, logos, HUD, buttons, borders or watermark. Do not imitate or use assets from existing commercial games. Do not copy a specific game's visual composition. This is a brand new artwork, no supplied image is an edit target.
```

## 실제 전투 기체 스프라이트

2026-10-18 내장 image_gen 도구로 생성한 독자적인 탑뷰 기체다. API 키·별도 CLI·외부 계정 없이 생성했고 이미지 후처리/재인코딩은 하지 않았다. 기존 키 아트 두 파일과 생성 원본은 보존했다.

- 앱 경로: assets/images/aurora_player.png
- SHA256: 792DDD3C2CA92E6F9FBE5C7CEAAC41B9C2A30847249762FDF8F3BB54D92FA910
- 원본: ~/.codex/generated_images/01a1495d-1cc0-7f13-9c55-c05f365743f8/exec-cb37556a-ad57-4b43-8569-3d960d585ac2.png
- 사용: 실제 전투와 첫 화면의 동일 기체. 런타임 256폭 디코딩, 전체 날개·투명 여백·작은 크기 실루엣을 검사했다. 적/보스·메카·탄환/배경은 앱 코드로 렌더한다. 상용 게임 이미지/로고/ROM을 앱 자산으로 복사하지 않았다.

최종 생성 프롬프트:

```text
Use case: stylized-concept. Asset type: a single production game sprite for an original mobile top-down arcade airplane shooter. Create one highly readable silver twin-boom twin-propeller fighter, WWII-era structural inspiration with original details, dark navy cockpit and restrained cyan/teal accents. Exact orthographic top view, nose points straight upward, bilateral symmetry, whole wings and both tail booms fully visible. A small clear central cockpit; clean metal panels and two subtle propeller blur discs. Polished illustrated 3D-game sprite, crisp silhouette and controlled detailing readable when rendered at 70 pixels. Aircraft occupies about 78 percent of a square canvas with generous transparent margin. No perspective, no text, logos, numbers, flags, insignia, weapons firing, shadow plane, scenery, clouds, frame, watermark or UI. Only one isolated aircraft on a genuinely transparent background. Do not copy commercial game assets or a specific game's design.
```
