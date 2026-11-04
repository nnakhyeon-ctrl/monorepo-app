// Scoped synthetic integration app only, never normal app or physical devices.
import {execFileSync,spawn} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createInterface} from 'node:readline';
const mode=process.argv[2];
if(process.argv.length!==3||!['before','after'].includes(mode))throw new Error('mode_required');
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const local=resolve(root,'server/firebase/.runtime/native-local');mkdirSync(local,{recursive:true});
const env=Object.fromEntries(['PATH','Path','PATHEXT','SystemRoot','WINDIR','COMSPEC','TEMP','TMP'].filter(k=>process.env[k]!==undefined).map(k=>[k,process.env[k]]));
Object.assign(env,{USERPROFILE:'C:\\Users\\user',HOMEDRIVE:'C:',HOMEPATH:'\\Users\\user',LOCALAPPDATA:local,ANDROID_HOME:'C:\\Users\\user\\AppData\\Local\\Android\\Sdk',JAVA_HOME:'C:\\Program Files\\Android\\Android Studio\\jbr',CI:'true'});
const adb=args=>execFileSync('C:/Users/user/AppData/Local/Android/Sdk/platform-tools/adb.exe',['-s','emulator-5554',...args],{env,windowsHide:true,timeout:30000,maxBuffer:16*1024*1024});
if(adb(['shell','getprop','ro.kernel.qemu']).toString().trim()!=='1')throw new Error('owned_emulator_required');
const directory=resolve(root,`docs/tailwing/design-pass-01/${mode}`);mkdirSync(directory,{recursive:true});
adb(['shell','wm','size','1080x1920']);let code=1;
try {
 const script="& 'C:\\Users\\user\\flutter\\bin\\flutter.bat' --suppress-analytics test integration_test/tailwing_design_test.dart -d emulator-5554 --dart-define=AIRZERO_INTEGRATION=true --no-uninstall --reporter expanded "+(mode==='before'?'--dart-define=TAILWING_DESIGN_BEFORE=true':'')+"; exit $LASTEXITCODE";
 const p=spawn('powershell.exe',['-NoProfile','-Command',script],{cwd:root,env,windowsHide:true,stdio:['ignore','pipe','pipe']});
 for(const stream of [p.stdout,p.stderr])createInterface({input:stream}).on('line',line=>{if(!/https?:\/\/|oobCode|idToken|refreshToken|Bearer |@example\.|apiKey=|pubkey|serialno/i.test(line))process.stdout.write(line+'\n');});
 code=await new Promise(done=>{p.on('error',()=>done(1));p.on('close',n=>done(n??1));});
 const report={date:'2026-10-30',mode,exitCode:code,scope:'SYNTHETIC_NATIVE_ANDROID_EMULATOR_NOT_LIVE_OR_PHYSICAL',captures:[]};
 if(code===0){
  for(const name of ['home-rabbit','home-turtle','hangar-top','hangar-cards','shield-active','shield-ended',...(mode==='after'?['rabbit-combat']:[])]){
   const b=adb(['exec-out','run-as','com.example.raikeopeu2026.dev.integration','cat',`files/tailwing_design_${mode}/${name}.png`]);
   writeFileSync(resolve(directory,name+'.png'),b);report.captures.push({name,width:b.readUInt32BE(16),height:b.readUInt32BE(20)});
  }
  report.checks=JSON.parse(adb(['exec-out','run-as','com.example.raikeopeu2026.dev.integration','cat',`files/tailwing_design_${mode}/checks.json`]).toString('utf8'));
 }
 writeFileSync(resolve(directory,'NATIVE-CHECKS.json'),JSON.stringify(report,null,2)+'\n');
}finally{adb(['shell','wm','size','reset']);}
process.exitCode=code;
