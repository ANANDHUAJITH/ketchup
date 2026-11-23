/* Example programs for the KetchupVM simulator. Each one demonstrates one OS/architecture idea. */
const KVM_SAMPLES = [
{ id: "hello", title: "1. Hello, kernel (syscall + demand paging)", settings: {},
  note: "The text lives on disk and is paged into RAM the first time it is touched. write() is a system call: watch the mode badge flip USER → KERNEL → USER.",
  procs: [{ name: "hello", src: `; Hello, kernel!
.string 0x20 "Hello, kernel!\\n"
MOV R0, 1        ; syscall number 1 = write
MOV R1, 0x20     ; pointer to the text (a VIRTUAL address)
MOV R2, 15       ; length
SYSCALL          ; trap into the kernel
MOV R0, 2        ; syscall 2 = exit
MOV R1, 0
SYSCALL` }] },
{ id: "seq", title: "2. Sequential sum (cache + TLB love locality)", settings: {},
  note: "32 consecutive bytes: every 4th load misses the cache (one 4-byte line is fetched), the other 3 hit. The TLB misses only once per page. Expected R2 = 528.",
  procs: [{ name: "sum", src: `; sum 32 bytes stored at 0x20
.data 0x20 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32
MOV R1, 0x20     ; pointer
MOV R2, 0        ; sum
MOV R3, 32       ; count
loop:
LOAD R4, [R1]
ADD R2, R4
ADD R1, 1
SUB R3, 1
JNZ loop
STORE [0x10], R2 ; save the low byte of the result
HALT` }] },
{ id: "stride", title: "3. Stride 16 (cache conflict misses)", settings: {},
  note: "Same few loads, but each lands in a different page at the same offset, so they all map to the SAME cache line and evict each other. Change STEP to 1 and run again: hit rate jumps.",
  procs: [{ name: "stride", src: `.equ STEP 16
MOV R3, 8        ; rounds
round:
MOV R1, 0
MOV R2, 4
inner:
LOAD R4, [R1]
ADD R1, STEP
SUB R2, 1
JNZ inner
SUB R3, 1
JNZ round
HALT` }] },
{ id: "thrash", title: "4. Thrashing (more pages than RAM frames)", settings: { frames: 8 },
  note: "12 pages are touched in a loop but RAM has 8 frames. With LRU every access evicts the page needed next: a page fault (and ~2000-cycle disk read) per access. Raise frames to 16 and rerun.",
  procs: [{ name: "thrash", src: `MOV R3, 3        ; rounds
round:
MOV R1, 0
MOV R2, 12       ; 12 pages
loop:
LOAD R4, [R1]
ADD R1, 16       ; next page
SUB R2, 1
JNZ loop
SUB R3, 1
JNZ round
HALT` }] },
{ id: "procs", title: "5. Two processes (timer interrupt + context switch)", settings: { quantum: 12 },
  note: "Two programs share one CPU. A timer interrupt ends each time slice; the kernel saves/restores registers and flushes the TLB. Each process has its own page table: same virtual address 0x20, different RAM frame.",
  procs: [
   { name: "A", src: `.data 0x20 65
MOV R3, 8
loop:
MOV R0, 1
MOV R1, 0x20
MOV R2, 1
SYSCALL
SUB R3, 1
JNZ loop
MOV R0, 2
MOV R1, 0
SYSCALL` },
   { name: "B", src: `.data 0x20 66
MOV R3, 8
loop:
MOV R0, 1
MOV R1, 0x20
MOV R2, 1
SYSCALL
SUB R3, 1
JNZ loop
MOV R0, 2
MOV R1, 0
SYSCALL` }] },
{ id: "pagecache", title: "6. Reading a file twice (the page cache)", settings: {},
  note: "The first read_file() of block 3 goes to the disk (~2000 cycles); the second is served from the kernel's page cache in RAM (~25 cycles).",
  procs: [{ name: "reader", src: `MOV R0, 4        ; syscall 4 = read_file
MOV R1, 3        ; file block 3
MOV R2, 0x40     ; destination buffer
SYSCALL          ; MISS: disk read
MOV R0, 4
MOV R1, 3
MOV R2, 0x50
SYSCALL          ; HIT: page cache
MOV R0, 1        ; print what we read
MOV R1, 0x50
MOV R2, 16
SYSCALL
HALT` }] },
{ id: "stack", title: "7. Function calls and the stack", settings: {},
  note: "CALL pushes the return address into memory at the top of the address space (page 15), RET pops it. The very first PUSH faults in a brand-new stack page. Expected R1 = 20.",
  procs: [{ name: "calls", src: `MOV R1, 5
CALL double
CALL double
HALT
double:
ADD R1, R1
RET` }] },
];
if (typeof module !== "undefined") module.exports = KVM_SAMPLES;
