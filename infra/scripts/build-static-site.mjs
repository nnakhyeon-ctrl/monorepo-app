#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { root, args, slug, reserved, appPath, child, privateName, secretContent, html } from '../../scripts/lib/safety.mjs';

const marker = '.generated-static-site.json';
const owner = 'monorepo-static-site-v1';
const extensions = new Set(['.html','.css','.js','.mjs','.json','.txt','.xml','.svg','.png','.jpg','.jpeg','.webp','.gif','.ico','.woff','.woff2']);
const digest = data => crypto.createHash('sha256').update(data).digest('hex');
function inventory(base, relative = '') {
  const list = [];
  for (const entry of fs.readdirSync(relative ? child(base, relative) : base, {withFileTypes:true})) {
    const rel = relative ? relative + '/' + entry.name : entry.name;
    const absolute = child(base, rel);
    if (entry.isDirectory()) list.push(...inventory(base, rel));
    else if (entry.isFile()) list.push(rel);
    else throw Error('일반 파일과 폴더만 허용');
    // child()는 symlink·junction·hardlink를 거부한다.
    void absolute;
  }
  return list.sort();
}
export function build(argv = [], base = root) {
  const a = args(argv, ['out']);
  const output = a.out || 'public-site';
  if (!/^public-site(?:-[a-z0-9]+)*$/.test(output)) throw Error('출력은 저장소 루트의 public-site 또는 public-site-이름 전용 폴더만 허용');
  const out = child(base, output);
  const files = new Map();
  const apps = [];
  for (const category of fs.readdirSync(base, {withFileTypes:true})) {
    if (reserved.has(category.name) || category.name.startsWith('.') || category.name.startsWith('public-site')) continue;
    try { slug(category.name, 'category'); } catch { continue; }
    if (category.isSymbolicLink()) throw Error('링크 카테고리 금지');
    if (!category.isDirectory()) continue;
    for (const app of fs.readdirSync(child(base, category.name), {withFileTypes:true})) {
      if (app.isSymbolicLink()) throw Error('링크 앱 금지');
      if (!app.isDirectory()) continue;
      const relative = category.name + '/' + app.name;
      const dir = appPath(base, relative);
      if (!['README.md','AGENTS.md','CLAUDE.md','ROADMAP.md','deploy.config.sh'].every(p => fs.existsSync(child(base, relative + '/' + p)))) continue;
      if (!fs.existsSync(child(base, relative + '/docs/index.html'))) continue;
      const docs = child(base, relative + '/docs');
      for (const p of inventory(docs)) {
        if (p.split('/').some(part => privateName.test(part))) throw Error('비공개 파일/폴더가 공개 docs에 있음: ' + relative + '/docs/' + p);
        const ext = path.extname(p).toLowerCase();
        if (!extensions.has(ext)) throw Error('공개 확장자 허용 목록에 없음: ' + p);
        const data = fs.readFileSync(child(docs, p));
        if (secretContent.test(data.toString('utf8'))) throw Error('공개 파일에 비밀 패턴 발견: ' + relative + '/docs/' + p);
        const target = relative + '/' + p;
        if ([...files.keys()].some(k => k.toLowerCase() === target.toLowerCase())) throw Error('공개 경로 충돌');
        files.set(target, data);
      }
      apps.push(relative);
      void dir;
    }
  }
  files.set('index.html', Buffer.from('<!doctype html><html lang="ko"><meta charset="utf-8"><title>앱 안내</title><h1>앱 안내</h1><ul>' + apps.map(a => '<li><a href="./' + a + '/">' + html(a) + '</a></li>').join('') + '</ul></html>\n'));
  // 이전 생성물의 소유 표시·목록·해시를 확인한다. 소스/사용자 파일은 삭제하지 않는다.
  if (fs.existsSync(out)) {
    if (!fs.statSync(out).isDirectory()) throw Error('출력 경로가 폴더가 아님');
    const existing = inventory(out);
    if (existing.length) {
      const p = child(out, marker);
      if (!fs.existsSync(p)) throw Error('소유 표시 없는 출력 폴더는 교체하지 않음');
      const previous = JSON.parse(fs.readFileSync(p, 'utf8'));
      if (previous.owner !== owner || !previous.files || typeof previous.files !== 'object') throw Error('잘못된 소유 표시');
      const expected = Object.keys(previous.files).sort();
      if (JSON.stringify(existing.filter(p => p !== marker)) !== JSON.stringify(expected)) throw Error('출력 폴더에 사용자 파일 또는 누락 파일 있음');
      for (const file of expected) if (digest(fs.readFileSync(child(out, file))) !== previous.files[file]) throw Error('수정된 출력 파일은 자동 삭제하지 않음');
    }
  }
  // 모든 입력을 검증한 다음 경계가 확인된 전용 출력만 교체한다.
  if (fs.existsSync(out)) fs.rmSync(out, {recursive:true});
  fs.mkdirSync(out);
  const manifest = {owner, files:{}};
  for (const [rel, data] of files) {
    const destination = child(out, rel);
    fs.mkdirSync(path.dirname(destination), {recursive:true});
    fs.writeFileSync(destination, data, {flag:'wx'});
    manifest.files[rel] = digest(data);
  }
  fs.writeFileSync(child(out, marker), JSON.stringify(manifest, null, 2) + '\n', {flag:'wx'});
  console.log('로컬 정적 페이지 생성: ' + output + ', 앱 ' + apps.length + '개 (업로드 없음)');
  return {out, apps};
}
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try { build(process.argv.slice(2)); } catch (error) { console.error(error.message); process.exitCode = 2; }
}
