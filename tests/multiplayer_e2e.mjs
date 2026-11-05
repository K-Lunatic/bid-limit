import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import { createSignalingServer } from '../signaling/server.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const godot = process.env.GODOT_BIN || '/private/tmp/godot-4.7.2/Godot.app/Contents/MacOS/Godot';
const server = createSignalingServer();
const children = [];
try {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;
  const post = async (path, body) => {
    const response = await fetch(origin + path, { method:'POST', headers:{'content-type':'application/json'}, body:JSON.stringify(body) });
    assert.ok(response.ok);
    return response.json();
  };
  const host = await post('/rooms', {name:'자동 4인 검증', private:true, password:'test-only'});
  const members = [host];
  for (let i=0; i<3; i++) members.push(await post(`/rooms/${host.room.id}/join`, {password:'test-only'}));
  await Promise.all(members.map(member => new Promise((resolve, reject) => {
    const settings = {roomId:host.room.id, peerId:member.peerId, token:member.token};
    const child = spawn(godot, ['--headless','--path',root,'--script','res://tests/multiplayer_peer.gd','--',`--signal-url=${origin}`,`--e2e=${JSON.stringify(settings)}`], {cwd:root});
    children.push(child);
    let output = '';
    let passed = false;
    const timeout = setTimeout(() => reject(new Error(`role ${member.peerId} timeout\n${output.slice(-5000)}`)), 30000);
    child.stdout.on('data', chunk => {
      output += chunk;
      const match = output.match(/BID_E2E_PASS[^\n]+/);
      if (match && !passed) { passed=true; clearTimeout(timeout); console.log(match[0]); resolve(); }
    });
    child.stderr.on('data', chunk => {output += chunk;});
    child.once('error', error => {clearTimeout(timeout); reject(error);});
    child.once('exit', code => {clearTimeout(timeout); reject(new Error(`role ${member.peerId} exited ${code}\n${output.slice(-5000)}`));});
  })));
  const hostDropStarted = Date.now();
  const dropped = children.slice(1).map((child,index) => new Promise((resolve,reject) => {
    let output = '';
    const timeout = setTimeout(() => reject(new Error(`host disconnect timeout role=${index+2}\n${output.slice(-3000)}`)),35000);
    child.stdout.on('data',chunk => {
      output += chunk;
      const match = output.match(/BID_E2E_HOST_LOST[^\n]+/);
      if (match) { clearTimeout(timeout); assert.ok(Date.now()-hostDropStarted < 12000); console.log(`${match[0]} detected_ms=${Date.now()-hostDropStarted}`); resolve(); }
    });
    child.once('exit',code => {clearTimeout(timeout);reject(new Error(`guest exited during host loss: ${code}`));});
  }));
  children[0].kill('SIGTERM');
  await Promise.all(dropped);
  console.log('Four-process WebRTC + real game scene + host disconnect: PASS');
} finally {
  for (const child of children) if (child.exitCode === null && child.signalCode === null) child.kill('SIGTERM');
  await Promise.all(children.map(child => (child.exitCode !== null || child.signalCode !== null) ? Promise.resolve() : new Promise(resolve => child.once('exit', resolve))));
  server.closeAllConnections();
  await new Promise(resolve => server.close(resolve));
}
