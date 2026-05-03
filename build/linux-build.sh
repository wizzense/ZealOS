#!/bin/bash
set -e

# Build from a clean Linux clone to avoid Windows encoding issues
CLONE="/tmp/ZealOS-AI"
WINSRC="/mnt/d/AitherOS-Fresh/ZealOS-AI/src"

if [ ! -d "$CLONE" ]; then
    echo "ERROR: Clone not found at $CLONE"
    exit 1
fi

cd "$CLONE"

# Copy our modified/new kernel files
cp "$WINSRC/Kernel/FluxIDT.ZC"    src/Kernel/
cp "$WINSRC/Kernel/CapEngine.ZC"  src/Kernel/
cp "$WINSRC/Kernel/AgentForge.ZC" src/Kernel/
cp "$WINSRC/Kernel/InferQueue.ZC" src/Kernel/
cp "$WINSRC/Kernel/Syscall.ZC"    src/Kernel/

cp "$WINSRC/Kernel/KernelA.HH"     src/Kernel/
cp "$WINSRC/Kernel/KGlobals.ZC"    src/Kernel/
cp "$WINSRC/Kernel/Sched.ZC"       src/Kernel/
cp "$WINSRC/Kernel/KInterrupts.ZC" src/Kernel/
cp "$WINSRC/Kernel/KMain.ZC"       src/Kernel/
cp "$WINSRC/Kernel/Kernel.PRJ"     src/Kernel/

mkdir -p src/System/AI
cp "$WINSRC/System/AI/AgentDemo.ZC" src/System/AI/
cp "$WINSRC/System/MakeSystem.ZC"   src/System/

echo "Files copied into clean clone"
echo "Building..."

cd build
dos2unix build-iso.sh 2>/dev/null || true
bash ./build-iso.sh --headless 2>&1
