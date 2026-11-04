import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export const reserved = new Set(['scripts', 'infra', 'templates', 'docs', 'apps-deployment', 'public-site', 'node-modules', 'build', 'private', 'data', 'secrets', 'captures', 'logs']);
export const privateName = /^(?:\..*|private|secrets?|credentials?|data|datasets?|logs?|captures?|screenshots?|backups?)$|^(?:private|secrets?|credentials?|users?|customers?|datasets?|captures?|screenshots?)[._-]|\.(?:p8|p12|pfx|pem|key|jks|keystore|mobileprovision|provisionprofile|db|sqlite3?|csv|xlsx?|log|tfstate)(?:\..*)?$|^(?:google-services\.json|GoogleService-Info\.plist|key\.properties|local\.properties|service-account.*\.json|.*-sa\.json)$/i;
export const secretContent = /-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{30,}|AIza[0-9A-Za-z_-]{35}|"type"\s*:\s*"service_account"/;

export function args(argv, allowed, bools = []) {
  const result = {};
  for (const arg of argv) {
    if (!arg.startsWith('--')) throw Error('옵션은 --이름=값 형식이어야 합니다.');
    const equal = arg.indexOf('=');
    const key = arg.slice(2, equal < 0 ? undefined : equal);
    const value = equal < 0 ? true : arg.slice(equal + 1);
    if (!allowed.includes(key) || Object.hasOwn(result, key)) throw Error('알 수 없거나 중복된 옵션: ' + key);
    if (bools.includes(key)) {
      if (![true, 'true', 'false'].includes(value)) throw Error('잘못된 boolean: ' + key);
      result[key] = value !== 'false';
    } else {
      if (typeof value !== 'string' || !value) throw Error('값이 필요합니다: ' + key);
      result[key] = value;
    }
  }
  return result;
}

export function slug(value, label) {
  if (!/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/.test(value || '') || value.length > 60 || /^(?:con|prn|aux|nul|com[0-9]|lpt[0-9])(?:-|$)/i.test(value)) throw Error('잘못된 ' + label + ': 소문자 kebab-case만 허용');
  return value;
}

export function child(base, relative) {
  if (typeof relative !== 'string' || /[\\:\x00-\x1f]/.test(relative) || path.isAbsolute(relative) || path.win32.isAbsolute(relative) || relative.split('/').some(p => !p || p === '.' || p === '..' || /[<>"|?*]|[. ]$/.test(p) || /^(con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)/i.test(p))) throw Error('안전하지 않은 상대 경로');
  const absolute = path.resolve(base, relative);
  const rel = path.relative(base, absolute);
  if (!rel || rel.startsWith('..') || path.isAbsolute(rel)) throw Error('저장소 경계 이탈');
  // Windows junction도 lstat에서 symbolic link로 판별한다.
  let cursor = path.resolve(base);
  for (const part of relative.split('/')) {
    cursor = path.join(cursor, part);
    if (!fs.existsSync(cursor)) {
      try { fs.lstatSync(cursor); } catch (error) { if (error.code === 'ENOENT') continue; throw error; }
    }
    if (fs.existsSync(cursor)) {
      const stat = fs.lstatSync(cursor);
      if (stat.isSymbolicLink() || (stat.isFile() && stat.nlink > 1)) throw Error('링크 경로 금지');
    }
  }
  // 존재하지 않는 마지막 링크도 거부한다.
  for (let cursor = absolute; cursor !== path.resolve(base); cursor = path.dirname(cursor)) {
    try { if (fs.lstatSync(cursor).isSymbolicLink()) throw Error('링크 경로 금지'); }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  return absolute;
}

export function appPath(base, relative) {
  const parts = String(relative).split('/');
  if (parts.length !== 2) throw Error('앱 경로는 category/app 형식이어야 합니다.');
  parts.forEach(p => slug(p, '앱 경로'));
  if (reserved.has(parts[0])) throw Error('예약된 카테고리');
  return child(base, relative);
}

export const html = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'}[c]));
export const shell = value => "'" + String(value).replaceAll("'", "'\\''") + "'";
export function text(value, label, max = 2000) {
  if (typeof value !== 'string' || /[\x00-\x1f\x7f]/.test(value) || value.length > max) throw Error('잘못된 텍스트: ' + label);
  return value;
}
export function bash() {
  if (process.platform !== 'win32') return 'bash';
  const candidates = [process.env.ProgramFiles, process.env['ProgramFiles(x86)']].filter(Boolean).map(p => path.join(p, 'Git/bin/bash.exe'));
  const found = candidates.find(p => fs.existsSync(p));
  if (!found) throw Error('공식 Git for Windows의 Git Bash가 필요합니다.');
  return found;
}
export const bashPath = value => value.replaceAll('\\', '/');
