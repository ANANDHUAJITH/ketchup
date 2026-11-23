# Ketchup study guide: networking and operating-system internals

Ketchup ships the tools to *see* what the machine is doing. Work through a lab, then read about it.
Everything here runs offline. Start with `ketchup-lab list`, `ketchup-devtools list`, `ketchup-doctor`.

## Track 1: networking from the wire up

Tools on the ISO: `ip`, `ss`, `tcpdump`, `tshark` (wireshark-cli), `nmap`, `mtr`, `traceroute`, `dig`, `iperf3`, `socat`, `nc`, `nft`, `conntrack`, `ethtool`.

1. **Lab topology.** `ketchup-lab net up` builds three namespaces (a, r, b) joined by a router.
   - `sudo ip netns exec ketchup-a ping -c2 10.10.2.2` crosses the router.
   - In a second terminal: `sudo ip netns exec ketchup-r tcpdump -ni veth-ra` and watch Ethernet, ARP, IP, ICMP.
2. **Layer 2/3.** `ip neigh` (ARP cache), `ip route`, `ip -s link`. Delete a route in `a` and predict the failure before you ping.
3. **Forwarding.** Turn `net.ipv4.ip_forward` off in `r`. Why does ping now fail, and where does the packet die (`tcpdump` on each side)?
4. **TCP.** `nc -l 9000` in `b`, `nc 10.10.2.2 9000` in `a`; capture the three-way handshake and FIN exchange (`tcpdump -nn -S 'tcp port 9000'`). Drop a packet with nftables and watch retransmissions.
5. **NAT and firewall.** In `r`: `nft add table ip nat; nft 'add chain ip nat post { type nat hook postrouting priority 100; }'; nft add rule ip nat post oifname veth-rb masquerade`. Then block a port with a filter chain.
6. **DNS.** `dig +trace example.com`; compare with `resolvectl query`. Read `/etc/resolv.conf` and `/etc/nsswitch.conf`: who answers first?
7. **Performance.** `iperf3 -s` in `b`, `iperf3 -c 10.10.2.2` in `a`. Change MTU on one link (`ip link set dev veth-ra mtu 600`) and watch fragmentation/PMTU.
8. **Next:** bridges and VLANs (`ip link add br0 type bridge`), WireGuard, `ss -tin` TCP internals (cwnd, rtt), `bpftrace -e 'tracepoint:tcp:tcp_retransmit_skb { @[comm] = count(); }'`.

## Track 2: operating-system fundamentals

1. **Boot path.** Firmware (BIOS/UEFI) -> bootloader -> kernel -> initramfs -> `systemd`.
   - `ketchup-lab boot new demo`, `make run`: your own 512-byte boot sector in QEMU. `make debug` single-steps it with gdb.
   - Read `/proc/cmdline`, `systemd-analyze critical-chain`, `lsinitcpio /boot/initramfs-linux-zen.img | less`.
2. **System calls.** `ketchup-lab syscalls new demo`; run `strace -f ./main`, then `strace -c ls /` and `strace -e openat cat /etc/hostname`. Everything a program does to the world is a syscall.
3. **Processes.** `ps -eo pid,ppid,stat,comm --forest`, `/proc/self/{maps,status,fd}`, `pstree -p`. Write a C program that `fork()`s and `exec()`s; watch with `strace -f`.
4. **Memory.** `/proc/meminfo`, `pmap -x PID`, `vmstat 1`, `perf stat -e page-faults,minor-faults ./prog`. Compare RSS vs virtual size; trigger OOM in a cgroup with `systemd-run -p MemoryMax=100M`.
5. **Scheduling.** `chrt`, `nice`, `taskset`; `perf sched record/latency`; the `scx` schedulers (`/sys/kernel/sched_ext`).
6. **Filesystems.** `stat`, `debugfs`, `btrfs filesystem usage /`, `filefrag -v`. Create a loop device with ext4 and look at inodes and journals.
7. **Namespaces and cgroups** (what containers are). `unshare -Urmpf --mount-proc bash`, `lsns`, `systemd-cgls`, `cat /sys/fs/cgroup/...`. Then `distrobox create` and inspect it from outside.
8. **Kernel modules.** `ketchup-lab kmod new hello`, `make`, `insmod`, `dmesg`. Next: a char device, `/proc` entry, a timer.
9. **eBPF tracing.** `bpftrace -e 'tracepoint:syscalls:sys_enter_openat { printf("%s %s\n", comm, str(args->filename)); }'`, `perf top`, `perf record -g`.

## Track 3: watch it happen (Ketchup Lens)

Reading about page faults is not the same as seeing one. Two tools, one real, one a toy:

**A. `ketchup-lens trace -- ./program`** runs *your* program under strace, perf, gdb and a /proc sampler and writes an interactive report
(`~/ketchup-lens/*.html`): the Story timeline (exec, dynamic loader, main, exit), every system call with an explanation, the address space at three
moments, registers at the syscall boundary, CPU counters, your real cache sizes, and disk vs page-cache I/O. `ketchup-lens samples` builds small programs:

| Run | What to look for |
|---|---|
| `ketchup-lens trace -- ./hello` | the whole life of a 1-line program: ~30 syscalls before and after `main`, what `write()` looks like in registers (`rax=1, rdi=1`) |
| `ketchup-lens trace -- ./touch_pages 200` | `malloc` costs no RAM; RSS and minor page faults climb as pages are *touched* (faults x 4 KiB = RSS) |
| `ketchup-lens trace -- ./readfile /usr/lib/libc.so.6` twice | first run reads from the device, second from the page cache (Disk tab) |
| `ketchup-lens trace -- ./fork_exec` | clone(), execve(), wait4(): process creation; the child's own loader phase |
| `ketchup-lens trace -- ./busy_loop` vs `./readfile` | IPC high vs low; voluntary vs involuntary context switches |
| `ketchup-lens latency` then any trace | the latency curve steps at your L1/L2/L3 sizes; RAM is ~100x slower than L1 |

**B. `ketchup-lens sim`** opens KetchupVM: a tiny computer with registers, a page table, a 4-entry TLB, a 4-line L1 cache, 8 RAM frames, a disk and a
kernel. Single-step and read the "what every layer did" panel after each instruction. Seven programs, each one idea:
hello (syscall, mode switch, demand paging), sequential sum (cache + TLB locality), stride 16 (conflict misses; change `STEP` to 1),
thrashing (12 pages, 8 frames; set frames to 16), two processes (timer interrupt, context switch, TLB flush), page cache, and the call stack.
Exercises: predict the hit rate before you run; make the thrash sample fast without adding frames (hint: change the access order); write a program
that triggers a *dirty* eviction and find the disk write in the log; compare FIFO and LRU on the thrash sample (identical for a pure cyclic scan: why?) and then on a back-and-forth access pattern.

The simulator is simplified on purpose (one-level page table, 16-byte pages, no instruction fetch from RAM). The real machine differs in size,
not in kind: 4 levels of page tables, 4 KiB pages, 64-byte cache lines, instruction caches, prefetchers, and many cores.

## Reading list
- *Operating Systems: Three Easy Pieces* (Arpaci-Dusseau), free online.
- *The Linux Programming Interface* (Kerrisk) and `man 2 <syscall>` (`man-pages` is installed).
- *TCP/IP Illustrated, Vol. 1* (Stevens/Fall); *Computer Networking: A Top-Down Approach* (Kurose/Ross).
- *Linux Kernel Development* (Love); the xv6 teaching kernel (MIT 6.S081).
- *Systems Performance* (Gregg) for perf and eBPF.
- *Operating Systems: Three Easy Pieces* (free online) pairs well with Track 3: virtualization (CPU, memory), concurrency, persistence.
- *Computer Systems: A Programmer's Perspective* (CS:APP): caches, linking and virtual memory from the programmer's side.

More toolchains on demand: `ketchup-devtools install c rust go python net os kernel`.
