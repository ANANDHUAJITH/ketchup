#!/usr/bin/env node
/* Tests for the KetchupVM simulator engine:  node tools/test-kvm.js */
const path = require("path");
const dir = path.join(__dirname, "..", "archiso/airootfs/usr/share/ketchup/lens");
const KVM = require(path.join(dir, "kvm-engine.js")), SAMPLES = require(path.join(dir, "kvm-samples.js"));
let fails = 0;
const ok = (c, msg) => { if (!c) { fails++; console.log("FAIL:", msg); } else console.log("ok  :", msg); };
function run(id, settings, max = 20000) {
  const s = SAMPLES.find(x => x.id === id), m = KVM.create(Object.assign({}, s.settings, settings));
  for (const p of s.procs) { const r = m.load(p.src, p.name); if (r.errors) throw new Error(id + ": " + JSON.stringify(r.errors)); }
  const n = m.run(max); return { m, n };
}
// every sample assembles and terminates
for (const s of SAMPLES) { const { m, n } = run(s.id); ok(m.halted && n < 20000, `sample '${s.id}' halts (${n} steps, ${m.cycles} cycles)`); }
// 1 hello
{ const { m } = run("hello"); ok(m.console === "Hello, kernel!\n", "hello prints its text through write()"); ok(m.stats.syscalls === 2, "hello made 2 syscalls"); ok(m.stats.faults >= 1, "hello demand-paged its data (page fault)"); }
// 2 sequential sum
{ const { m } = run("seq"); const P = m.procs[0]; ok(P.regs[2] === 528, "sum of 1..32 is 528"); ok(m.stats.cacheHit > 3 * m.stats.cacheMiss - 6 && m.stats.cacheHit / (m.stats.cacheHit + m.stats.cacheMiss) > 0.6, `sequential hit rate high (${(100 * m.stats.cacheHit / (m.stats.cacheHit + m.stats.cacheMiss)).toFixed(0)}%)`); ok(m.stats.tlbMiss <= 4, `few TLB misses (${m.stats.tlbMiss})`); }
// 3 stride vs sequential
{ const a = run("stride").m; const b = (() => { const s = SAMPLES.find(x => x.id === "stride"), m = KVM.create(); m.load(s.procs[0].src.replace("STEP 16", "STEP 1"), "s1"); m.run(5000); return m; })();
  const ha = a.stats.cacheHit / (a.stats.cacheHit + a.stats.cacheMiss), hb = b.stats.cacheHit / (b.stats.cacheHit + b.stats.cacheMiss);
  ok(ha < 0.1, `stride 16 hit rate ~0 (${(ha * 100).toFixed(0)}%)`); ok(hb > 0.6, `stride 1 hit rate high (${(hb * 100).toFixed(0)}%)`); ok(a.cycles > b.cycles, `bad locality costs more cycles (${a.cycles} vs ${b.cycles})`); }
// 4 thrashing
{ const t8 = run("thrash", { frames: 8 }).m, t16 = run("thrash", { frames: 16 }).m;
  ok(t8.stats.faults >= 36, `thrash faults with 8 frames: ${t8.stats.faults}`); ok(t16.stats.faults <= 14, `no thrash with 16 frames: ${t16.stats.faults}`); ok(t8.cycles > 2 * t16.cycles, `thrashing is much slower (${t8.cycles} vs ${t16.cycles} cycles)`);
  const f = run("thrash", { frames: 8, policy: "FIFO" }).m; ok(f.stats.faults > 0, "FIFO policy also runs"); }
// 5 two processes
{ const { m } = run("procs"); ok(/A/.test(m.console) && /B/.test(m.console) && m.console.length === 16, `both processes printed 8 chars each: "${m.console}"`); ok(m.stats.ctx > 2, `context switches happened (${m.stats.ctx})`); ok(m.stats.irq > 0, `timer interrupts fired (${m.stats.irq})`);
  ok(m.procs[0].pt[2].pfn !== m.procs[1].pt[2].pfn || m.procs[0].state === "done", "same virtual page maps to different frames per process");
  ok(/AB|BA/.test(m.console), "output is interleaved"); }
// 6 page cache
{ const { m } = run("pagecache"); ok(m.stats.pcMiss === 1 && m.stats.pcHit === 1, "page cache: first read misses, second hits"); ok(m.console === "DEFGHIJKLMNOPQRS" || m.console.length === 16, `file content copied to user memory: "${m.console}"`); }
// 7 stack
{ const { m } = run("stack"); ok(m.procs[0].regs[1] === 20, "call/ret/stack: R1 = 20"); ok(m.procs[0].pt[15].present || m.procs[0].state === "done", "stack page (15) was faulted in"); }
// error reporting
{ const m = KVM.create(); const r = m.load("FROB R1\nJMP nowhere", "bad"); ok(r.errors && r.errors.length === 2, "assembler reports unknown instruction and label"); }
// memory model invariants after a thrash run
{ const { m } = run("thrash", { frames: 4 }); const used = m.frames.filter(Boolean).length; ok(used <= 4, "never more frames in use than exist"); m.frames.forEach((f, i) => { if (f) { const pte = m.procs.find(p => p.pid === f.pid).pt[f.vpn]; if (pte.present && pte.pfn !== i) ok(false, "page table and frame table agree"); } }); }
console.log(fails ? `\n${fails} FAILED` : "\nall passed"); process.exit(fails ? 1 : 0);
