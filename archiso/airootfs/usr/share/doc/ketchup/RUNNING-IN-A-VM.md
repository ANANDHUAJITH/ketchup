# Running Ketchup in a virtual machine

niri needs an OpenGL-capable GPU device. It has no software-rendering fallback, so a VM whose
display is a plain 2D framebuffer reaches the login screen at best and then drops back to a
console after login. The greeter has a software fallback, which is why it can still appear.

Give the VM a virtio GPU with 3D acceleration (virgl). Choosing "virtio" without 3D is not
enough. `ketchup-doctor` reports whether a GPU render node exists.

## QEMU

```sh
qemu-system-x86_64 \
  -enable-kvm -m 4G -smp 4 -machine q35 -cpu host \
  -device virtio-vga-gl -display sdl,gl=on \
  -device virtio-net-pci,netdev=n0 -netdev user,id=n0 \
  -drive file=ketchup.iso,media=cdrom -boot d
```

Use `-display gtk,gl=on` if QEMU has no SDL UI. For UEFI add OVMF:

```sh
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=OVMF_VARS.4m.fd
```

The paths differ between distributions; look for `OVMF_CODE*.fd` under `/usr/share/edk2` or
`/usr/share/OVMF`. `OVMF_VARS` must be a writable copy.

## libvirt / virt-manager

Set the video model to **Virtio** and tick **3D acceleration**. The XML is
`<model type='virtio'><acceleration accel3d='yes'/></model>`. Spice or VNC both work.

## VirtualBox and VMware

Turn on 3D acceleration in the display settings and give the VM at least 128 MB of video
memory.

## Things that do not work

- Plain `-vga std`, `qxl` or `virtio` without GL.
- The "safe graphics (nomodeset)" boot entry: `nomodeset` disables the kernel driver niri
  needs.
- A host without any working OpenGL. virgl uses the host's GL stack; a software one such as
  llvmpipe is fine.

## Persistence in a VM

`ketchup-persist` works on a virtual disk too, as long as the ISO is attached as a disk
(`-drive file=ketchup.iso,format=raw` enlarged with `truncate -s 8G ketchup.iso`) and not as a
CD-ROM.
