# 12단계 이미지 제작 기록

2026-10-29. `imagegen` 스킬의 **내장 image_gen**을 사용했다. 별도 CLI/API key·모델 결제 가입 없이 기존 자체 제작 `assets/images/aurora_aviation_hd.png`를 supporting reference로 사용했다. 아래는 실제 전송 프롬프트다. 생성 원본과 규격 변환본은 같은 폴더의 이름으로 보존한다. 배너/아이콘은 브랜드 그림이며 실제 플레이 캡처로 표시하지 않는다. 재개 후 [출처/사용 조건·규격 검토](ASSET-REVIEW.md)를 정리했으며 실제 native 마스크/Xcode·최종 권리 검토는 대기다.

## 아이콘 — icon-source-v1.png

생성 원본명: `exec-ccd36a9d-6709-4683-87bf-5d85b4eca008.png`.

```text
Use-case: logo-brand. Create ONE polished square mobile game app icon for AIRZERO STRIKE. Supporting reference image is the game's own Aurora aircraft. Preserve its identity exactly: silver twin-boom propeller aircraft, central dark cockpit, two visible propellers, connecting tailplane, restrained cyan stripes. Do not turn it into a jet or spaceship. The entire silhouette must remain clear and recognizable at small icon sizes, centered in a square with generous safe margins. Background: opaque deep navy #081621 with a restrained teal atmospheric halo, clean high quality metallic lighting consistent with the supplied asset. No words, no letters, no badges, no frame, no pre-rounded corners, no transparent background, no star ratings, no weapons that are not on the aircraft. High resolution smooth edges, no pixel art. Intended master icon 1024x1024; one image, not an asset sheet. Keep plane inside the central 76 percent of square so launcher masks do not crop its wings/tail.
```

실제 생성 크기는1254×1254다. native/스토어 파일은 크기/PNG 형식만 변환했다. 사각 원본에서 기체가 넓게 차지하므로 Android 다양한 마스크의 실제 확인은 별도로 남긴다.

## 배너 — feature-source-v1.png

생성 원본명: `exec-6025aeab-f9c7-4809-a483-420dc0217faf.png`.

```text
Use-case: ads-marketing. Create ONE landscape Google Play feature graphic for the same AIRZERO STRIKE mobile flight shooter, exact 1024:500 composition ratio. Supporting reference is the actual own Aurora aircraft asset; preserve the silver twin-boom propeller shape, cockpit, twin propellers and cyan stripes. Match navy #081621 and teal #60dbcb digital game branding. Put the aircraft on the right half, clean readable title on the left, exact text 'AIRZERO' on first line and 'STRIKE' on second line in a bold restrained modern white sans serif. Subtle coastal atmosphere only, no HUD, no invented enemies, no spacecraft, no new game features, no rating/price/discount/CTA, no store badges, no logos of third parties, no extra text or watermark. This is a brand banner, not a fabricated gameplay screenshot. Keep all elements away from edges. Opaque full-bleed rectangular image, no rounded corners.
```

내장 생성 후 원본을 프로젝트로 복사했다. `tool/prepare_release_images.mjs`·`ReleaseImageHelper.cs`는 deterministic 크기/PNG 변환 도구이며 imagegen CLI가 아니다. 실제 게임 캡처4장에는 생성형 그림·문구/UI 합성·크롭을 적용하지 않았다.
