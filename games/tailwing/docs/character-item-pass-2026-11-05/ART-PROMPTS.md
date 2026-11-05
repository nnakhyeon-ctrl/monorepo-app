# 세라 원화 생성 기록

방식: 내장 `image_gen` 편집 도구, 자산마다1회(총3회). 프로젝트 기존 `fox_portrait.png`, `fox_ship.png`를 편집 대상으로, 자체 `rabbit_portrait_v2.png`를 재질/조명 참고로 사용했다. 상용 게임 첨부는 도구에 전달하지 않았다. 투명 배경을 요청하고 생성된 알파를 유지했다. 원본 보존, 새 파일을 앱 자산 폴더로 복사해 연결했다. 외부 API 키·CLI는 사용하지 않았다.

최종 경로: `assets/tailwing/fox_portrait_v2.png`, `assets/tailwing/fox_ship_v2.png`, `assets/tailwing/fox_hero_v2.png`.

## 공통 프롬프트

각 자산 프롬프트는 아래 개별 문구 다음에 이 공통 문구를 그대로 결합했다.

```text
Original TAILWING mobile flight game asset. Edit targets are the project's own orange fox Sera and her own pearl/lavender aircraft in the first two reference files; third file is only the project's own rabbit material/lighting quality reference. Keep Sera an unmistakable fox with orange fur, cream muzzle, pointed ears, dark paws and one bushy cream-tipped tail; preserve her friendly clever identity, improve large readable eyes, cheek silhouette and confident gentle smile. New original cream and lavender practical pilot flightsuit, lilac seam panels and a tiny circular navigation receiver on one ear. Do not use any existing commercial franchise, recognizable character, branded symbols, military insignia, or a copied screenshot composition. Soft premium stylized 3D toy-like game illustration, clean readable silhouettes, soft materials, restrained teal engine lights, coherent with the reference rabbit. No words, letters, watermark, border or backdrop; genuine transparent alpha, isolated centered full subject with safe margins, crisp high-resolution 1024px square.
```

## 초상

```text
Use case identity-preserve. Produce one full-body STANDING FOX PILOT PORTRAIT ONLY, no aircraft: compact upright stance, one paw resting on hip and one holding a small rounded navigation puck. Avoid the old sitting pose and the old triangular handheld object. Head and ears fully visible.
```

## 전투 기체

```text
Use case precise-object-edit. Produce one TOP-DOWN GAMEPLAY SPRITE of Sera's aircraft ONLY with a tiny orange fox pilot visible in the cockpit. Plane points straight UP/north, engines at bottom. Keep the project's pearl/lavender small plane identity; improve it with a clean tapered central cockpit, two short swept lavender wings, two rounded engine nacelles and a small warm amber navigation core. Compact recognizable symmetric silhouette, no detached pieces, no ground shadow. Fox ears visible but not hiding the nose. Not a rear or front perspective shot.
```

## 홈 탑승

```text
Use case compositing. Produce one HOME SCREEN MOUNTED HERO: Sera the fox pilot SITTING IN HER pearl and lavender little aircraft, front three-quarter view. Her whole friendly fox FACE and both ears clearly visible above cockpit, aircraft nose and two wings unobstructed. New rounded cockpit ring and twin short swept lavender wings, paired compact engine pods, a small warm amber core, consistent with her top-down aircraft description. One complete pilot-and-plane object, centered, no extra character or separated components.
```

결과는1280px RGBA로 생성됐다. 전투 스프라이트는 위가 진행 방향인 스타일화 기체이며 파일럿 얼굴이 읽히는 표현을 채택했다. 도구 출력/고유 코드 작성만으로 법적 무침해나 독점 권리를 보증하지 않는다. 최종 출시 전 명칭/자산 권리는 별도 확인한다.
