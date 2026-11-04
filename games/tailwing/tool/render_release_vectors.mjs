// Rasterize authored editable SVGs in an isolated headless profile; no user browser data.
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {inside,pngInfo,validateVectorText} from './release_candidate.mjs';
if(process.argv.length!==2)throw Error('no_arguments_accepted');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const graphics=inside(root,'docs/release-prep-2026-11-04/graphics');
const runtime=inside(root,'server/firebase/.runtime/stage12-vectors');fs.mkdirSync(runtime,{recursive:true});
const edge='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
if(!fs.existsSync(edge))throw Error('local_edge_unavailable');
const icon=validateVectorText(fs.readFileSync(path.join(graphics,'icon-master.svg'),'utf8'));
validateVectorText(fs.readFileSync(path.join(graphics,'feature-master.svg'),'utf8'));
fs.writeFileSync(path.join(graphics,'ios-icon-master.svg'),icon.replace('width="512" height="512"','width="1024" height="1024"'));
const jobs=[['icon-master.svg','play-icon-512.png',512,512,true],['feature-master.svg','play-feature-1024x500.png',1024,500,false],['ios-icon-master.svg','ios-icon-1024.png',1024,1024,false]];
const plan=[];
for(const [source,target,width,height,alpha] of jobs){
 const raw=path.join(runtime,target);
 execFileSync(edge,['--headless=new','--disable-extensions','--disable-background-networking','--no-first-run','--no-default-browser-check',
  '--force-device-scale-factor=1','--hide-scrollbars',`--user-data-dir=${path.join(runtime,'profile-'+width+'-'+height)}`,
  `--window-size=${width},${height}`,`--screenshot=${raw}`,pathToFileURL(path.join(graphics,source)).href],
  {windowsHide:true,timeout:45000,stdio:'pipe',maxBuffer:1024*1024});
 const info=pngInfo(fs.readFileSync(raw));if(info.width!==width||info.height!==height)throw Error('render_size_mismatch');
 plan.push({source:raw,target:path.join(graphics,target),width,height,alpha});
}
const exe=path.join(runtime,'image-format.exe');
execFileSync('C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe',['/nologo','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll',`/out:${exe}`,inside(root,'tool/ReleaseImageHelper.cs')],{windowsHide:true,stdio:'pipe'});
const config=path.join(runtime,'format-plan.json');fs.writeFileSync(config,JSON.stringify({root,jobs:plan}));
execFileSync(exe,[config],{windowsHide:true,stdio:'pipe'});
const review=inside(root,'docs/release-prep-2026-11-04/index.html');
if(fs.existsSync(review))execFileSync(edge,['--headless=new','--disable-extensions','--disable-background-networking','--no-first-run','--no-default-browser-check',
 '--force-device-scale-factor=1','--hide-scrollbars',`--user-data-dir=${path.join(runtime,'review-profile')}`,
 '--window-size=1280,1800',`--screenshot=${path.join(runtime,'local-review.png')}`,pathToFileURL(review).href],
 {windowsHide:true,timeout:45000,stdio:'pipe',maxBuffer:1024*1024});
console.log(JSON.stringify({rendered:jobs.length,source:'ORIGINAL_EDITABLE_SVG_NOT_GAMEPLAY',nativeIconsChanged:false,submissionReady:false,localPagePreview:fs.existsSync(review)}));
