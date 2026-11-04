import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, mkdirSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {localTools, psQuote} from './local_tools.mjs';

test('local tooling keeps shell metacharacters literal and does not inherit credentials', () => {
  const dir = mkdtempSync(join(tmpdir(), 'tailwing-tools-'));
  try {
    mkdirSync(join(dir, 'bin'));
    writeFileSync(join(dir, 'bin/flutter.bat'), '@exit /b 0');
    const source = {USERPROFILE:dir, LOCALAPPDATA:dir, FLUTTER_ROOT:dir,
      FAKE_SECRET:'synthetic-test-only', FIREBASE_TOKEN:'synthetic-test-only'};
    const tools = localTools({source});
    assert.equal(tools.env.FIREBASE_TOKEN, undefined);
    assert.equal(tools.env.FAKE_SECRET, undefined);
    assert.equal(tools.env.FLUTTER_ROOT, undefined);
    assert.equal(psQuote("a'b$(whoami);x"), "'a''b$(whoami);x'");
    assert.match(tools.command(['test', "a'b$(whoami);x"]), /'a''b\$\(whoami\);x'/);
    assert.throws(() => localTools({source, android:true}), /Android SDK unavailable/);
  } finally {
    // dir is a fixed-prefix directory returned by mkdtemp, never user input.
    rmSync(dir, {recursive:true, force:true});
  }
});
