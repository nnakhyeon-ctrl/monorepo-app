import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {inside,digest,verifySnapshot,pngInfo} from './release_candidate.mjs';
if(process.argv.length!==2)throw Error('no_arguments_accepted');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),folder='docs/release-prep-2026-11-04';
const json=n=>JSON.parse(fs.readFileSync(inside(root,folder+'/'+n),'utf8'));
const ready=json('READINESS.json'),saved=json('SOURCE-SNAPSHOT.json'),assets=json('ASSET-INVENTORY.json');
const checks=[];const add=(id,pass)=>checks.push({id,status:pass?'PASS':'FAIL'});
add('current_source_fingerprint',verifySnapshot(root,saved).matches);
add('all_material_hashes',assets.files.every(f=>fs.existsSync(inside(root,folder+'/'+f.path))&&digest(fs.readFileSync(inside(root,folder+'/'+f.path)))===f.sha256));
add('no_false_submission_success',ready.submissionReady===false&&!ready.android.signedAabProduced&&!ready.ios.ipaProduced);
add('historical_screenshots_labelled',json('FRAME-EVIDENCE.json').screenshots.every(s=>!s.currentReleaseCapture&&!s.submissionReady&&s.captured==='2026-10-30'));
add('technique_not_presented_as_free_shield',json('FRAME-EVIDENCE.json').screenshots.find(s=>s.path.includes('shield-active')).entitlement.includes('SUBSCRIPTION'));
add('source_debug_and_network_guards',ready.releaseGuardChecks.every(c=>c.status==='STATIC_PASS'));
for(const [name,w,h,color] of [['play-icon-512.png',512,512,6],['play-feature-1024x500.png',1024,500,2],['ios-icon-1024.png',1024,1024,2]]){
 const b=fs.readFileSync(inside(root,folder+'/graphics/'+name)),p=pngInfo(b);
 add('graphic_format_'+name,p.width===w&&p.height===h&&p.bitDepth===8&&p.colorType===color&&(!name.startsWith('play-icon')||b.length<=1024*1024));
}
let links=0,broken=[];
for(const f of assets.files.filter(f=>/\.html$/.test(f.path))){
 const html=fs.readFileSync(inside(root,folder+'/'+f.path),'utf8');
 add('offline_page_'+f.path,html.includes('noindex,nofollow')&&html.includes("form-action 'none'")&&!/<(?:script|form|input|iframe)\b/i.test(html)&&!/(?:src|action)=["']https?:/i.test(html));
 for(const m of html.matchAll(/(?:href|src)="([^"]+)"/g)){
  if(/^https?:/.test(m[1])||m[1].startsWith('#'))continue;links++;
  const relative=path.posix.normalize(folder+'/'+path.posix.dirname(f.path)+'/'+m[1]);
  if(!fs.existsSync(inside(root,relative)))broken.push(relative);
 }
}
add('local_links_exist',broken.length===0);
const report={date:'2026-11-04',scope:'LOCAL_SOURCE_AND_MATERIAL_CHECKS_NOT_SIGNED_BUILD_OR_STORE_VERIFICATION',checks,links,broken,
 passed:checks.filter(x=>x.status==='PASS').length,failed:checks.filter(x=>x.status==='FAIL').length};
fs.writeFileSync(inside(root,folder+'/CHECKS.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({passed:report.passed,failed:report.failed,broken}));process.exitCode=report.failed?1:0;
