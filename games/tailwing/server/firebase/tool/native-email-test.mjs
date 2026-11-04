import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mkdirSync } from 'node:fs';
if (process.env.GCLOUD_PROJECT !== 'demo-airzero-strike' || process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9299' ||
  process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8280') throw new Error('local_demo_only');
const appRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
if (process.argv.length > 3 || (process.argv[2] && !['--core', '--persistence'].includes(process.argv[2]))) throw new Error('invalid_native_target');
const core = process.argv[2] === '--core';
const persistence = process.argv[2] === '--persistence';
const nativeLocal = resolve(dirname(fileURLToPath(import.meta.url)), '../.runtime/native-local');
mkdirSync(nativeLocal, { recursive: true });
const env = { ...process.env, USERPROFILE: 'C:\\Users\\user', HOMEDRIVE: 'C:', HOMEPATH: '\\Users\\user',
  LOCALAPPDATA: nativeLocal,
  ANDROID_HOME: 'C:\\Users\\user\\AppData\\Local\\Android\\Sdk', JAVA_HOME: 'C:\\Program Files\\Android\\Android Studio\\jbr' };
// Inherit only the parent runner's already-whitelisted environment. No UI/IDE credentials.
const target = core ? 'integration_test/screen_flow_test.dart' : persistence ? 'integration_test/update_persistence_test.dart' : 'integration_test/email_flow_test.dart';
async function run(phase = '') {
// Keep Flutter's plugin regeneration enabled when switching release <-> test.
// --no-pub skips that step in this SDK and can leave a stale registrant.
const command = `& 'C:\\Users\\user\\flutter\\bin\\flutter.bat' --suppress-analytics test ${target} -d emulator-5554 --dart-define=AIRZERO_INTEGRATION=true ${core || persistence ? '' : '--dart-define=AIRZERO_AUTH_EMULATOR=true'} ${phase ? `--dart-define=AIRZERO_PERSISTENCE_PHASE=${phase}` : ''} --no-uninstall --reporter expanded; exit $LASTEXITCODE`;
const child = spawn('powershell.exe', ['-NoProfile', '-Command', command], { cwd: appRoot, env, stdio: ['ignore','pipe','pipe'], windowsHide:true });
for (const stream of [child.stdout,child.stderr]) createInterface({ input:stream }).on('line',line=> {
  if (/https?:\/\/|oobCode|idToken|refreshToken|token listeners|Bearer |@example\.|apiKey=|D\/FirebaseAuth/i.test(line)) return;
  process.stdout.write(line+'\n');
});
return new Promise(resolve => {
  child.on('error',()=>{ console.error('native_email_test_start_failed'); resolve(1); });
  child.on('close',code=>resolve(code??1));
});
}
const code = await run(persistence ? 'seed' : '');
process.exitCode = code === 0 && persistence ? await run('verify') : code;
