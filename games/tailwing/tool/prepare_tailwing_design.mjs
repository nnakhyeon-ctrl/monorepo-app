// Only downscale authored PNGs; originals and previous runtime files retained.
import {readFileSync,writeFileSync,copyFileSync,mkdirSync} from 'node:fs';
import {resolve,dirname,basename} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
if(process.argv.length!==2)throw new Error('no_arguments');
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const folder=resolve(root,'docs/tailwing/design-pass-01');
const original=JSON.parse(readFileSync(resolve(folder,'ART-JOBS.json')));
const mounted=JSON.parse(readFileSync(resolve(folder,'MOUNTED-ART-JOBS.json')));
const jobs=[...original.jobs,...mounted.jobs];
const sourceFolder=resolve(folder,'sources');mkdirSync(sourceFolder,{recursive:true});
const plan=jobs.map(j=>{
 if(!['rabbit','turtle'].includes(j.species)||!['portrait','ship','hero'].includes(j.kind)||!/^C:\\Users\\user\\\.codex\\generated_images\\[\da-f-]+\\exec-[\da-f-]+\.png$/.test(j.source))throw new Error('invalid_job');
 const source=resolve(sourceFolder,`${j.species}-${j.kind}-${basename(j.source)}`);copyFileSync(j.source,source);
 const b=readFileSync(source);if(b.readUInt32BE(16)<1024||b[25]!==6)throw new Error('expected_high_resolution_rgba');
 return {source,target:resolve(root,`assets/tailwing/${j.species}_${j.kind}_v2.png`),width:1024,height:Math.round(b.readUInt32BE(20)*1024/b.readUInt32BE(16)),alpha:true};
});
const runtime=resolve(root,'server/firebase/.runtime');mkdirSync(runtime,{recursive:true});
const exe=resolve(runtime,'tailwing-design-image-helper.exe');
execFileSync('C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe',['/nologo','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll',`/out:${exe}`,resolve(root,'tool/ReleaseImageHelper.cs')],{windowsHide:true,stdio:'pipe'});
const path=resolve(runtime,'tailwing-design-image-plan.json');writeFileSync(path,JSON.stringify({root,jobs:plan}));
execFileSync(exe,[path],{windowsHide:true,stdio:'pipe'});
const files=plan.map(j=>{const b=readFileSync(j.target),source=readFileSync(j.source);return {path:j.target.slice(root.length+1).replaceAll('\\','/'),source:j.source.slice(root.length+1).replaceAll('\\','/'),sourceWidth:source.readUInt32BE(16),sourceHeight:source.readUInt32BE(20),width:b.readUInt32BE(16),height:b.readUInt32BE(20),colorType:b[25],bytes:b.length,sha256:createHash('sha256').update(b).digest('hex')};});
writeFileSync(resolve(folder,'ASSET-INVENTORY.json'),JSON.stringify({date:'2026-10-30',method:'Built-in imagegen originals; 1024px downscale with alpha; no tracing or upscaling',files},null,2)+'\n');
console.log(JSON.stringify({newVersionedAssets:files.length,bytes:files.reduce((s,f)=>s+f.bytes,0),previousFilesPreserved:true}));
