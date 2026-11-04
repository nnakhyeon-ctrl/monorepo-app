// Reconcile local evidence/artifacts, not new gameplay or live-store tests.
import {readFileSync,writeFileSync,readdirSync,lstatSync,existsSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {inspectBillingSetup} from './check_billing_readiness.mjs';

if(process.argv.length!==2)throw new Error('no_arguments');
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const read=p=>JSON.parse(readFileSync(resolve(root,p),'utf8'));
const hash=b=>createHash('sha256').update(b).digest('hex');
const requireCheck=(ok,code)=>{if(!ok)throw new Error(code);};
const builds=read('docs/tailwing/BUILDS.json'),release=read('docs/tailwing/APK-INSPECTION.json');
const startup=read('docs/tailwing/STARTUP-CHECK.json'),native=read('docs/tailwing/NATIVE-FOLLOWUP.json'),lab=read('docs/tailwing/NATIVE-LAB-RECHECK.json');
const roster=read('docs/tailwing/ROSTER-CATALOG.json').pilots,review=read('docs/tailwing/REVIEW-INVENTORY.json');
const security=read('docs/tailwing/SECURITY-RECHECK.json'),billing=inspectBillingSetup(root);
const source=[];
function collect(p){for(const name of readdirSync(resolve(root,p)).sort()){
  const path=p+'/'+name,s=lstatSync(resolve(root,path));requireCheck(!s.isSymbolicLink(),'source_symlink');
  if(s.isDirectory())collect(path);else if(s.isFile())source.push({path,sha256:hash(readFileSync(resolve(root,path)))});
}}
collect('lib');collect('assets');
for(const path of ['pubspec.yaml','pubspec.lock','android/app/build.gradle.kts','android/app/src/main/AndroidManifest.xml','ios/Runner/Info.plist'])source.push({path,sha256:hash(readFileSync(resolve(root,path)))});
source.sort((a,b)=>a.path.localeCompare(b.path,'en'));
const fingerprint=hash(Buffer.from(source.map(f=>`${f.path}\0${f.sha256}\n`).join('')));
let checkedHashes=0;
for(const [mode,fixed] of [['preview','build/tailwing-preview/tailwing-preview-debug.apk'],['release-inspection','build/tailwing-preview/tailwing-inspection-unsigned.apk']]){
  const b=builds[mode];requireCheck(b.path===fixed,'unexpected_artifact_path');
  const bytes=readFileSync(resolve(root,fixed));
  requireCheck(bytes.length===b.bytes&&hash(bytes)===b.sha256,'artifact_hash_mismatch');checkedHashes++;
  requireCheck(b.sourceFingerprint===fingerprint,'source_differs_from_build');
}
requireCheck(release.sha256===builds['release-inspection'].sha256&&Object.values(release.checks).every(Boolean),'release_static_failed');
requireCheck(release.signature==='UNSIGNED_NOT_INSTALLABLE_OR_SUBMITTABLE','unexpected_signing_state');
requireCheck(startup.sha256===builds.preview.sha256&&startup.status==='LIMITED_STARTUP_CHECK_PASS'&&startup.ownedEmulatorStopped,'startup_not_confirmed');
requireCheck(!startup.uninstallOrDataClear&&!startup.normalAppTouched,'isolation_not_preserved');
requireCheck(native.flow?.phase==='won'&&native.flow.bossSeen&&native.flow.recordCleared&&!native.flow.enemiesHealthScoreInjected,'native_flow_not_confirmed');
requireCheck(lab.exitCode===0&&lab.lab?.pilots.length===12&&lab.lab.normalPremiumGranted===false&&lab.lab.records===0,'native_lab_not_confirmed');
requireCheck(roster.length===12&&roster.filter(p=>p.freeCharacter).map(p=>p.id).sort().join(',')==='eden,pilot,rion','roster_access_mismatch');
requireCheck(roster.every(p=>lab.lab.pilots.includes(p.id)),'native_roster_differs');
for(const f of review.files){
  requireCheck(/^(assets\/tailwing|docs\/tailwing\/(?:screenshots|followup-screenshots))\/[a-z0-9_-]+\.png$/.test(f.path),'unexpected_review_path');
  const bytes=readFileSync(resolve(root,f.path));requireCheck(bytes.length===f.bytes&&hash(bytes)===f.sha256,'review_hash_mismatch');checkedHashes++;
}
const captures=review.files.filter(f=>f.path.startsWith('docs/tailwing/'));
requireCheck(review.files.length===47&&captures.length===20,'review_inventory_incomplete');
requireCheck(hash(readFileSync(resolve(root,'server/firebase/package-lock.json')))===security.lockSha256,'security_lock_changed');
requireCheck(security.all.moderate===5&&security.production.total===0&&security.compatibleDryRun.changed===0&&!security.installedChanged,'security_evidence_differs');
const purchaseLocked=billing.checks.some(c=>c.id==='purchase_activation'&&c.code==='purchase_remains_disabled'&&c.status==='PASS');
requireCheck(purchaseLocked&&billing.localStatus==='PENDING','purchase_gate_changed');
let links=0;
const documents=['README.md','ROADMAP.md','docs/TAILWING-ROSTER-RESULTS.md','docs/TAILWING-FOLLOWUP-RESULTS.md','docs/TAILWING-RUN-GUIDE.md','docs/STAGE11-RESULTS.md','docs/STAGE12-PREPARATION.md','docs/STAGE11-SECURITY-FOLLOWUP.md'];
for(const p of documents)for(const m of readFileSync(resolve(root,p),'utf8').matchAll(/\]\(([^)]+)\)/g)){
  const target=m[1].replace(/^<|>$/g,'').split('#')[0];if(!target||/^(https?:|mailto:)/.test(target))continue;
  requireCheck(existsSync(resolve(root,dirname(p),target)),'documentation_link_missing');links++;
}
const report={date:new Intl.DateTimeFormat('sv-SE',{timeZone:'Asia/Seoul'}).format(new Date()),
  status:'LOCAL_FOLLOWUP_EVIDENCE_RECONCILED_NOT_FINAL_OR_SUBMISSION_READY',
  sourceFingerprint:fingerprint,sourceScope:builds.preview.sourceScope,currentBuildsMatchSource:true,
  artifactAndPngHashesChecked:checkedHashes,markdownLocalLinksChecked:links,runtimeAssets:27,actualCaptures:20,
  retainedTests:{affectedFlutter:64,fullAnalysis:'No issues found (35.5s); targeted followup/tool analysis also passed',
    nativeFlow:'initial run one passed/one lab harness failure; full stage 273.483s and retry passed',
    nativeLab:'corrected lazy-scroll harness, isolated lab rerun one passed, all 12 checked',
    server:'unchanged; previous 21 unit/43 demo history retained, not rerun'},
  startup:{status:startup.status,coldStarts:startup.runs.map(r=>r.totalTimeMs),warmWaitMs:startup.warmLaunch.waitTimeMs,
    previousHistoricalCause:'UNDETERMINED',physicalPerformance:'NOT_RUN'},
  security:{moderate:5,production:0,safeCompatibleDryRunChanges:0,unresolved:true},
  billing:{purchaseLocked,missingIds:7,missingPublicUrls:4,liveVerification:'NOT_RUN'},
  release:{status:release.status,signature:release.signature,runtimeOfUnsignedApk:'NOT_RUN'},
  pending:['real auth/server/store/notifications','public deletion website','Apple/iOS and physical devices',
    'profile/release long-session performance and balance','five development security warnings',
    'new store icon/native splash/RGB captures/copy/policies and signed AAB/IPA'],
  noPaidActionsOrDeployOrRealUserDeletionOrCommit:true};
writeFileSync(resolve(root,'docs/tailwing/FOLLOWUP-LOCAL-CHECKS.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({status:report.status,hashChecks:checkedHashes,localLinks:links,purchaseLocked,submissionReady:false}));
