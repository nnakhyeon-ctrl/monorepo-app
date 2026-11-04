// Fixed isolated debug APK and owned emulator only. No uninstall/data clear,
// normal app/physical device access, authentication or server/store operations.
import {spawnSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import os from 'node:os';

if(process.argv.length!==2)throw new Error('no_arguments');
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const env=Object.fromEntries(['PATH','Path','PATHEXT','SystemRoot','WINDIR','COMSPEC','TEMP','TMP']
  .filter(k=>process.env[k]!==undefined).map(k=>[k,process.env[k]]));
Object.assign(env,{USERPROFILE:'C:\\Users\\user',LOCALAPPDATA:resolve(root,'server/firebase/.runtime/native-local')});
const sdk='C:/Users/user/AppData/Local/Android/Sdk';
const id='com.example.raikeopeu2026.dev.integration';
const apk=resolve(root,'build/tailwing-preview/tailwing-preview-debug.apk');
const adb=args=>spawnSync(`${sdk}/platform-tools/adb.exe`,['-s','emulator-5554',...args],
  {env,encoding:'utf8',windowsHide:true,timeout:45000,maxBuffer:1024*1024});
if(adb(['shell','getprop','ro.kernel.qemu']).stdout?.trim()!=='1' ||
  adb(['shell','getprop','sys.boot_completed']).stdout?.trim()!=='1')throw new Error('booted_owned_emulator_required');
const badge=spawnSync(`${sdk}/build-tools/36.0.0/aapt2.exe`,['dump','badging',apk],
  {env,encoding:'utf8',windowsHide:true,maxBuffer:1024*1024});
if(!badge.stdout?.includes(`package: name='${id}'`))throw new Error('isolated_app_id_required');
const builds=JSON.parse(readFileSync(resolve(root,'docs/tailwing/BUILDS.json'),'utf8'));
const sha=createHash('sha256').update(readFileSync(apk)).digest('hex');
if(sha!==builds.preview.sha256)throw new Error('apk_hash_mismatch');
const report={date:new Intl.DateTimeFormat('sv-SE',{timeZone:'Asia/Seoul'}).format(new Date()),
  scope:'OWNED_DEBUG_EMULATOR_STARTUP_ONLY_NOT_REAL_DEVICE_OR_PERFORMANCE_PASS',
  apk:'build/tailwing-preview/tailwing-preview-debug.apk',sha256:sha,appId:id,
  totalHostMemoryBytes:os.totalmem(),freeHostMemoryBeforeInstall:os.freemem(),
  install:null,runs:[],normalAppTouched:false,uninstallOrDataClear:false,
  notChecked:['physical_devices','release_profile_performance','original_historical_exit_cause','all_runtime_failures']};
const save=()=>writeFileSync(resolve(root,'docs/tailwing/STARTUP-CHECK.json'),JSON.stringify(report,null,2)+'\n');
const install=adb(['install','-r',apk]);
report.install={success:install.status===0&&/Success/.test(install.stdout??''),
  signatureMismatch:/UPDATE_INCOMPATIBLE/.test((install.stderr??'')+(install.stdout??''))};
save();
if(!report.install.success){console.log(JSON.stringify({install:report.install,noUninstallFallback:true}));process.exitCode=1;}
else{
  const alive=()=>adb(['shell','pidof',id]).status===0;
  const delay=ms=>new Promise(done=>setTimeout(done,ms));
  for(let i=0;i<3;i++){
    adb(['shell','am','force-stop',id]);
    const launch=adb(['shell','am','start','-W','-n',`${id}/com.example.raikeopeu2026.MainActivity`]);
    const text=launch.stdout??'';
    const row={attempt:i+1,controlledColdStart:true,launchExit:launch.status,
      launchStatus:/Status:\s*(\w+)/.exec(text)?.[1]??'not_reported',
      totalTimeMs:Number(/TotalTime:\s*(\d+)/.exec(text)?.[1]??NaN),
      waitTimeMs:Number(/WaitTime:\s*(\d+)/.exec(text)?.[1]??NaN),
      processAfterLaunch:alive(),freeHostMemoryBytes:os.freemem()};
    await delay(5000);row.processAfter5s=alive();
    await delay(10000);row.processAfter15s=alive();
    report.runs.push(row);save();console.log(JSON.stringify(row));
  }
  const warm=adb(['shell','am','start','-W','-n',`${id}/com.example.raikeopeu2026.MainActivity`]);
  report.warmLaunch={status:/Status:\s*(\w+)/.exec(warm.stdout??'')?.[1]??'not_reported',
    waitTimeMs:Number(/WaitTime:\s*(\d+)/.exec(warm.stdout??'')?.[1]??NaN)};
  await delay(30000);report.processAfterExtra30s=alive();
  // Only reason enums for this synthetic package; never save raw log text.
  const info=adb(['shell','dumpsys','activity','exit-info',id]).stdout??'';
  report.packageExitReasonEnums=[...new Set([...info.matchAll(/(?:^|\s)reason=(\d+) \(([^)]+)\)/g)].map(m=>`${m[1]}:${m[2]}`))];
  report.packageExitSubreasonEnums=[...new Set([...info.matchAll(/\bsubreason=(\d+) \(([^)]+)\)/g)].map(m=>`${m[1]}:${m[2]}`))];
  report.exitReasonLimit='History includes earlier test installs and our controlled force-stops; does not establish prior PID-loss cause.';
  report.reproducedProcessLoss=report.runs.some(r=>!r.processAfter15s)||!report.processAfterExtra30s;
  report.status=report.runs.every(r=>r.launchStatus==='ok'&&r.processAfter15s)&&
    report.warmLaunch.status==='ok'&&report.processAfterExtra30s?'LIMITED_STARTUP_CHECK_PASS':'STARTUP_ISSUE_REVIEW_REQUIRED';
  save();console.log(JSON.stringify({status:report.status,reproducedProcessLoss:report.reproducedProcessLoss}));
  if(report.status!=='LIMITED_STARTUP_CHECK_PASS')process.exitCode=1;
}
