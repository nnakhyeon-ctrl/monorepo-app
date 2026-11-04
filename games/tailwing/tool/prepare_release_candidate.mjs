// Local editable preparation only. No build, signing, login, hosting or store calls.
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {snapshot,inside,digest,pngInfo} from './release_candidate.mjs';
import {inspectBillingSetup} from './check_billing_readiness.mjs';
import {localTools} from './local_tools.mjs';
if(process.argv.length!==2)throw Error('no_arguments_accepted');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const rel='docs/release-prep-2026-11-04';
const folder=inside(root,rel);fs.mkdirSync(folder,{recursive:true});
const ownerPath=inside(root,rel+'/OWNER.json');
if(fs.existsSync(ownerPath)&&JSON.parse(fs.readFileSync(ownerPath,'utf8')).owner!=='tailwing-stage12-local')throw Error('foreign_output');
fs.writeFileSync(ownerPath,JSON.stringify({owner:'tailwing-stage12-local',date:'2026-11-04',notPublished:true},null,2)+'\n');
const write=(p,value)=>fs.writeFileSync(inside(root,rel+'/'+p),JSON.stringify(value,null,2)+'\n');
const source=snapshot(root);write('SOURCE-SNAPSHOT.json',source);
const read=p=>fs.readFileSync(inside(root,p),'utf8');
const version=/^version:\s*(\S+)/m.exec(read('pubspec.yaml'))?.[1];
let androidTools=false,androidReason='NOT_CHECKED';
try{localTools({android:true});androidTools=true;androidReason='SDK_TOOLS_PRESENT_NOT_DEVICE_VERIFIED';}catch(e){androidReason=/Android SDK/.test(String(e))?'ANDROID_SDK_MISSING':/build-tools/.test(String(e))?'BUILD_TOOLS_MISSING':'TOOLCHAIN_INCOMPLETE';}
const gradle=read('android/app/build.gradle.kts');
let targetSdk=null;
const sdkSource=path.resolve(root,'../../flutter/packages/flutter_tools/lib/src/android/gradle_utils.dart');
if(fs.existsSync(sdkSource))targetSdk=Number(/const targetSdkVersion = '(\d+)'/.exec(fs.readFileSync(sdkSource,'utf8'))?.[1])||null;
const signingPath=process.env.TAILWING_SIGNING_PROPERTIES;
const billing=inspectBillingSetup(root);
const auditPath=inside(root,rel+'/DEPENDENCY-AUDIT.json');
const dependencyAudit=fs.existsSync(auditPath)?JSON.parse(fs.readFileSync(auditPath,'utf8')):null;
const guards=[
 ['auth_emulator_debug_only',/kDebugMode\s*&&\s*const bool.fromEnvironment\('AIRZERO_AUTH_EMULATOR'\)/.test(read('lib/security/firebase_email.dart'))],
 ['backend_emulator_rejects_release',/if \(!kDebugMode \|\| !const bool.fromEnvironment\('AIRZERO_AUTH_EMULATOR'\)\)/.test(read('lib/security/backend_session.dart'))],
 ['research_loadout_free_outside_debug',/!kDebugMode\s*\? const FreeLoadout\(\)/.test(read('lib/features/animal_preview.dart'))],
 ['research_home_debug_only',/if \(kDebugMode\)/.test(read('lib/features/home.dart'))],
 ['release_integration_build_rejected',/Integration flag is debug-only/.test(gradle)],
 ['android_cleartext_disabled',/android:usesCleartextTraffic="false"/.test(read('android/app/src/main/AndroidManifest.xml'))],
 ['android_backup_disabled',/android:allowBackup="false"/.test(read('android/app/src/main/AndroidManifest.xml'))],
 ['ios_arbitrary_loads_disabled',/<key>NSAllowsArbitraryLoads<\/key>\s*<false\/>/.test(read('ios/Runner/Info.plist'))]
].map(([id,pass])=>({id,status:pass?'STATIC_PASS':'STATIC_REVIEW_REQUIRED',runtime:'NOT_RUN'}));
const dartLogs=source.files.filter(f=>f.path.startsWith('lib/')&&/\.dart$/.test(f.path))
 .filter(f=>/\b(?:print|debugPrint)\s*\(/.test(read(f.path))).map(f=>f.path);
const artifacts=['build/tailwing-preview/tailwing-preview-debug.apk','build/app/outputs/flutter-apk/app-release.apk',
 'build/app/outputs/bundle/release/app-release.aab','build/app/outputs/bundle/release/app.aab'].map(p=>{
 const absolute=inside(root,p),exists=fs.existsSync(absolute);
 return {path:p,exists,...(exists?{bytes:fs.statSync(absolute).size,sha256:digest(fs.readFileSync(absolute))}:{}),
  signature:'NOT_VERIFIED',sourceMatchesCurrent:'NOT_VERIFIED',execution:'NOT_RUN',submissionReady:false};
});
const head=execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim();
const dirty=execFileSync('git',['status','--porcelain','--untracked-files=no'],{cwd:root,encoding:'utf8'}).trim().length>0;
const report={date:'2026-11-04',app:'테일윙 · TAILWING',appPath:'games/tailwing',version,
 status:'LOCAL_EDITABLE_PREPARATION_ONLY_SUBMISSION_BLOCKED',submissionReady:false,stage13:'OPEN_FOR_CONTINUED_EDITING',
 sourceCommit:head,trackedWorktreeDirty:dirty,sourceFingerprint:source.fingerprint,
 android:{applicationId:'com.example.raikeopeu2026.dev',targetSdkFromInstalledFlutter:targetSdk,targetRequirementChecked:'API_36_2026-11-04',
  toolsPresent:androidTools,toolchainStatus:androidReason,signingPathConfigured:Boolean(signingPath),
  signingPathExists:Boolean(signingPath&&fs.existsSync(signingPath)),signingContentsRead:false,
  releaseSigningConnected:/signingConfig\s*=\s*signingConfigs/.test(gradle),signedAabProduced:false,
  pageSize16k:'CURRENT_BINARY_AND_DEVICE_NOT_VERIFIED',releaseExecution:'NOT_RUN',callbackExecution:'NOT_RUN'},
 ios:{host:process.platform,macAvailable:process.platform==='darwin',xcode:'NOT_VERIFIED_ON_WINDOWS',
  bundleId:'com.example.raikeopeu2026.dev',signing:'OWNER_PREPARATION_REQUIRED',archiveProduced:false,ipaProduced:false,execution:'NOT_RUN',
  appPrivacyManifestPresent:fs.existsSync(inside(root,'ios/Runner/PrivacyInfo.xcprivacy')),mergedSdkPrivacyManifests:'NOT_VERIFIED'},
 cloudBuild:'NOT_SELECTED_NOT_USED',releaseGuardChecks:guards,applicationLogCallFiles:dartLogs,
 sdkRuntimeLogging:'NOT_VERIFIED',billing:{source:billing.source,status:billing.localStatus,liveVerification:billing.liveVerification,authLocalStatus:billing.authLocalStatus,authLiveVerification:billing.authLiveVerification,
  pending:billing.checks.filter(x=>x.status!=='PASS').map(x=>({id:x.id,status:x.status,code:x.code}))},
 releaseArtifacts:artifacts,
 dependencyAudit:dependencyAudit?{scope:dependencyAudit.scope,reports:dependencyAudit.reports.map(r=>({scope:r.scope,status:r.status,counts:r.counts}))}:{status:'NOT_VERIFIED'},
 blockers:['STAGE11_LIVE_VERIFICATION_PENDING','ANDROID_SDK_AND_SIGNING','MAC_XCODE_AND_SIGNING',
  'LIVE_AUTH_CALLBACKS_AND_BACKEND','STORE_PRODUCTS_PRICES_AND_BILLING_TESTS','PUBLIC_POLICY_SUPPORT_DELETION_URLS',
  'FINAL_ICON_SELECTION_AND_NATIVE_ICON_UPDATE','CURRENT_SIGNED_BUILD_SCREENSHOTS_AND_RUNTIME_TESTS','CURRENT_DEPENDENCY_AUDIT_REVIEW_REQUIRED'],
 storesOrHostingChanged:false};
write('READINESS.json',report);
const shots=['home-rabbit','home-turtle','hangar-cards','shield-active'];
fs.mkdirSync(inside(root,rel+'/historical-frames'),{recursive:true});
const screenshots=shots.map(n=>{
 const from=`docs/tailwing/design-pass-01/after/${n}.png`,to=`${rel}/historical-frames/${n}.png`;
 fs.copyFileSync(inside(root,from),inside(root,to));
 return {path:`historical-frames/${n}.png`,source:from,captured:'2026-10-30',...pngInfo(fs.readFileSync(inside(root,to))),
  sha256:digest(fs.readFileSync(inside(root,to))),kind:'HISTORICAL_REAL_ANDROID_DEBUG_RENDER_WITH_SYNTHETIC_DATA',
  currentReleaseCapture:false,entitlement:n==='shield-active'?'SYNTHETIC_SUBSCRIPTION_TECHNIQUE_NOT_FREE_BASIC_SHIELD':'FREE_ROSTER_OR_LOCKED_SELECTION',submissionReady:false};
});write('FRAME-EVIDENCE.json',{screenshots});
const materials=[];
function inventory(p){for(const name of fs.readdirSync(inside(root,p?rel+'/'+p:rel))){
 const relative=p?p+'/'+name:name;
 if(['ASSET-INVENTORY.json','CHECKS.json'].includes(relative))continue;
 const absolute=inside(root,rel+'/'+relative),stat=fs.statSync(absolute);
 if(stat.isDirectory())inventory(relative);else{const b=fs.readFileSync(absolute);materials.push({path:relative,bytes:b.length,sha256:digest(b),...(/\.png$/.test(name)?pngInfo(b):{})});}
}}
inventory('');write('ASSET-INVENTORY.json',{status:'DRAFT_NOT_SUBMISSION_READY',files:materials});
console.log(JSON.stringify({status:report.status,sourceFiles:source.files.length,materials:materials.length,androidTools,sourceCommit:head,submissionReady:false}));
