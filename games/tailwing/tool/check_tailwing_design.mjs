// Local impact suite only. Reports synthetic tests, never claims live service verification.
import {spawn} from 'node:child_process';
import {createInterface} from 'node:readline';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {mkdirSync,writeFileSync} from 'node:fs';
import {localTools,kstDate} from './local_tools.mjs';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const tools=localTools(),env=tools.env;
const files=['tailwing_design_test','animal_home_test','animal_roster_test','animal_lifecycle_test','loadout_preparation_test','battle_flow_test','basic_screens_test','menu_settings_test'].map(n=>`test/${n}.dart`);
const command=tools.command(['test','--no-pub',...files,'--reporter','json']);
const child=spawn('powershell.exe',['-NoProfile','-Command',command],{cwd:root,env,windowsHide:true,stdio:['ignore','pipe','pipe']});
const results=new Map(),errors=[],startup=[];
createInterface({input:child.stdout}).on('line',line=>{let e;try{e=JSON.parse(line);}catch{return;}
 if(e.type==='testStart')results.set(e.test.id,{name:e.test.name,result:'running',hidden:false});
 if(e.type==='testDone'){const test=results.get(e.testID);if(test){test.result=e.result;test.hidden=e.hidden;}}
 if(e.type==='error'){errors.push({testID:e.testID,message:String(e.error).replace(/https?:\/\/\S+|[\w.+-]+@[\w.-]+/g,'[redacted]').slice(0,1800)});}
});
createInterface({input:child.stderr}).on('line',line=>{
 if(startup.length<6&&!/token|Bearer|password|apiKey|https?:\/\//i.test(line))startup.push(line.slice(0,300));
});
const exitCode=await new Promise(done=>{child.on('error',()=>done(1));child.on('close',n=>done(n??1));});
const tests=[...results.values()].filter(t=>!t.hidden&&!t.name.startsWith('loading '));
const report={date:kstDate(),scope:'LOCAL_SYNTHETIC_NOT_LIVE_OR_PHYSICAL',exitCode,files,
 passed:tests.filter(t=>t.result==='success').length,failed:tests.filter(t=>t.result!=='success').length,tests,errors};
const reports=resolve(root,'docs/local-verification');mkdirSync(reports,{recursive:true});
writeFileSync(resolve(reports,`DESIGN-${kstDate()}.json`),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({exitCode,passed:report.passed,failed:report.failed,errors,startup:tests.length?[]:startup}));process.exitCode=exitCode;
