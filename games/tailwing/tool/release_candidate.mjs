// Read only explicitly allowlisted source/material paths. Never read signing files.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';

export const digest = bytes => createHash('sha256').update(bytes).digest('hex');
export function validateVectorText(svg) {
  if (/<(?:script|foreignObject)\b|<!DOCTYPE|<\?xml-stylesheet|\bon\w+\s*=/i.test(svg)) throw Error('active_svg_not_allowed');
  for (const m of svg.matchAll(/\b(?:href|src)\s*=\s*["']([^"']+)["']/gi)) {
    if (!m[1].startsWith('#') && m[1]!=='icon-master.svg') throw Error('external_svg_resource_not_allowed');
  }
  for (const m of svg.matchAll(/url\(\s*["']?([^)'"\s]+)/gi)) if(!m[1].startsWith('#'))throw Error('external_svg_resource_not_allowed');
  return svg;
}
export function inside(root, relative) {
  if (path.isAbsolute(relative) || relative.split(/[\\/]/).some(p => !p || p === '..' || p === '.')) throw Error('invalid_relative_path');
  const base=fs.realpathSync(root), target=path.resolve(base,relative);
  if (!target.startsWith(base+path.sep)) throw Error('outside_app');
  let cursor=base;
  for (const part of relative.split('/')) {
    cursor=path.join(cursor,part);
    if (fs.existsSync(cursor)) {
      const s=fs.lstatSync(cursor);
      if (s.isSymbolicLink() || s.isFile()&&s.nlink>1) throw Error('linked_source_or_output');
    }
  }
  return target;
}
export const sourceRoots=['lib','assets','pubspec.yaml','pubspec.lock',
  'android/app/src/main','android/app/build.gradle.kts','android/build.gradle.kts',
  'android/settings.gradle.kts','android/gradle.properties','android/gradle/wrapper/gradle-wrapper.properties',
  'ios/Runner/Assets.xcassets','ios/Runner/Info.plist','ios/Runner/AppDelegate.swift',
  'ios/Runner/SceneDelegate.swift','ios/Runner/Runner.entitlements','ios/Runner.xcodeproj/project.pbxproj',
  'ios/Runner/PrivacyInfo.xcprivacy','ios/Runner/Runner-Bridging-Header.h','ios/Runner/Base.lproj',
  'ios/Flutter/Release.xcconfig','ios/Flutter/AuthPublic.xcconfig','ios/Flutter/AppFrameworkInfo.plist',
  'ios/Runner.xcworkspace/contents.xcworkspacedata','ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
  'ios/Podfile','ios/Podfile.lock',
  'server/firebase/src','server/firebase/package.json','server/firebase/package-lock.json',
  'server/firebase/firestore.rules','server/firebase/firestore.prod.rules'];
export function snapshot(root, roots=sourceRoots) {
  const files=[];
  function walk(p) {
    const absolute=inside(root,p); if(!fs.existsSync(absolute))return;
    const s=fs.lstatSync(absolute);
    if(s.isDirectory())for(const name of fs.readdirSync(absolute).sort())walk(p+'/'+name);
    else if(s.isFile())files.push({path:p,bytes:s.size,sha256:digest(fs.readFileSync(absolute))});
    else throw Error('unsupported_source');
  }
  roots.forEach(walk);files.sort((a,b)=>a.path.localeCompare(b.path,'en'));
  return {scope:'ALLOWLISTED_RAW_WORKTREE_BYTES_MOBILE_AND_SERVER_NOT_SECRETS_OR_BUILD',lineEndings:'RAW_WORKTREE_SHA_NOT_GIT_TREE_ID',files,
    fingerprint:digest(Buffer.from(files.map(f=>`${f.path}\0${f.sha256}\n`).join('')))};
}
export function verifySnapshot(root,saved) {
  const current=snapshot(root);
  return {matches:current.fingerprint===saved.fingerprint,
    changed:saved.files.filter(f=>!fs.existsSync(inside(root,f.path))||digest(fs.readFileSync(inside(root,f.path)))!==f.sha256).map(f=>f.path),
    added:current.files.filter(f=>!saved.files.some(old=>old.path===f.path)).map(f=>f.path)};
}
export function pngInfo(bytes) {
  if(bytes.length<26||!bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))throw Error('invalid_png');
  return {width:bytes.readUInt32BE(16),height:bytes.readUInt32BE(20),bitDepth:bytes[24],colorType:bytes[25]};
}
export function assertUneditedGeneratedFiles(root,folder,next,previous={}) {
  for(const [name,content] of Object.entries(next)) {
    const file=inside(root,folder+'/'+name);
    if(fs.existsSync(file)&&digest(fs.readFileSync(file))!==(previous[name]||digest(Buffer.from(content))))throw Error('local_page_edited_keep_user_changes');
  }
}
