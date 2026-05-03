#!/bin/bash
# ZealOS-AI QEMU Boot Test Harness
# Boots the ISO in QEMU and validates AI kernel initialization via serial output.
#
# Usage: ./test-boot.sh [path-to-iso]
# Exit codes: 0=pass, 1=fail

set -e

ISO="${1:-$(find . -name '*.iso' | head -1)}"

if [ -z "$ISO" ] || [ ! -f "$ISO" ]; then
    echo "ERROR: No ISO found. Build first with ./build-iso.sh"
    exit 1
fi

echo "=== ZealOS-AI Boot Test ==="
echo "ISO: $ISO"

LOGFILE=$(mktemp /tmp/zealos-ai-boot-XXXXXX.log)
TIMEOUT_SEC=${BOOT_TIMEOUT:-90}

# Detect KVM availability
KVM_FLAG=""
if [ -e /dev/kvm ]; then
    KVM_FLAG="-enable-kvm"
    echo "KVM: enabled"
else
    echo "KVM: not available (slower emulation)"
fi

echo "Timeout: ${TIMEOUT_SEC}s"
echo "Log: $LOGFILE"
echo ""

# Boot QEMU with serial console
timeout "$TIMEOUT_SEC" qemu-system-x86_64 \
    -cdrom "$ISO" \
    -m 512M \
    -smp 2 \
    -nographic \
    -serial stdio \
    -no-reboot \
    $KVM_FLAG 2>&1 | tee "$LOGFILE" || true

echo ""
echo "=== Boot Test Results ==="

PASS=0
FAIL=0

check() {
    local label="$1"
    local pattern="$2"
    if grep -q "$pattern" "$LOGFILE" 2>/dev/null; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (pattern: '$pattern' not found)"
        FAIL=$((FAIL + 1))
    fi
}

# Phase 0 validation checks
check "Kernel boots"              "ZealOS"
check "Timer initialized"        "TimerInit"
check "Interrupts initialized"   "IntInit2"
check "Compiler loaded"          "Load(\"Compiler\")"
check "FluxIDT initialized"      "AIInit: FluxIDT"
check "CapEngine initialized"    "AIInit: CapEngine"
check "Syscall gate registered"  "AIInit: Syscall"
check "Identities loaded"        "AIInit: Identities"
check "Agents spawned"           "AIInit: Spawning agents"
check "System ready"             "SYSTEM_READY"

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""

rm -f "$LOGFILE"

if [ "$FAIL" -gt 0 ]; then
    echo "OVERALL: FAIL"
    exit 1
fi

echo "OVERALL: PASS"
exit 0
