# Ketup study guide: networking and operating-system internals

Ketup ships the tools to *see* what the machine is doing. Work through a lab, then read about it.
Everything here runs offline. Start with `ketup-lab list`, `ketup-devtools list`, `ketup-doctor`.

## Track 1: networking from the wire up

Tools on the ISO: `ip`, `ss`, `tcpdump`, `tshark` (wireshark-cli), `nmap`, `mtr`, `traceroute`, `dig`, `iperf3`, `socat`, `nc`, `nft`, `conntrack`, `ethtool`.

1. **Lab topology.** `ketup-lab net up` builds three namespaces (a, r, b) joined by a router.
   - `sudo ip netns exec ketup-a ping -c2 10.10.2.2` crosses the router.
   - In a second terminal: `sudo ip netns exec ketup-r tcpdump -ni veth-ra` and watch Ethernet, ARP, IP, ICMP.
2. **Layer 2/3.** `ip neigh` (ARP cache), `ip route`, `ip -s link`. Delete a route in `a` and predict the failure before you ping.
3. **Forwarding.** Turn `net.ipv4.ip_forward` off in `r`. Why does ping now fail, and where does the packet die (`tcpdump` on each side)?
4. **TCP.** `nc -l 9000` in `b`, `nc 10.10.2.2 9000` in `a`; capture the three-way handshake and FIN exchange (`tcpdump -nn -S 'tcp port 9000'`). Drop a packet with nftables and watch retransmissions.
5. **NAT and firewall.** In `r`: `nft add table ip nat; nft 'add chain ip nat post { type nat hook postrouting priority 100; }'; nft add rule ip nat post oifname veth-rb masquerade`. Then block a port with a filter chain.
6. **DNS.** `dig +trace example.com`; compare with `resolvectl query`. Read `/etc/resolv.conf` and `/etc/nsswitch.conf`: who answers first?
7. **Performance.** `iperf3 -s` in `b`, `iperf3 -c 10.10.2.2` in `a`. Change MTU on one link (`ip link set dev veth-ra mtu 600`) and watch fragmentation/PMTU.
8. **Next:** bridges and VLANs (`ip link add br0 type bridge`), WireGuard, `ss -tin` TCP internals (cwnd, rtt), `bpftrace -e 'tracepoint:tcp:tcp_retransmit_skb { @[comm] = count(); }'`.

## Track 2: operating-system fundamentals

1. **Boot path.** Firmware (BIOS/UEFI) -> bootloader -> kernel -> initramfs -> `systemd`.
   - `ketup-lab boot new demo`, `make run`: your own 512-byte boot sector in QEMU. `make debug` single-steps it with gdb.
   - Read `/proc/cmdline`, `systemd-analyze critical-chain`, `lsinitcpio /boot/initramfs-linux-zen.img | less`.
2. **System calls.** `ketup-lab syscalls new demo`; run `strace -f ./main`, then `strace -c ls /` and `strace -e openat cat /etc/hostname`. Everything a program does to the world is a syscall.
3. **Processes.** `ps -eo pid,ppid,stat,comm --forest`, `/proc/self/{maps,status,fd}`, `pstree -p`. Write a C program that `fork()`s and `exec()`s; watch with `strace -f`.
4. **Memory.** `/proc/meminfo`, `pmap -x PID`, `vmstat 1`, `perf stat -e page-faults,minor-faults ./prog`. Compare RSS vs virtual size; trigger OOM in a cgroup with `systemd-run -p MemoryMax=100M`.
5. **Scheduling.** `chrt`, `nice`, `taskset`; `perf sched record/latency`; the `scx` schedulers (`/sys/kernel/sched_ext`).
6. **Filesystems.** `stat`, `debugfs`, `btrfs filesystem usage /`, `filefrag -v`. Create a loop device with ext4 and look at inodes and journals.
7. **Namespaces and cgroups** (what containers are). `unshare -Urmpf --mount-proc bash`, `lsns`, `systemd-cgls`, `cat /sys/fs/cgroup/...`. Then `distrobox create` and inspect it from outside.
8. **Kernel modules.** `ketup-lab kmod new hello`, `make`, `insmod`, `dmesg`. Next: a char device, `/proc` entry, a timer.
9. **eBPF tracing.** `bpftrace -e 'tracepoint:syscalls:sys_enter_openat { printf("%s %s\n", comm, str(args->filename)); }'`, `perf top`, `perf record -g`.

## Reading list
- *Operating Systems: Three Easy Pieces* (Arpaci-Dusseau), free online.
- *The Linux Programming Interface* (Kerrisk) and `man 2 <syscall>` (`man-pages` is installed).
- *TCP/IP Illustrated, Vol. 1* (Stevens/Fall); *Computer Networking: A Top-Down Approach* (Kurose/Ross).
- *Linux Kernel Development* (Love); the xv6 teaching kernel (MIT 6.S081).
- *Systems Performance* (Gregg) for perf and eBPF.

More toolchains on demand: `ketup-devtools install c rust go python net os kernel`.
