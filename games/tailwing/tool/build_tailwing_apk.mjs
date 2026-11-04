// Local builds only; explicit fixed mode, no signing setup/install/store/deploy.
import {spawn,execFileSync} from 'node:child_process';
import {createInterface} from 'node:readline';
import {readFileSync,writeFileSync,copyFileSync,mkdirSync,readdirSync,lstatSync,existsSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {localTools} from './local_tools.mjs';
const mode=process.argv[2];if(process.argv.length!==3||!['preview','release-inspection'].includes(mode))throw new Error('explicit_fixed_mode_required');
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const tools=localTools({android:true}),env=tools.env;
const preview=mode==='preview';
const cmd=tools.command(['build','apk',...(preview?['--debug','--dart-define=AIRZERO_INTEGRATION=true']:['--release']),'--target','lib/main.dart']);
const child=spawn('powershell.exe',['-NoProfile','-Command',cmd],{cwd:root,env,windowsHide:true,stdio:['ignore','pipe','pipe']});
for(const stream of [child.stdout,child.stderr])createInterface({input:stream}).on('line',line=>{
  if(/dart-defines|oobCode|idToken|refreshToken|Bearer |apiKey=|pubkey|serialno/i.test(line))return;
  process.stdout.write(line+'\n');
});
const code=await new Promise(res=>{child.on('error',()=>res(1));child.on('close',n=>res(n??1));});
if(code!==0){process.exitCode=code;process.exit(code);}
const source=resolve(root,`build/app/outputs/flutter-apk/app-${preview?'debug':'release'}.apk`);
const sdk=tools.buildTools;
const badge=execFileSync(`${sdk}/aapt2.exe`,['dump','badging',source],{encoding:'utf8',windowsHide:true});
const appId=/package: name='([^']+)'/.exec(badge)?.[1];
if(appId!==`com.example.raikeopeu2026.dev${preview?'.integration':''}`)throw new Error('app_id_mismatch');
const out='build/tailwing-preview/'+(preview?'tailwing-preview-debug.apk':'tailwing-inspection-unsigned.apk');
mkdirSync(resolve(root,'build/tailwing-preview'),{recursive:true});copyFileSync(source,resolve(root,out));
const hash=b=>createHash('sha256').update(b).digest('hex');const files=[];
function collect(p){for(const name of readdirSync(resolve(root,p)).sort()){
 const path=p+'/'+name,s=lstatSync(resolve(root,path));if(s.isSymbolicLink())throw new Error('source_symlink');
 if(s.isDirectory())collect(path);else if(s.isFile())files.push({path,sha256:hash(readFileSync(resolve(root,path)))});
}}
collect('lib');collect('assets');
for(const path of ['pubspec.yaml','pubspec.lock','android/app/build.gradle.kts','android/app/src/main/AndroidManifest.xml','ios/Runner/Info.plist'])files.push({path,sha256:hash(readFileSync(resolve(root,path)))});
files.sort((a,b)=>a.path.localeCompare(b.path,'en'));
const reportPath=resolve(root,'docs/tailwing/BUILDS.json'),reports=existsSync(reportPath)?JSON.parse(readFileSync(reportPath,'utf8')):{};
const historyPath=resolve(root,'docs/tailwing/BUILD-HISTORY.json');
if(reports[mode]){
 const history=existsSync(historyPath)?JSON.parse(readFileSync(historyPath,'utf8')):[];
 if(!history.some(r=>r.mode===mode&&r.sha256===reports[mode].sha256))history.push({mode,...reports[mode],superseded:true});
 writeFileSync(historyPath,JSON.stringify(history,null,2)+'\n');
}
const b=readFileSync(source);
reports[mode]={date:new Intl.DateTimeFormat('sv-SE',{timeZone:'Asia/Seoul'}).format(new Date()),path:out,bytes:b.length,sha256:hash(b),appId,version:'0.1.0+1',
status:preview?'DEBUG_ONLY_ISOLATED_INTERACTIVE_PREVIEW_NOT_SUBMISSION_FILE':'UNSIGNED_INSPECTION_ONLY_NOT_INSTALLABLE_OR_SUBMITTABLE',
sourceFingerprint:hash(Buffer.from(files.map(f=>`${f.path}\0${f.sha256}\n`).join(''))),sourceFiles:files.length,
sourceScope:'lib/assets/pubspec/Android app manifest+Gradle/iOS Info only, not a committed provenance assertion',
purchaseConfigurationInjected:false,serverOrStoreDeployment:false};
writeFileSync(reportPath,JSON.stringify(reports,null,2)+'\n');console.log(JSON.stringify({mode,path:out,appId,status:reports[mode].status}));
