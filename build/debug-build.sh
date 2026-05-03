#!/bin/bash
set -e
cd "$(dirname "$0")"

WORK="$(mktemp -d)"
DISK="$WORK/ZealOS.raw"
MNT="$WORK/mnt"
mkdir -p "$MNT"

KVM=""
test -e /dev/kvm && KVM="-accel kvm"

cleanup() {
    umount "$MNT" 2>/dev/null || true
    qemu-nbd -d /dev/nbd0 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

echo "=== Step 1: Auto-install ==="
qemu-img create -f raw "$DISK" 1024M
timeout 120 qemu-system-x86_64 -machine q35 $KVM \
    -drive format=raw,file="$DISK" -m 1G -rtc base=localtime -smp 4 \
    -cdrom AUTO.ISO -device isa-debug-exit -display none 2>&1 || true

echo "=== Step 2: Copy ONLY modified/new files ==="
modprobe nbd 2>/dev/null || true
qemu-nbd -c /dev/nbd0 -f raw "$DISK"
sleep 2
mount /dev/nbd0p1 "$MNT"

# The auto-install already put a full working src tree at /Tmp/OSBuild/
# We only overlay our changed files to avoid encoding corruption from git/Windows
DEST="$MNT/Tmp/OSBuild"
mkdir -p "$DEST/Kernel" "$DEST/System/AI"

# New AI kernel files
cp ../src/Kernel/FluxIDT.ZC    "$DEST/Kernel/"
cp ../src/Kernel/CapEngine.ZC  "$DEST/Kernel/"
cp ../src/Kernel/AgentForge.ZC "$DEST/Kernel/"
cp ../src/Kernel/InferQueue.ZC "$DEST/Kernel/"
cp ../src/Kernel/Syscall.ZC    "$DEST/Kernel/"

# Modified kernel files
cp ../src/Kernel/KernelA.HH      "$DEST/Kernel/"
cp ../src/Kernel/KGlobals.ZC     "$DEST/Kernel/"
cp ../src/Kernel/Sched.ZC        "$DEST/Kernel/"
cp ../src/Kernel/KInterrupts.ZC  "$DEST/Kernel/"
cp ../src/Kernel/KMain.ZC        "$DEST/Kernel/"
cp ../src/Kernel/Kernel.PRJ      "$DEST/Kernel/"

# New System/AI
cp ../src/System/AI/AgentDemo.ZC "$DEST/System/AI/"
cp ../src/System/MakeSystem.ZC   "$DEST/System/"

sync
umount "$MNT"
qemu-nbd -d /dev/nbd0

echo "=== Step 3: Rebuild (VNC :1, screendump after 90s) ==="
qemu-system-x86_64 -machine q35 $KVM \
    -drive format=raw,file="$DISK" -m 1G -rtc base=localtime -smp 4 \
    -device isa-debug-exit -display none \
    -vnc :1 \
    -monitor unix:"$WORK/mon.sock",server,nowait &
QPID=$!

sleep 90
echo "screendump $WORK/screen.ppm" | socat - UNIX-CONNECT:"$WORK/mon.sock" 2>/dev/null || true
sleep 2
kill $QPID 2>/dev/null; wait $QPID 2>/dev/null || true

if [ -f "$WORK/screen.ppm" ]; then
    cp "$WORK/screen.ppm" ./zealos_screen.ppm
    convert ./zealos_screen.ppm -resize 50% ./zealos_screen.png 2>/dev/null || true
    echo "Screenshot saved"
else
    echo "No screenshot"
fi
echo "=== DONE ==="
