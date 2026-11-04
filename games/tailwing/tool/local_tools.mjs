// Explicit local tooling paths only. Never load .env, credentials or local.properties.
import {existsSync} from 'node:fs';
import {homedir} from 'node:os';
import {resolve, dirname, parse} from 'node:path';
import {fileURLToPath} from 'node:url';

export const appRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const kstDate = () => new Intl.DateTimeFormat('sv-SE', {timeZone:'Asia/Seoul'}).format(new Date());
export const psQuote = value => "'" + String(value).replaceAll("'", "''") + "'";

export function localTools({android = false, source = process.env} = {}) {
  const home = source.USERPROFILE || homedir();
  const appData = source.LOCALAPPDATA || resolve(home, 'AppData/Local');
  const flutter = [resolve(appRoot, '../../flutter/bin/flutter.bat'),
    source.FLUTTER_ROOT && resolve(source.FLUTTER_ROOT, 'bin/flutter.bat'),
    resolve(home, 'flutter/bin/flutter.bat')].filter(Boolean).find(existsSync);
  if (!flutter) throw Error('Flutter SDK unavailable: use repository flutter/ or FLUTTER_ROOT');
  const env = Object.fromEntries(['PATH','Path','PATHEXT','SystemRoot','SYSTEMROOT','WINDIR','windir',
    'COMSPEC','ComSpec','TEMP','TMP','PROGRAMFILES','ProgramFiles','ProgramFiles(x86)','ProgramW6432']
    .filter(k => source[k] !== undefined).map(k => [k, source[k]]));
  Object.assign(env, {USERPROFILE:home, HOMEDRIVE:parse(home).root.replace(/[\\/]$/, ''),
    HOMEPATH:home.slice(parse(home).root.length - 1), LOCALAPPDATA:appData,
    PUB_CACHE:source.PUB_CACHE || resolve(appData, 'Pub/Cache'), CI:'true'});
  let sdk, buildTools, java;
  if (android) {
    sdk = [source.ANDROID_HOME, source.ANDROID_SDK_ROOT, resolve(appData, 'Android/Sdk')]
      .filter(Boolean).find(p => existsSync(resolve(p, 'platform-tools/adb.exe')));
    if (!sdk) throw Error('Android SDK unavailable: install SDK via Android Studio or set ANDROID_HOME');
    buildTools = resolve(sdk, 'build-tools/36.0.0');
    if (!existsSync(resolve(buildTools, 'aapt2.exe'))) throw Error('Android build-tools 36.0.0 unavailable');
    java = [source.JAVA_HOME, 'C:/Program Files/Android/Android Studio/jbr']
      .filter(Boolean).find(p => existsSync(resolve(p, 'bin/java.exe')));
    if (!java) throw Error('Java unavailable: set JAVA_HOME to Android Studio JBR');
    Object.assign(env, {ANDROID_HOME:sdk, ANDROID_SDK_ROOT:sdk, JAVA_HOME:java});
  }
  return {flutter, env, sdk, buildTools, java,
    command: args => '& ' + [flutter, '--suppress-analytics', ...args].map(psQuote).join(' ') + '; exit $LASTEXITCODE'};
}
