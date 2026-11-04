// Offline gallery/hash inventory only, no deployment or remote resources.
import {readFileSync,writeFileSync,readdirSync,existsSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
if(process.argv.length!==2)throw new Error('no_arguments');
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const roster=JSON.parse(readFileSync(resolve(root,'docs/tailwing/ROSTER-CATALOG.json'),'utf8')).pilots;
if(roster.length!==12||new Set(roster.map(p=>p.id)).size!==12)throw new Error('runtime_roster_required');
for(const p of roster){
  if(!/^[a-z][a-z0-9_]{0,40}$/.test(p.id)||!/^[a-z][a-z0-9_]{0,40}$/.test(p.art)||
    typeof p.freeCharacter!=='boolean'||['name','species','technique'].some(k=>typeof p[k]!=='string'||p[k].length>160))throw new Error('invalid_roster_fields');
}
if(new Set(roster.map(p=>p.art)).size!==12)throw new Error('duplicate_art');
const escapeHtml=s=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const labels=roster.map(p=>[p.art,escapeHtml(`${p.name} · ${p.species}`),escapeHtml(p.technique),p.freeCharacter?'무료':'구독']);
const html=`<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="no-referrer"><meta name="robots" content="noindex,nofollow"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"><title>테일윙 · TAILWING 로컬 미리보기</title><style>body{margin:0;background:#0b192a;color:#edf7ff;font:17px/1.6 system-ui,sans-serif}main{max-width:1240px;margin:auto;padding:24px}a{color:#87e6d5}h1{font-size:36px}.note{background:#193143;padding:18px;border-radius:18px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:18px}article{background:#14293b;border:1px solid #31566b;border-radius:20px;padding:18px}img{max-width:100%;height:auto}.art{display:flex;align-items:center;height:190px}.art img{width:50%;max-height:190px;object-fit:contain}.screen{display:block;margin:16px auto;max-height:640px}.hero{max-height:600px;display:block;margin:auto}.badge{color:#ffe1b1}</style></head><body><main><h1>테일윙 · TAILWING</h1><p class="note">귀엽고 밝은 미래형 SF · 로컬 검토본 / 미공개<br>기본 토끼·여우·거북이와 사격·보호막 무료. 월·연 구독은 전체 캐릭터와 고유 기술. 상품 ID 미정·실서버/스토어 미연결로 실제 구매는 잠겨 있습니다.<br>아래 전투는 Android 가상 앱·가상 구독 권한으로 시험한 실제 Flutter 렌더링입니다. 실기기·실제 결제/로그인 검증이 아닙니다.</p><p><a href="../TAILWING-ROSTER-RESULTS.md">검증 결과·남은 항목</a> · <a href="ROSTER-CONTACT-SHEET.png">전체 아트 검토 시트</a> · <a href="ANDROID-METRICS.json">가상 기기 성능 기록</a></p><h2>실제 홈 화면</h2><img class="hero" src="screenshots/00-home.png" alt="테일윙 실제 가상 Android 홈"><h2>캐릭터·탑승 기체·실제 전투</h2><div class="grid">${labels.map(([id,name,skill,access])=>`<article><h3>${name}</h3><p class="badge">캐릭터 ${access} · 고유 기술은 구독</p><div class="art"><img src="../../assets/tailwing/${id}_portrait.png" alt="${name} 자체 제작 초상"><img src="../../assets/tailwing/${id}_ship.png" alt="${name} 같은 방향으로 탑승한 기체"></div><p>${skill}</p><a href="screenshots/${id}.png"><img class="screen" loading="lazy" src="screenshots/${id}.png" alt="${name} 가상 구독 고유 기술 시험 화면"></a></article>`).join('')}</div><h2>아직 확인하지 못한 것</h2><p>실제 인증/서버/스토어·공개 삭제 웹·iOS/실기기·16KB 기기/발열/입력 지연·장기 밸런스·보안 경고5개와 새 서명 제출 파일/스토어 아이콘·최종 소개 자료는 대기입니다. 기본 배경 한 장과5개 지역 색조를 공유하며15탄 전체의 개별 신규 배경을 만들었다고 표시하지 않습니다. 캐릭터 동작은 단일 제작 그림의 코드 기반 움직임이며 얼굴/관절별 애니메이션은 아닙니다.</p></main></body></html>`;
const followup=[['boss','무료1탄 보스 · 자동 조작'],['result','보스 격파 후 결과 기록'],['retry','결과 화면에서 재도전'],['lab-turtle','연구소 · 거북이 방향성 갑판'],['lab-squirrel','연구소 · 다람쥐 씨앗 비콘'],['lab-frog','연구소 · 개구리 잔상 비콘']];
const finalHtml=html.replace('<h2>캐릭터·탑승 기체·실제 전투</h2>','<h2>실제 기술 카드 · 수치와 잠금 확인</h2><img class="hero" src="screenshots/skill-cards.png" alt="Android 가상 앱의 실제 기술 카드와 구매 잠금"><h2>캐릭터·탑승 기체·실제 전투 · 10월29일 캡처</h2>')
  .replace('<h2>아직 확인하지 못한 것</h2>',`<h2>10월30일 후속 실제 Flutter 화면</h2><p><a href="../TAILWING-FOLLOWUP-RESULTS.md">12종 표·실제/모의/미검증 구분</a> · <a href="../TAILWING-RUN-GUIDE.md">Android 직접 실행·남은 준비 순서</a></p><p>무료1탄은 게임 시간273초 동안 적/체력/점수 주입 없이 자동 steering으로 보스→결과→재도전을 확인했습니다. 연구소12종의 종료는 native 버튼 발동 후 가속 모델 step 검사입니다. 실기기/실로그인/실결제나60fps 통과가 아닙니다. 해적 곰·수달은 기본 디자인이며 별도 스킨 상품이 아닙니다.</p><div class="grid">${followup.map(([name,label])=>`<article><h3>${label}</h3><a href="followup-screenshots/${name}.png"><img class="screen" loading="lazy" src="followup-screenshots/${name}.png" alt="${label} 실제 가상 앱 캡처"></a></article>`).join('')}</div><h2>아직 확인하지 못한 것</h2>`);
writeFileSync(resolve(root,'docs/tailwing/index.html'),finalHtml+'\n');
const files=[];
for(const folder of ['assets/tailwing','docs/tailwing/screenshots','docs/tailwing/followup-screenshots']){
  for(const name of readdirSync(resolve(root,folder)).sort()){
    if(!/^[a-z0-9_-]+\.png$/.test(name))continue;
    const path=`${folder}/${name}`,b=readFileSync(resolve(root,path));
    files.push({path,bytes:b.length,sha256:createHash('sha256').update(b).digest('hex'),width:b.readUInt32BE(16),height:b.readUInt32BE(20)});
  }
}
writeFileSync(resolve(root,'docs/tailwing/REVIEW-INVENTORY.json'),JSON.stringify({date:new Intl.DateTimeFormat('sv-SE',{timeZone:'Asia/Seoul'}).format(new Date()),status:'LOCAL_RENEWAL_NOT_LIVE_OR_SUBMISSION_READY',files},null,2)+'\n');
const missing=[];
for(const m of finalHtml.matchAll(/(?:src|href)="([^"]+)"/g)){if(!existsSync(resolve(root,'docs/tailwing',m[1])))missing.push(m[1]);}
console.log(JSON.stringify({assetsAndCaptures:files.length,localLinksMissing:missing.length,status:'NOT_SUBMISSION_READY'}));
if(missing.length)process.exitCode=1;
