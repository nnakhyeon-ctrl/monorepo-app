import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {tmpdir} from 'node:os';
import {snapshot,verifySnapshot,inside,validateVectorText,assertUneditedGeneratedFiles,digest} from './release_candidate.mjs';
test('source evidence expires on editing or new assets and never includes signing contents',()=>{
 const dir=fs.mkdtempSync(path.join(tmpdir(),'tailwing-release-'));
 try{
  fs.mkdirSync(path.join(dir,'lib'));fs.mkdirSync(path.join(dir,'assets'));fs.mkdirSync(path.join(dir,'android'));
  fs.writeFileSync(path.join(dir,'lib/main.dart'),'void main() {}');
  fs.writeFileSync(path.join(dir,'android/key.properties'),'password=SYNTHETIC_MUST_NOT_BE_READ');
  const saved=snapshot(dir);assert.equal(verifySnapshot(dir,saved).matches,true);
  assert.equal(JSON.stringify(saved).includes('SYNTHETIC'),false);assert.equal(saved.files.some(x=>x.path.includes('key.properties')),false);
  fs.writeFileSync(path.join(dir,'lib/main.dart'),'void main() { return; }');
  assert.equal(verifySnapshot(dir,saved).matches,false);
  fs.writeFileSync(path.join(dir,'assets/new.txt'),'synthetic asset');
  assert.deepEqual(verifySnapshot(dir,saved).added,['assets/new.txt']);
  assert.throws(()=>inside(dir,'../outside'),/invalid_relative_path/);
 }finally{
  assert.ok(path.resolve(dir).startsWith(path.resolve(tmpdir())+path.sep));fs.rmSync(dir,{recursive:true,force:true});
 }
});
test('editable SVG renderer refuses scripts and external resources',()=>{
  assert.equal(validateVectorText('<svg><path fill="url(#mint)"/></svg>'),'<svg><path fill="url(#mint)"/></svg>');
  for(const s of ['<svg><script>bad()</script></svg>','<svg onload="bad()"/>','<svg><image href="https://example.test/a.png"/></svg>','<svg><image href="../private.png"/></svg>'])assert.throws(()=>validateVectorText(s));
});
test('regenerating local pages preserves an owner edit instead of overwriting it',()=>{
 const dir=fs.mkdtempSync(path.join(tmpdir(),'tailwing-pages-'));
 try{
  fs.mkdirSync(path.join(dir,'pages'));fs.writeFileSync(path.join(dir,'pages/index.html'),'generated');
  const before={ 'index.html':digest(Buffer.from('generated')) };
  assert.doesNotThrow(()=>assertUneditedGeneratedFiles(dir,'pages',{'index.html':'new template'},before));
  fs.writeFileSync(path.join(dir,'pages/index.html'),'owner edit');
  assert.throws(()=>assertUneditedGeneratedFiles(dir,'pages',{'index.html':'new template'},before),/keep_user_changes/);
  assert.equal(fs.readFileSync(path.join(dir,'pages/index.html'),'utf8'),'owner edit');
 }finally{assert.ok(path.resolve(dir).startsWith(path.resolve(tmpdir())+path.sep));fs.rmSync(dir,{recursive:true,force:true});}
});
