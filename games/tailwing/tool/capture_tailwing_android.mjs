// Dedicated fictional integration app only. Never changes the normal .dev app.
import {execFileSync,spawn} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createInterface} from 'node:readline';
const cardsOnly=process.argv[2]==='--cards-only';
const labOnly=process.argv[2]==='--lab-only';
const followUp=process.argv[2]==='--follow-up'||labOnly;
if(process.argv.length!==((cardsOnly||followUp)?3:2))throw new Error('invalid_arguments');
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const local=resolve(root,'server/firebase/.runtime/native-local');mkdirSync(local,{recursive:true});
const env=Object.fromEntries(['PATH','Path','PATHEXT','SystemRoot','SYSTEMROOT','WINDIR','windir','COMSPEC','ComSpec','TEMP','TMP'].filter(k=>process.env[k]!==undefined).map(k=>[k,process.env[k]]));
Object.assign(env,{USERPROFILE:'C:\\Users\\user',HOMEDRIVE:'C:',HOMEPATH:'\\Users\\user',LOCALAPPDATA:local,
  ANDROID_HOME:'C:\\Users\\user\\AppData\\Local\\Android\\Sdk',JAVA_HOME:'C:\\Program Files\\Android\\Android Studio\\jbr',CI:'true'});
const adb='C:/Users/user/AppData/Local/Android/Sdk/platform-tools/adb.exe';
function command(args,encoding){return execFileSync(adb,['-s','emulator-5554',...args],{env,encoding,windowsHide:true,timeout:20000,maxBuffer:12*1024*1024});}
if(command(['shell','getprop','ro.kernel.qemu'],'utf8').trim()!=='1')throw new Error('dedicated_emulator_required');
const out=resolve(root,'docs/tailwing/screenshots');mkdirSync(out,{recursive:true});let code=1;
try{
  command(['shell','wm','size','1080x1920']);
  const script="& 'C:\\Users\\user\\flutter\\bin\\flutter.bat' --suppress-analytics test "+(followUp?'integration_test/tailwing_followup_test.dart':cardsOnly?'integration_test/tailwing_cards_test.dart':'integration_test/tailwing_roster_test.dart')+" -d emulator-5554 --dart-define=AIRZERO_INTEGRATION=true --no-uninstall --reporter expanded"+(labOnly?" --dart-define=TAILWING_LAB_ONLY=true --plain-name 'debug research lab exposes all twelve without subscription grants'":'')+"; exit $LASTEXITCODE";
  const child=spawn('powershell.exe',['-NoProfile','-Command',script],{cwd:root,env,windowsHide:true,stdio:['ignore','pipe','pipe']});
  for(const stream of [child.stdout,child.stderr])createInterface({input:stream}).on('line',line=>{
    if(/https?:\/\/|oobCode|idToken|refreshToken|Bearer |@example\.|apiKey=|pubkey|serialno/i.test(line))return;
    process.stdout.write(line+'\n');
  });
  code=await new Promise(res=>{child.on('error',()=>res(1));child.on('close',n=>res(n??1));});
  if(followUp){
    const folder=resolve(root,'docs/tailwing/followup-screenshots');mkdirSync(folder,{recursive:true});
    const report={date:new Intl.DateTimeFormat('sv-SE',{timeZone:'Asia/Seoul'}).format(new Date()),exitCode:code,mode:labOnly?'lab-only':'follow-up',scope:'SYNTHETIC_DEBUG_EMULATOR_NOT_LIVE_OR_PHYSICAL_DEVICE',captures:[]};
    for(const name of labOnly?['lab-turtle','lab-squirrel','lab-frog']:['lab-turtle','lab-squirrel','lab-frog','boss','result','retry']){
      try{
        const b=command(['exec-out','run-as','com.example.raikeopeu2026.dev.integration','cat',`files/tailwing_followup_v1/${name}.png`]);
        if(b.readUInt32BE(16)!==1080||b.readUInt32BE(20)!==1920)throw new Error('capture_dimensions');
        writeFileSync(resolve(folder,name+'.png'),b);report.captures.push(name);
      }catch{/* Keep successful partial evidence without exposing raw logs. */}
    }
    for(const name of labOnly?['lab']:['lab','flow']){
      try{report[name]=JSON.parse(command(['exec-out','run-as','com.example.raikeopeu2026.dev.integration','cat',`files/tailwing_followup_v1/${name}.json`],'utf8'));}catch{}
    }
    writeFileSync(resolve(root,labOnly?'docs/tailwing/NATIVE-LAB-RECHECK.json':'docs/tailwing/NATIVE-FOLLOWUP.json'),JSON.stringify(report,null,2)+'\n');
    console.log(JSON.stringify({nativeFollowupExit:code,captures:report.captures.length,labChecked:!!report.lab,flowChecked:!!report.flow}));
  }else if(code===0){
    for(const name of cardsOnly?['skill-cards']:['00-home','rabbit','fox','bear','turtle','otter','owl','squirrel','hedgehog','penguin','frog','eagle','volt']){
      const b=command(['exec-out','run-as','com.example.raikeopeu2026.dev.integration','cat',`files/tailwing_roster_capture_v1/${name}.png`]);
      if(b.readUInt32BE(16)!==1080||b.readUInt32BE(20)!==1920)throw new Error('capture_dimensions');
      writeFileSync(resolve(out,name+'.png'),b);
    }
    if(!cardsOnly){
    const m=command(['exec-out','run-as','com.example.raikeopeu2026.dev.integration','cat','files/tailwing_roster_capture_v1/metrics.json']);
    const metrics=JSON.parse(m.toString('utf8'));if(metrics.pilots!==12)throw new Error('metrics');
    writeFileSync(resolve(root,'docs/tailwing/ANDROID-METRICS.json'),JSON.stringify(metrics,null,2)+'\n');
    }
    console.log(cardsOnly?'TAILWING: native skill-card check complete, 1 actual frame; purchase locked.':'TAILWING: native synthetic trial complete, 13 actual frames. Not real billing/login/device verification.');
  }
}finally{command(['shell','wm','size','reset']);}
process.exitCode=code;
