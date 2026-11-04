// Anonymous registry audit of copied lockfiles only. No installs or auth config.
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {inside} from './release_candidate.mjs';
if(process.argv.length!==2)throw Error('no_arguments_accepted');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const runtime=inside(root,'server/firebase/.runtime/stage12-audit');fs.mkdirSync(runtime,{recursive:true});
for(const name of ['package.json','package-lock.json'])fs.copyFileSync(inside(root,'server/firebase/'+name),path.join(runtime,name));
for(const name of ['user.npmrc','global.npmrc'])fs.writeFileSync(path.join(runtime,name),'');
const env=Object.fromEntries(['PATH','Path','PATHEXT','SystemRoot','WINDIR','COMSPEC','TEMP','TMP'].filter(k=>process.env[k]!==undefined).map(k=>[k,process.env[k]]));
Object.assign(env,{USERPROFILE:runtime,HOME:runtime,NPM_CONFIG_CACHE:path.join(runtime,'cache'),CI:'true'});
const reports=[];
for(const productionOnly of [false,true]){
 const result=spawnSync('cmd.exe',['/d','/s','/c',`npm.cmd audit --json --ignore-scripts --registry=https://registry.npmjs.org --userconfig user.npmrc --globalconfig global.npmrc${productionOnly?' --omit=dev':''}`],{cwd:runtime,env,encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:4*1024*1024});
 let data;try{data=JSON.parse(result.stdout);}catch{}
 const valid=!!data?.metadata?.vulnerabilities;
 reports.push({scope:productionOnly?'SERVER_PRODUCTION_DEPENDENCIES':'SERVER_WITH_DEVELOPMENT_TOOLS',
  status:valid?'AUDIT_RETURNED':'NOT_VERIFIED',exitCode:result.status,
  ...(valid?{counts:data.metadata.vulnerabilities,advisories:[...new Map(Object.values(data.vulnerabilities||{}).flatMap(v=>v.via.filter(x=>typeof x==='object').map(x=>[x.url,{package:x.name,severity:x.severity,url:x.url}]))).values()]}:{reason:'REGISTRY_OR_LOCAL_TOOL_UNAVAILABLE'}),
  packagesChanged:false,credentialsRead:false});
}
const report={date:'2026-11-04',registry:'https://registry.npmjs.org',scope:'NODE_LOCKFILE_AUDIT_NOT_MOBILE_OR_RUNTIME_SECURITY_PROOF',reports};
fs.writeFileSync(inside(root,'docs/release-prep-2026-11-04/DEPENDENCY-AUDIT.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(reports.map(r=>({scope:r.scope,status:r.status,counts:r.counts}))));
if(reports.some(r=>r.status==='NOT_VERIFIED'))process.exitCode=2;
