#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { privateName, secretContent } from './lib/safety.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ignoredDirs = new Set(['.git', 'node_modules', '.terraform', 'build', 'DerivedData', 'public-site', '.tools', '.test-tmp']);
const ignoredFiles = new Set(['package-lock.json', 'check-sensitive.mjs', 'check-docs.mjs']);
// Public source/lock metadata only; these names also match the broader private-name guard.
const publicPaths = new Set([
  'games/tailwing/.metadata',
  'infra/aws/.terraform.lock.hcl',
  'games/tailwing/tool/capture_store_android.mjs',
  'games/tailwing/tool/capture_tailwing_android.mjs',
  'games/tailwing/tool/capture_tailwing_design.mjs',
]);
const patterns = [
  /limsangjin12/i,
  /jin-apps/i,
  /jin-factory/i,
  /com\.jin/i,
  /gmail\.com/i,
  /BEGIN (RSA |EC |OPENSSH |PRIVATE )?KEY/,
  /AKIA[0-9A-Z]{16}/,
  /AIza[0-9A-Za-z_-]{35}/,
  /ghp_[0-9A-Za-z]{36}/,
];
const allowedPublicReferences = [
  'https://github.com/limsangjin12/app-templates',
  'git@github.com:limsangjin12/app-templates.git',
  'https://github.com/limsangjin12/app-templates.git',
  'https://raw.githubusercontent.com/limsangjin12/app-templates/main/README.md',
  'https://raw.githubusercontent.com/limsangjin12/app-templates/main/AGENTS.md',
  'https://raw.githubusercontent.com/limsangjin12/app-templates/main/prompts/app-development-environment-setup.md',
];

function withoutAllowedPublicReferences(content) {
  let sanitized = content;
  for (const value of allowedPublicReferences) {
    sanitized = sanitized.split(value).join('');
  }
  return sanitized;
}

function walk(dir, result = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const relPath = path.relative(root, path.join(dir, entry.name)).replaceAll('\\', '/');
    if (entry.isDirectory() && (ignoredDirs.has(entry.name) || entry.name.startsWith('public-site-'))) continue;
    if (entry.isSymbolicLink()) throw new Error('민감정보 검사 대상 링크 금지');
    if (privateName.test(entry.name) && !['.claude','.codex','.github','.vscode','.gitignore'].includes(entry.name) && !publicPaths.has(relPath)) continue;
    const fullPath = path.join(dir, entry.name);
    // Never traverse the installed SDK or its third-party fixtures.
    if (fullPath === path.join(root, 'flutter')) continue;
    if (entry.isDirectory()) walk(fullPath, result);
    else if (!ignoredFiles.has(entry.name)) result.push(fullPath);
  }
  return result;
}

const findings = [];
// 민감 파일은 본문을 읽지 않고, 이미 추적됐는지 이름만 검사한다.
const tracked = execFileSync('git', ['ls-files','-z'], {cwd:root,encoding:'utf8'}).split('\0').filter(Boolean);
for (const file of tracked) {
  const parts = file.split('/');
  if (!publicPaths.has(file) && parts.some(p => privateName.test(p) && !['.claude','.codex','.github','.vscode','.gitignore'].includes(p))) findings.push(file + ': 비공개 파일이 이미 추적됨');
}
for (const file of walk(root)) {
  const rel = path.relative(root, file);
  let content;
  try {
    content = fs.readFileSync(file, 'utf8');
  } catch {
    continue;
  }
  content = withoutAllowedPublicReferences(content);
  if (secretContent.test(content)) findings.push(rel + ': 비밀 패턴 (값 생략)');
  for (const pattern of patterns) {
    if (pattern.test(content)) findings.push(`${rel}: ${pattern}`);
  }
}

if (findings.length) {
  console.error('민감정보 패턴 검사 실패:');
  for (const finding of findings) console.error(`- ${finding}`);
  process.exit(1);
}

console.log('민감정보 패턴 검사 통과');
