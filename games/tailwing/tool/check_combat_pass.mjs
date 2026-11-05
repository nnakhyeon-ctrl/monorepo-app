// Synthetic app tests only. No live accounts, installs, store or hosting calls.
import {spawn} from 'node:child_process';
import {createInterface} from 'node:readline';
import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {appRoot,localTools,kstDate} from './local_tools.mjs';
const local=localTools();
const pass=process.argv[2]??'combat';
if(!['combat','character-item','audit','survivor'].includes(pass)||process.argv.length>3)throw Error('invalid_check_scope');
const tests=new Map(),errors=[],startup=[];
function startupLine(line) {
  if(/dubious ownership/i.test(line)) { startup.push('Flutter SDK ownership differs from the sandbox user; rerun with the permitted owner context.'); return; }
  if(/S-1-|owned by|current user|CodexSandbox|[A-Z]:[\\/]/i.test(line))return;
  if(startup.length<6&&!/token|Bearer|password|apiKey|https?:\/\//i.test(line))startup.push(line.slice(0,300));
}
const child=spawn('powershell.exe',['-NoProfile','-Command',local.command(['test','--no-pub','--reporter','json'])],
  {cwd:appRoot,env:local.env,windowsHide:true,stdio:['ignore','pipe','pipe']});
createInterface({input:child.stdout}).on('line',line=>{
  let e;try{e=JSON.parse(line);}catch{startupLine(line);return;}
  if(e.type==='testStart')tests.set(e.test.id,{name:e.test.name,result:'running',hidden:false});
  if(e.type==='testDone'&&tests.has(e.testID))Object.assign(tests.get(e.testID),{result:e.result,hidden:e.hidden});
  if(e.type==='error')errors.push({testID:e.testID,message:String(e.error).replace(/https?:\/\/\S+|[\w.+-]+@[\w.-]+/g,'[redacted]').slice(0,1600)});
});
createInterface({input:child.stderr}).on('line',startupLine);
const exitCode=await new Promise(done=>{child.on('error',()=>done(1));child.on('close',n=>done(n??1));});
const results=[...tests.values()].filter(t=>!t.hidden);
const report={date:kstDate(),scope:'LOCAL_SYNTHETIC_NOT_NATIVE_SIGNED_OR_LIVE',exitCode,
  passed:results.filter(t=>t.result==='success').length,failed:results.filter(t=>t.result!=='success').length,
  tests:results,errors,notRun:['Android/iOS physical GPU FPS and GC','signed package startup','real store purchases','real account callbacks']};
const output=resolve(appRoot,'docs/local-verification');mkdirSync(output,{recursive:true});
const prefix=pass==='survivor'?'SURVIVOR':pass==='audit'?'AUDIT':pass==='character-item'?'CHARACTER-ITEM':'COMBAT';
writeFileSync(resolve(output,`${prefix}-${kstDate()}.json`),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({exitCode,passed:report.passed,failed:report.failed,errors,startup:results.length?[]:startup}));
process.exitCode=exitCode;
