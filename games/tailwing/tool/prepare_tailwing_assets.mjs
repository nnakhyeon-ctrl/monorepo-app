// Deterministic format/size conversion of AI-generated originals. No tracing.
import {readFileSync,writeFileSync,mkdirSync,copyFileSync} from 'node:fs';
import {resolve,dirname,basename} from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
if(process.argv.length!==2) throw new Error('no_arguments');
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const manifest=JSON.parse(readFileSync(resolve(root,'docs/TAILWING-ART-JOBS.json')));
mkdirSync(resolve(root,'assets/tailwing'),{recursive:true});
mkdirSync(resolve(root,'docs/tailwing/art-source'),{recursive:true});
const jobs=[];
for(const j of manifest.jobs){
  if(!/^[a-z]+$/.test(j.species)||!['portrait','ship','hero','background','enemies'].includes(j.kind)||
      !/^C:\\Users\\user\\\.codex\\generated_images\\[\da-f-]+\\exec-[\da-f-]+\.png$/.test(j.source)) throw new Error('invalid_art_job');
  const original=resolve(root,'docs/tailwing/art-source',basename(j.source));
  copyFileSync(j.source,original);
  const b=readFileSync(original),w=b.readUInt32BE(16),h=b.readUInt32BE(20);
  const width=j.kind==='background'?720:512,height=Math.round(h*width/w);
  jobs.push({source:original,target:resolve(root,`assets/tailwing/${j.species}_${j.kind}.png`),width,height,alpha:j.kind!=='background'});
}
const local=resolve(root,'server/firebase/.runtime');mkdirSync(local,{recursive:true});
const exe=resolve(local,'tailwing-image-helper.exe');
execFileSync('C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe',['/nologo','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll',`/out:${exe}`,resolve(root,'tool/ReleaseImageHelper.cs')],{windowsHide:true,stdio:'pipe'});
const plan=resolve(local,'tailwing-image-plan.json');writeFileSync(plan,JSON.stringify({root,jobs}));
execFileSync(exe,[plan],{windowsHide:true,stdio:'pipe'});
writeFileSync(resolve(root,'docs/TAILWING-ASSET-INVENTORY.json'),JSON.stringify({date:'2026-10-29',method:'Built-in imagegen + .NET format conversion; original pixels retained in docs',files:jobs.map(j=>{
  const b=readFileSync(j.target);return {path:j.target.slice(root.length+1).replaceAll('\\','/'),width:b.readUInt32BE(16),height:b.readUInt32BE(20),colorType:b[25],bytes:b.length,sha256:createHash('sha256').update(b).digest('hex')};
})},null,2)+'\n');
console.log(JSON.stringify({assets:jobs.length,status:'converted_originals_preserved'}));
