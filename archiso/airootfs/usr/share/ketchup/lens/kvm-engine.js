/* KetchupVM engine: a tiny computer you can single-step.
   CPU (8 x 16-bit registers, flags) -> MMU (page tables + TLB) -> L1 cache -> RAM (physical frames) -> disk,
   plus a mini kernel (page-fault handler, system calls, round-robin scheduler, page cache).
   Pure logic, no DOM: tested with node (tools/test-kvm.js). Sizes are tiny on purpose so everything fits on screen. */
const KVM = (() => {
  const PAGE = 16, VPAGES = 16, FILE_BLOCKS = 8;
  const DEFAULTS = { frames: 8, policy: "LRU", quantum: 12, tlbSize: 4, cacheLines: 4, lineSize: 4, flushTlb: true,
    cost: { instr: 1, tlb: 1, walk: 20, l1: 1, ram: 30, fault: 60, disk: 2000, syscall: 40, ctx: 60, irq: 30, pagecache: 25 } };
  const REGS = ["R0", "R1", "R2", "R3", "R4", "R5", "R6", "R7"];
  const SYSCALLS = { 1: "write(ptr=R1, len=R2)", 2: "exit(code=R1)", 3: "yield()", 4: "read_file(block=R1, dest=R2)", 5: "getpid()", 6: "sleep(ticks=R1)" };
  const m16 = v => v & 0xFFFF, hex = (v, n = 2) => "0x" + (v >>> 0).toString(16).toUpperCase().padStart(n, "0");

  /* ---------------- assembler ---------------- */
  function assemble(src) {
    const code = [], data = [], labels = {}, equ = {}, errors = [];
    const lines = src.split("\n");
    const num = (t, ln) => {
      if (t === undefined) return NaN;
      if (/^'.'$/.test(t)) return t.charCodeAt(1);
      if (/^-?\d+$/.test(t)) return parseInt(t, 10);
      if (/^0x[0-9a-f]+$/i.test(t)) return parseInt(t, 16);
      if (t in equ) return equ[t];
      return NaN;
    };
    const parsed = [];
    lines.forEach((raw, i) => {
      let line = raw.replace(/;.*$/, "").trim(); if (!line) return;
      let m;
      while ((m = line.match(/^([A-Za-z_]\w*):\s*(.*)$/))) { labels[m[1]] = parsed.filter(x => x.ins).length; line = m[2]; }
      if (!line) return;
      if (line[0] === ".") {
        const d = line.match(/^\.(\w+)\s+(.*)$/);
        if (!d) { errors.push({ line: i + 1, msg: "bad directive" }); return; }
        if (d[1] === "equ") { const a = d[2].split(/\s+/); equ[a[0]] = num(a[1]); }
        else if (d[1] === "data") { const a = d[2].match(/'.'|\S+/g); parsed.push({ dir: "data", a, ln: i + 1 }); }
        else if (d[1] === "string") { const mm = d[2].match(/^(\S+)\s+"(.*)"$/); if (mm) parsed.push({ dir: "string", addr: mm[1], str: mm[2], ln: i + 1 }); else errors.push({ line: i + 1, msg: 'usage: .string ADDR "text"' }); }
        else errors.push({ line: i + 1, msg: "unknown directive ." + d[1] });
        return;
      }
      const mm = line.match(/^(\w+)\s*(.*)$/);
      parsed.push({ ins: mm[1].toUpperCase(), ops: mm[2] ? mm[2].split(/,(?![^\[]*\])/).map(s => s.trim()) : [], ln: i + 1, text: line });
    });
    const reg = t => { if (!t) return -1; t = t.toUpperCase(); if (t === "SP") return 7; const k = REGS.indexOf(t); return k; };
    const memop = (t, ln) => {
      const m = t && t.match(/^\[\s*(\w+)\s*(?:([+-])\s*(\w+))?\s*\]$/);
      if (!m) { errors.push({ line: ln, msg: "expected [address]: " + t }); return { base: -1, off: 0 }; }
      const r = reg(m[1]);
      if (r >= 0) { const o = m[3] ? num(m[3]) : 0; if (isNaN(o)) errors.push({ line: ln, msg: "bad offset " + m[3] }); return { base: r, off: m[2] === "-" ? -o : o }; }
      const a = num(m[1]); if (isNaN(a)) errors.push({ line: ln, msg: "unknown symbol " + m[1] });
      return { base: -1, off: a };
    };
    const val = (t, ln) => { const r = reg(t); if (r >= 0) return { r }; const n = num(t); if (isNaN(n)) errors.push({ line: ln, msg: "bad operand " + t }); return { imm: n }; };
    const JUMPS = ["JMP", "JE", "JZ", "JNE", "JNZ", "JL", "JGE", "JG", "JLE"], ALU = ["ADD", "SUB", "AND", "OR", "XOR", "SHL", "SHR", "MUL"];
    for (const p of parsed) {
      if (p.dir === "data") { const addr = num(p.a[0]); const bytes = p.a.slice(1).map(x => num(x)); if ([addr, ...bytes].some(isNaN) || addr + bytes.length > 256) errors.push({ line: p.ln, msg: "bad .data" }); else data.push({ addr, bytes }); continue; }
      if (p.dir === "string") { const addr = num(p.addr); data.push({ addr, bytes: [...p.str.replace(/\\n/g, "\n")].map(c => c.charCodeAt(0)) }); continue; }
      const o = p.ops, I = { op: p.ins, ln: p.ln, text: p.text };
      if (ALU.includes(p.ins) || p.ins === "MOV") { I.d = reg(o[0]); I.s = val(o[1], p.ln); if (I.d < 0) errors.push({ line: p.ln, msg: "first operand must be a register" }); }
      else if (p.ins === "CMP") { I.d = reg(o[0]); I.s = val(o[1], p.ln); if (I.d < 0) errors.push({ line: p.ln, msg: "first operand must be a register" }); }
      else if (JUMPS.includes(p.ins) || p.ins === "CALL") { if (!(o[0] in labels)) errors.push({ line: p.ln, msg: "unknown label " + o[0] }); I.target = labels[o[0]]; }
      else if (p.ins === "LOAD") { I.d = reg(o[0]); I.mem = memop(o[1], p.ln); }
      else if (p.ins === "STORE") { I.mem = memop(o[0], p.ln); I.s = val(o[1], p.ln); }
      else if (p.ins === "PUSH") I.s = val(o[0], p.ln);
      else if (p.ins === "POP") I.d = reg(o[0]);
      else if (["RET", "SYSCALL", "NOP", "HALT"].includes(p.ins)) { /* no operands */ }
      else errors.push({ line: p.ln, msg: "unknown instruction " + p.ins });
      code.push(I);
    }
    return { code, data, labels, errors };
  }

  /* ---------------- machine ---------------- */
  function create(opts) {
    const cfg = Object.assign({}, DEFAULTS, opts || {}); cfg.cost = Object.assign({}, DEFAULTS.cost, (opts || {}).cost);
    const M = {
      cfg, ram: new Uint8Array(cfg.frames * PAGE), frames: Array.from({ length: cfg.frames }, () => null),
      tlb: [], cache: Array.from({ length: cfg.cacheLines }, () => ({ valid: false, tag: 0, dirty: false })),
      procs: [], cur: -1, cycles: 0, tick: 0, console: "", pageCache: [], mode: "user", halted: false,
      stats: { instrs: 0, tlbHit: 0, tlbMiss: 0, cacheHit: 0, cacheMiss: 0, faults: 0, evictions: 0, writebacks: 0, diskReads: 0, diskWrites: 0, syscalls: 0, ctx: 0, irq: 0, pcHit: 0, pcMiss: 0 },
      breakdown: { cpu: 0, mmu: 0, cache: 0, ram: 0, disk: 0, kernel: 0 }, last: [], lastIns: null,
    };
    let ev;
    const charge = (cat, c) => { M.cycles += c; M.breakdown[cat] += c; };
    const log = (k, t, c) => ev.push({ k, t, c: c || 0 });

    M.load = function (src, name) {
      const a = assemble(src); if (a.errors.length) return { errors: a.errors };
      const pid = M.procs.length + 1;
      const disk = Array.from({ length: VPAGES }, () => new Uint8Array(PAGE));
      for (const d of a.data) d.bytes.forEach((b, i) => { const ad = d.addr + i; disk[ad >> 4][ad & 15] = b & 255; });
      const P = { pid, name: name || "proc" + pid, code: a.code, labels: a.labels, pc: 0, regs: new Array(8).fill(0), z: false, n: false, disk,
        pt: Array.from({ length: VPAGES }, () => ({ present: false, pfn: -1, dirty: false, ref: false })), state: "ready", slice: 0, wakeAt: 0, exit: null, instrs: 0, faults: 0 };
      P.regs[7] = 0;                                  /* SP starts at 0: the first PUSH wraps to 0xFF, the top page */
      M.procs.push(P); if (M.cur < 0) { M.cur = 0; P.state = "running"; }
      M.halted = false; return { pid };
    };

    /* ----- kernel: frames, faults ----- */
    function pickVictim() {
      let best = -1, key = Infinity;
      M.frames.forEach((f, i) => { const k = M.cfg.policy === "FIFO" ? f.loadedAt : f.lastUsed; if (k < key) { key = k; best = i; } });
      return best;
    }
    function invalidateFrame(pfn) {
      M.tlb = M.tlb.filter(e => e.pfn !== pfn);
      for (let l = 0; l < M.cache.length; l++) { const c = M.cache[l]; if (c.valid && Math.floor(((c.tag * M.cfg.cacheLines + l) * M.cfg.lineSize) / PAGE) === pfn) c.valid = false; }
    }
    function pageFault(P, vpn) {
      M.stats.faults++; P.faults++; M.mode = "kernel";
      log("fault", `PAGE FAULT: process ${P.pid} touched virtual page ${vpn} (not in RAM). CPU traps into the kernel.`, M.cfg.cost.fault); charge("kernel", M.cfg.cost.fault);
      let pfn = M.frames.findIndex(f => f === null);
      if (pfn < 0) {
        pfn = pickVictim(); const f = M.frames[pfn], O = M.procs.find(x => x.pid === f.pid), pte = O.pt[f.vpn];
        M.stats.evictions++;
        log("kernel", `RAM full: evict frame ${pfn} (process ${f.pid} page ${f.vpn}) using ${M.cfg.policy}.`, 0);
        if (pte.dirty) { O.disk[f.vpn].set(M.ram.subarray(pfn * PAGE, pfn * PAGE + PAGE)); M.stats.diskWrites++; M.stats.writebacks++; charge("disk", M.cfg.cost.disk);
          log("disk", `Page was modified (dirty): write it back to disk first.`, M.cfg.cost.disk); }
        pte.present = false; pte.pfn = -1; pte.dirty = false; invalidateFrame(pfn);
        log("kernel", "Victim's page-table entry cleared, TLB and cache entries for that frame invalidated.", 0);
      } else log("kernel", `Free frame ${pfn} found.`, 0);
      M.ram.set(P.disk[vpn], pfn * PAGE); M.stats.diskReads++; charge("disk", M.cfg.cost.disk);
      log("disk", `Read page ${vpn} from disk into frame ${pfn} (the slow part: ~${M.cfg.cost.disk} cycles).`, M.cfg.cost.disk);
      const pte = P.pt[vpn]; pte.present = true; pte.pfn = pfn; pte.dirty = false; pte.ref = true;
      M.frames[pfn] = { pid: P.pid, vpn, loadedAt: ++M.tick, lastUsed: M.tick };
      log("kernel", `Page table updated: page ${vpn} → frame ${pfn}. Return to user mode and retry the instruction.`, 0);
      M.mode = "user";
    }

    /* ----- MMU + cache ----- */
    function translate(P, va, write) {
      const vpn = (va >> 4) & 15, off = va & 15, c = M.cfg.cost;
      let e = M.tlb.find(t => t.pid === P.pid && t.vpn === vpn);
      if (e) { M.stats.tlbHit++; charge("mmu", c.tlb); log("tlb", `TLB hit: page ${vpn} → frame ${e.pfn}`, c.tlb); }
      else {
        M.stats.tlbMiss++; charge("mmu", c.walk); log("tlb", `TLB miss for page ${vpn}: walk the page table in RAM`, c.walk);
        if (!P.pt[vpn].present) pageFault(P, vpn);
        const pte = P.pt[vpn]; log("tlb", `PTE[${vpn}] present → frame ${pte.pfn}; cache it in the TLB`, 0);
        e = { pid: P.pid, vpn, pfn: pte.pfn }; M.tlb.push(e); if (M.tlb.length > M.cfg.tlbSize) M.tlb.shift();
      }
      const pte = P.pt[vpn]; pte.ref = true; if (write) pte.dirty = true; M.frames[e.pfn].lastUsed = ++M.tick;
      return e.pfn * PAGE + off;
    }
    function cacheAccess(pa, write) {
      const c = M.cfg.cost, line = Math.floor(pa / M.cfg.lineSize), idx = line % M.cfg.cacheLines, tag = Math.floor(line / M.cfg.cacheLines), L = M.cache[idx];
      if (L.valid && L.tag === tag) { M.stats.cacheHit++; charge("cache", c.l1); log("cache", `L1 hit (line ${idx})`, c.l1); }
      else {
        M.stats.cacheMiss++; charge("ram", c.ram);
        log("cache", `L1 MISS (line ${idx} holds ${L.valid ? "another block" : "nothing"}): fetch ${M.cfg.lineSize} bytes from RAM @${hex(line * M.cfg.lineSize)}`, c.ram);
        if (L.valid && L.dirty) { charge("ram", c.ram); log("cache", "evicted line was dirty: write it back to RAM first", c.ram); }
        L.valid = true; L.tag = tag; L.dirty = false;
      }
      if (write) L.dirty = true;
    }
    function access(P, va, write, value) {
      va &= 255; const pa = translate(P, va, write); cacheAccess(pa, write);
      if (write) { M.ram[pa] = value & 255; return value & 255; }
      return M.ram[pa];
    }

    /* ----- scheduler ----- */
    const runnable = () => M.procs.filter(p => p.state === "ready" || p.state === "running");
    function wakeSleepers() { for (const p of M.procs) if (p.state === "sleeping" && M.cycles >= p.wakeAt) { p.state = "ready"; log("sched", `Process ${p.pid} wakes up (timer expired).`, 0); } }
    function schedule(reason) {
      wakeSleepers();
      const cur = M.procs[M.cur];
      if (cur && cur.state === "running") cur.state = "ready";
      let next = -1;
      for (let i = 1; i <= M.procs.length; i++) { const k = (M.cur + i) % M.procs.length; if (M.procs[k].state === "ready") { next = k; break; } }
      if (next < 0) {
        const sl = M.procs.filter(p => p.state === "sleeping");
        if (sl.length) { const t = Math.min(...sl.map(p => p.wakeAt)); log("sched", `All processes are blocked: CPU idles (HLT) for ${t - M.cycles} cycles.`, 0); charge("kernel", Math.max(0, t - M.cycles)); wakeSleepers(); return schedule(reason); }
        M.halted = true; M.mode = "user"; log("sched", "No runnable processes left: machine halted.", 0); return;
      }
      if (next !== M.cur) {
        M.stats.ctx++; charge("kernel", M.cfg.cost.ctx);
        log("sched", `CONTEXT SWITCH (${reason}): save registers of process ${cur ? cur.pid : "-"}, load process ${M.procs[next].pid}.`, M.cfg.cost.ctx);
        if (M.cfg.flushTlb) { M.tlb = []; log("tlb", "TLB flushed: the new process has different page tables (this is why switches hurt).", 0); }
      }
      M.cur = next; M.procs[next].state = "running"; M.procs[next].slice = 0;
    }
    function freeProcess(P) {
      M.frames.forEach((f, i) => { if (f && f.pid === P.pid) { M.frames[i] = null; invalidateFrame(i); } });
      M.tlb = M.tlb.filter(t => t.pid !== P.pid);
    }

    /* ----- syscalls ----- */
    function syscall(P) {
      const c = M.cfg.cost, n = P.regs[0], name = SYSCALLS[n] || "unknown";
      M.stats.syscalls++; M.mode = "kernel"; charge("kernel", c.syscall);
      log("kernel", `SYSCALL ${n} ${name}: the CPU switches to kernel mode (ring 3 → ring 0) and jumps to the kernel's syscall entry.`, c.syscall);
      if (n === 1) {
        const len = Math.min(P.regs[2], 64); let s = "";
        for (let i = 0; i < len; i++) s += String.fromCharCode(access(P, (P.regs[1] + i) & 255, false));
        M.console += s; P.regs[0] = len; log("io", `Kernel copies ${len} byte(s) from user memory to the console: "${s}"`, 0);
      } else if (n === 2) { P.state = "done"; P.exit = P.regs[1]; log("kernel", `exit(${P.regs[1]}): kernel frees process ${P.pid}'s RAM frames and page tables.`, 0); freeProcess(P); M.mode = "user"; schedule("exit"); return; }
      else if (n === 3) { M.mode = "user"; schedule("yield"); return; }
      else if (n === 4) {
        const b = P.regs[1] % FILE_BLOCKS, dest = P.regs[2];
        const hit = M.pageCache.indexOf(b);
        if (hit >= 0) { M.stats.pcHit++; M.pageCache.splice(hit, 1); M.pageCache.push(b); charge("kernel", c.pagecache); log("kernel", `Page cache HIT: file block ${b} is already in RAM (~${c.pagecache} cycles, no disk).`, c.pagecache); }
        else { M.stats.pcMiss++; M.stats.diskReads++; charge("disk", c.disk); log("disk", `Page cache MISS: read file block ${b} from disk (~${c.disk} cycles), keep a copy in RAM.`, c.disk); M.pageCache.push(b); if (M.pageCache.length > 4) M.pageCache.shift(); }
        for (let i = 0; i < PAGE; i++) access(P, (dest + i) & 255, true, (b * 16 + i + 65) & 255);
        P.regs[0] = PAGE; log("io", `Kernel copies ${PAGE} bytes into the process at ${hex(dest)} (copy_to_user).`, 0);
      } else if (n === 5) P.regs[0] = P.pid;
      else if (n === 6) { P.state = "sleeping"; P.wakeAt = M.cycles + P.regs[1] * 100; log("sched", `Process ${P.pid} sleeps ${P.regs[1]} ticks: the scheduler runs someone else.`, 0); M.mode = "user"; schedule("sleep"); return; }
      else P.regs[0] = m16(-1);
      M.mode = "user"; log("kernel", "sysret: back to user mode.", 0);
    }

    /* ----- one instruction ----- */
    M.step = function () {
      ev = []; M.last = ev;
      if (M.halted) { log("cpu", "Machine is halted.", 0); return false; }
      wakeSleepers();
      let P = M.procs[M.cur];
      if (!P || P.state !== "running") { schedule("start"); P = M.procs[M.cur]; if (M.halted) return false; }
      const I = P.code[P.pc]; M.lastIns = I ? { pid: P.pid, pc: P.pc, text: I.text } : null;
      if (!I) { log("cpu", `Process ${P.pid} ran off the end of its code: treated as exit.`, 0); P.state = "done"; P.exit = 0; freeProcess(P); schedule("exit"); return !M.halted; }
      const c = M.cfg.cost; charge("cpu", c.instr); M.stats.instrs++; P.instrs++; P.slice++;
      log("cpu", `FETCH/EXECUTE  [pid ${P.pid} pc ${P.pc}]  ${I.text}`, c.instr);
      const R = P.regs, sv = s => (s.r !== undefined ? R[s.r] : m16(s.imm)), ea = mo => (mo.base >= 0 ? R[mo.base] : 0) + mo.off;
      let next = P.pc + 1, jumped = false;
      switch (I.op) {
        case "NOP": break;
        case "HALT": P.state = "done"; P.exit = 0; log("kernel", "HALT: treated as exit(0).", 0); freeProcess(P); schedule("exit"); return !M.halted;
        case "MOV": R[I.d] = sv(I.s); break;
        case "ADD": R[I.d] = m16(R[I.d] + sv(I.s)); P.z = R[I.d] === 0; break;
        case "SUB": R[I.d] = m16(R[I.d] - sv(I.s)); P.z = R[I.d] === 0; P.n = (R[I.d] & 0x8000) !== 0; break;
        case "MUL": R[I.d] = m16(R[I.d] * sv(I.s)); P.z = R[I.d] === 0; break;
        case "AND": R[I.d] = R[I.d] & sv(I.s); P.z = R[I.d] === 0; break;
        case "OR": R[I.d] = R[I.d] | sv(I.s); P.z = R[I.d] === 0; break;
        case "XOR": R[I.d] = R[I.d] ^ sv(I.s); P.z = R[I.d] === 0; break;
        case "SHL": R[I.d] = m16(R[I.d] << sv(I.s)); P.z = R[I.d] === 0; break;
        case "SHR": R[I.d] = R[I.d] >>> sv(I.s); P.z = R[I.d] === 0; break;
        case "CMP": { const r = m16(R[I.d] - sv(I.s)); P.z = r === 0; P.n = (r & 0x8000) !== 0; break; }
        case "JMP": next = I.target; jumped = true; break;
        case "JE": case "JZ": if (P.z) { next = I.target; jumped = true; } break;
        case "JNE": case "JNZ": if (!P.z) { next = I.target; jumped = true; } break;
        case "JL": if (P.n) { next = I.target; jumped = true; } break;
        case "JGE": if (!P.n) { next = I.target; jumped = true; } break;
        case "JG": if (!P.n && !P.z) { next = I.target; jumped = true; } break;
        case "JLE": if (P.n || P.z) { next = I.target; jumped = true; } break;
        case "LOAD": R[I.d] = access(P, ea(I.mem), false); break;
        case "STORE": access(P, ea(I.mem), true, sv(I.s)); break;
        case "PUSH": R[7] = m16(R[7] - 1); access(P, R[7] & 255, true, sv(I.s)); break;
        case "POP": R[I.d] = access(P, R[7] & 255, false); R[7] = m16(R[7] + 1); break;
        case "CALL": R[7] = m16(R[7] - 1); access(P, R[7] & 255, true, next); next = I.target; jumped = true; break;
        case "RET": next = access(P, R[7] & 255, false); R[7] = m16(R[7] + 1); jumped = true; break;
        case "SYSCALL": P.pc = next; syscall(P); return !M.halted;
      }
      P.pc = next;
      if (P.state === "running" && P.slice >= M.cfg.quantum && runnable().length > 1) {
        M.stats.irq++; M.mode = "kernel"; charge("kernel", c.irq);
        log("sched", `TIMER INTERRUPT: process ${P.pid} used its time slice (${M.cfg.quantum} instructions). Hardware forces a jump into the kernel.`, c.irq);
        M.mode = "user"; schedule("time slice over");
      }
      return !M.halted;
    };
    M.run = function (n) { let i = 0; while (i < n && M.step()) i++; return i; };
    M.hitRate = (h, m) => (h + m ? h / (h + m) : null);
    return M;
  }
  return { create, assemble, PAGE, VPAGES, FILE_BLOCKS, SYSCALLS, REGS, DEFAULTS, hex };
})();
if (typeof module !== "undefined") module.exports = KVM;
