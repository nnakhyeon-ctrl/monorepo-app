import { mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { resolve, dirname, delimiter } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const mode = process.argv[2] ?? 'test';
if (!['test', '--native-email', '--native-core', '--native-persistence', '--serve'].includes(mode) || process.argv.length > 3) throw new Error('invalid_local_mode');
const local = resolve(root, '.runtime');
mkdirSync(local, { recursive: true });
for (const name of ['home', 'config', 'appdata', 'cloud', 'cache']) mkdirSync(resolve(local, name), { recursive: true });
writeFileSync(resolve(local, 'user.npmrc'), '');
writeFileSync(resolve(local, 'global.npmrc'), '');
// Never forward the IDE/agent environment or developer secrets to child tools.
const inherited = Object.fromEntries(['PATH', 'Path', 'PATHEXT', 'SystemRoot', 'SYSTEMROOT',
  'WINDIR', 'windir', 'COMSPEC', 'ComSpec', 'TEMP', 'TMP', 'JAVA_HOME']
  .filter((key) => process.env[key] !== undefined).map((key) => [key, process.env[key]]));
const env = { ...inherited, CI: 'true', AI_AGENT: 'codex_cli', FIREBASE_CLI_DISABLE_TELEMETRY: '1',
  GCLOUD_PROJECT: 'demo-airzero-strike', GOOGLE_CLOUD_PROJECT: 'demo-airzero-strike',
  XDG_CONFIG_HOME: resolve(local, 'config'), USERPROFILE: resolve(local, 'home'),
  APPDATA: resolve(local, 'appdata'), CLOUDSDK_CONFIG: resolve(local, 'cloud'),
  FIREBASE_EMULATORS_PATH: resolve(local, 'cache'),
  NPM_CONFIG_USERCONFIG: resolve(local, 'user.npmrc'), NPM_CONFIG_GLOBALCONFIG: resolve(local, 'global.npmrc'),
  FUNCTIONS_DISCOVERY_TIMEOUT: '30',
  METADATA_SERVER_DETECTION: 'none',
  FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9299', FIRESTORE_EMULATOR_HOST: '127.0.0.1:8280',
};
// JAVA_HOME alone does not make `java -version` discoverable by Firebase CLI.
if (env.JAVA_HOME && existsSync(resolve(env.JAVA_HOME, 'bin', process.platform === 'win32' ? 'java.exe' : 'java'))) {
  const currentPath = env.Path ?? env.PATH ?? '';
  for (const key of Object.keys(env)) if (key.toLowerCase() === 'path') delete env[key];
  env[process.platform === 'win32' ? 'Path' : 'PATH'] = resolve(env.JAVA_HOME, 'bin') + delimiter + currentPath;
}
// Constant local-only command; no deploy/login/import/export, no user shell text.
const child = spawn(process.execPath, [resolve(root, 'node_modules/firebase-tools/lib/bin/firebase.js'),
  mode === '--serve' ? 'emulators:start' : 'emulators:exec', '--project', 'demo-airzero-strike', '--config', 'firebase.json',
  '--log-verbosity', 'QUIET',
  '--only', 'auth,firestore,functions',
  ...(mode === '--serve' ? [] : [mode === '--native-email' ? 'node tool/native-email-test.mjs' : mode === '--native-core' ? 'node tool/native-email-test.mjs --core' : mode === '--native-persistence' ? 'node tool/native-email-test.mjs --persistence' : 'node --test --test-concurrency=1 build/test/email-emulator.test.js build/test/emulator.test.js build/test/social-emulator.test.js build/test/account-emulator.test.js build/test/billing-emulator.test.js'])], { cwd: root, env, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true });
// Auth Emulator prints action URLs by default. Never expose links/credentials.
for (const stream of [child.stdout, child.stderr]) {
  const lines = createInterface({ input: stream });
  lines.on('line', (line) => {
    if (/https?:\/\/|oobCode|idToken|refreshToken|Bearer |@example\.|password=|apiKey=/i.test(line)) return;
    process.stdout.write(line + '\n');
  });
}
child.on('error', () => { console.error('local_emulator_start_failed'); process.exitCode = 1; });
child.on('exit', (code) => { process.exitCode = code ?? 1; });
