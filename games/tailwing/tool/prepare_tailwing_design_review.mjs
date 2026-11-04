import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
if(process.argv.length!==2)throw new Error('no_arguments');
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const folder='docs/tailwing/design-pass-01';
const archivePath=resolve(root,'docs/tailwing/index.html');
let archive=readFileSync(archivePath,'utf8');
if(!archive.includes('id="latest-design-pass"')){
 archive=archive.replace('<main>','<main><p class="note" id="latest-design-pass">'+
 '<a href="design-pass-01/index.html">2026-10-30 최신 홈·토끼/거북이·전투/음악 전후 비교</a><br>아래 이미지는 이전 리뉴얼의 보존 이력입니다. 현재 앱은 새 v2 자산과 선택 화면을 사용합니다.</p>');
 writeFileSync(archivePath,archive);
}
const scenes=[['home-rabbit','토끼 홈'],['home-turtle','거북이 홈'],['hangar-top','선택한 파일럿'],['hangar-cards','캐릭터 카드'],['shield-active','갑판 전개'],['shield-ended','갑판 종료']];
const files=JSON.parse(readFileSync(resolve(root,folder,'ASSET-INVENTORY.json'))).files.map(f=>f.path);
files.push('assets/audio/tailwing_flight_v2.wav');
for(const [name] of scenes)for(const phase of ['before','after'])files.push(`${folder}/${phase}/${name}.png`);
files.push(`${folder}/after/rabbit-combat.png`);
const inventory=files.map(path=>{
 if(!existsSync(resolve(root,path)))throw new Error('review_input_missing:'+path);
 const b=readFileSync(resolve(root,path));return {path,bytes:b.length,sha256:createHash('sha256').update(b).digest('hex')};
});
const page=`<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="no-referrer"><meta name="robots" content="noindex,nofollow"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self'; media-src 'self'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"><title>TAILWING · 실제 앱 전후 비교</title>
<style>body{background:#09131e;color:#edf6fa;font:16px/1.6 system-ui,sans-serif;max-width:1100px;margin:0 auto;padding:24px}a{color:#85dec9}h1{font-size:32px}h2{margin-top:50px}p{color:#c2d2dc}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}.pair img{width:100%;border-radius:18px}.pair figure{margin:0;background:#132330;padding:12px;border-radius:20px}figcaption{padding:8px}.assets{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}.assets img{width:100%;background:#203440;border-radius:16px}.solo{display:block;width:min(100%,440px);border-radius:18px}audio{max-width:100%}@media(max-width:500px){body{padding:12px}.pair{gap:8px}.pair figure{padding:5px}.assets{grid-template-columns:repeat(2,1fr)}}</style>
<h1>TAILWING · 홈/캐릭터/전투 개선</h1><p>2026-10-30 · 실제 Flutter Android 가상 기기에서 촬영한 화면입니다. 합성 홍보 이미지가 아니며, 실제 사용자·실결제·물리 기기 성능 검증 자료도 아닙니다.</p>
<p><a href="../../TAILWING-DESIGN-PASS-RESULTS.md">변경·검증·미확인 항목</a> · <a href="../../TAILWING-RUN-GUIDE.md">Android 직접 실행</a> · <a href="TEST-RESULTS.json">로컬 95개 검사</a> · <a href="after/NATIVE-CHECKS.json">Android 가상 검사</a></p>
<h2>새 전투 음악</h2><p>112BPM · 약34.3초 · 자체 생성 PCM. 자동 재생하지 않습니다. 앱의 기존 배경음 켜기/끄기·음량·일시정지 설정을 사용합니다. 실기기 스피커 청취·장시간 피로도는 미확인입니다.</p><audio controls preload="none" src="../../../assets/audio/tailwing_flight_v2.wav"></audio>
${scenes.map(([name,label])=>`<h2>${label}</h2><div class="pair"><figure><figcaption>변경 전</figcaption><a href="before/${name}.png"><img loading="lazy" src="before/${name}.png" alt="변경 전 ${label}"></a></figure><figure><figcaption>변경 후</figcaption><a href="after/${name}.png"><img loading="lazy" src="after/${name}.png" alt="변경 후 ${label}"></a></figure></div>`).join('')}
<h2>토끼 실제 출격 · 구름 스티치</h2><p>합성 이용권을 사용하는 격리된 native 검사 화면입니다. 일반 앱은 고유 기술을 무료로 해금하지 않습니다.</p><a href="after/rabbit-combat.png"><img class="solo" loading="lazy" src="after/rabbit-combat.png" alt="새 토끼 기체의 실제 출격과 고유 기술"></a>
<h2>새 원본 기반 자산6장</h2><p>초상·탑뷰 전투 기체·홈 탑승 이미지. 모두 자체 이미지의 AI 편집/생성 결과이며1024px RGBA로 축소 보존했습니다. 기존 자산을 덮어쓰지 않았습니다.</p><div class="assets">${['rabbit','turtle'].flatMap(p=>['portrait','ship','hero'].map(k=>`<a href="../../../assets/tailwing/${p}_${k}_v2.png"><img loading="lazy" src="../../../assets/tailwing/${p}_${k}_v2.png" alt="${p} ${k}"></a>`)).join('')}</div><p><a href="ART-JOBS.json">초상 제작 기록</a> · <a href="MOUNTED-ART-JOBS.json">탑승 제작 프롬프트</a> · <a href="ASSET-INVENTORY.json">자산 규격</a> · <a href="REVIEW-INVENTORY.json">검토 파일 SHA-256</a></p></html>`;
writeFileSync(resolve(root,folder,'index.html'),page);
writeFileSync(resolve(root,folder,'REVIEW-INVENTORY.json'),JSON.stringify({date:'2026-10-30',scope:'LOCAL_DESIGN_REVIEW_NOT_STORE_SUBMISSION',files:inventory},null,2)+'\n');
console.log(JSON.stringify({reviewFiles:inventory.length,before:6,after:7,networkRequests:false}));
