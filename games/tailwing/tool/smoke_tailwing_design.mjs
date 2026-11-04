import {spawnSync} from 'node:child_process';
import {readFileSync,writeFileSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
if(process.argv.length!==2)throw new Error('no_arguments');
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const env=Object.fromEntries(['PATH','Path','PATHEXT','SystemRoot','WINDIR','COMSPEC','TEMP','TMP'].filter(k=>process.env[k]!==undefined).map(k=>[k,process.env[k]]));
Object.assign(env,{USERPROFILE:'C:\\Users\\user',LOCALAPPDATA:resolve(root,'server/firebase/.runtime/native-local')});
const sdk='C:/Users/user/AppData/Local/Android/Sdk';
const adb=args=>spawnSync(`${sdk}/platform-tools/adb.exe`,['-s','emulator-5554',...args],{env,windowsHide:true,timeout:45000,encoding:'utf8',maxBuffer:1024*1024});
if(adb(['shell','getprop','ro.kernel.qemu']).stdout?.trim()!=='1')throw new Error('owned_emulator_required');
const id='com.example.raikeopeu2026.dev.integration';
const build=JSON.parse(readFileSync(resolve(root,'docs/tailwing/BUILDS.json'))).preview;
const apk=resolve(root,build.path),hash=createHash('sha256').update(readFileSync(apk)).digest('hex');
if(build.appId!==id||hash!==build.sha256)throw new Error('isolated_apk_check');
const install=adb(['install','-r',apk]);
const report={date:'2026-10-30',scope:'ISOLATED_DEBUG_MAIN_STARTUP_NOT_SUBMISSION_OR_PHYSICAL',
 sha256:hash,appId:id,install:install.status===0&&/Success/.test(install.stdout??''),
 uninstallOrDataClear:false,normalAppTouched:false};
if(report.install){
 adb(['shell','am','force-stop',id]);
 const launch=adb(['shell','am','start','-W','-n',`${id}/com.example.raikeopeu2026.MainActivity`]);
 report.launch=launch.status===0&&/Status: ok/.test(launch.stdout??'');
 report.totalTimeMs=Number(/TotalTime:\s*(\d+)/.exec(launch.stdout??'')?.[1]??0);
 await new Promise(done=>setTimeout(done,5000));
 report.aliveAfter5Seconds=adb(['shell','pidof',id]).status===0;
 adb(['shell','am','force-stop',id]);
}
writeFileSync(resolve(root,'docs/tailwing/design-pass-01/INTERACTIVE-SMOKE.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));if(!report.install||!report.launch||!report.aliveAfter5Seconds)process.exitCode=1;
