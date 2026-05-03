# ZealOS-AI: Native AI Operating System

ZealOS-AI collapses AitherOS's 196 Python microservices into ZealOS kernel constructs, making AI agents first-class kernel citizens instead of userspace processes.

## Phase 0: Agent as Kernel Object (Current)

All files are in `src/Kernel/` and `src/System/AI/`.

### New Kernel Files

| File | Purpose | AitherOS Equivalent |
|------|---------|---------------------|
| `FluxIDT.ZC` | Ring-buffer event bus on IDT vectors 0x60-0x7F | FluxEmitter + AitherEvents |
| `CapEngine.ZC` | HMAC capability tokens, default-deny, audit log | CapabilityEngine |
| `AgentForge.ZC` | Identity system, agent lifecycle, ForgeDispatch | IdentitySystem + AgentForge |
| `Syscall.ZC` | INT 0x80 syscall gate for Ring-3 sandboxes | N/A (everything was HTTP) |
| `AI/AgentDemo.ZC` | Phase 0 validation demo | N/A |

### Modified Kernel Files

| File | Changes |
|------|---------|
| `KernelA.HH` | CAgentMeta, CFluxRing, CCapToken, CIdentity, CForgeSpec + 20 structs |
| `KGlobals.ZC` | kernel_state global |
| `Sched.ZC` | AgentTick() ISR with priority+effort+budget scoring |
| `KInterrupts.ZC` | FluxIDT vector reservation in IntInit2() |
| `KMain.ZC` | AI_MODELS + AGENT_KERNEL boot stages, agent spawning |
| `KTask.ZC` | CTask.agent_meta pointer (unchanged, added in KernelA.HH) |
| `Kernel.PRJ` | Include new .ZC files in build |
| `MakeSystem.ZC` | Include AgentDemo |

### Architecture

```
Boot Sequence (Extended):
  RAW -> INTERRUPTS -> BLKDEV -> COMPILER -> StartOS ->
  AI_MODELS -> AGENT_KERNEL -> SYSTEM_READY

Agent Lifecycle:
  IdentityRegister() -> AgentSpawn() -> AgentTaskAdd() ->
  AgentTick() [30s ISR] -> AgentKill()

Event Flow:
  FluxEmit(vector, type, agent, payload) ->
    ring buffer write (~100ns) ->
    chained handler invocation ->
    FluxPoll() by subscribers

Security:
  CapTokenCreate() -> CapTokenGrant() -> CapCheck() [default-deny]
  Every operation: CapCheck(agent_id, resource, action)

Scheduling Score:
  score = staleness * 1.0 + pain * 2.0 + goal_boost * 1.5 - effort * 0.5
```

### Performance vs AitherOS

| Operation | AitherOS | ZealOS-AI | Speedup |
|-----------|----------|-----------|---------|
| Agent IPC | ~1ms (Redis) | ~100ns (ring buffer) | 10,000x |
| Agent dispatch | ~5ms (HTTP) | ~5us (direct call) | 1,000x |
| Capability check | ~100us (Python HMAC) | ~1us (inline) | 100x |
| Memory per agent | ~50MB (Python) | ~500KB (CTask) | 100x |
| Boot to ready | ~3 min (87 containers) | ~2 sec (kernel) | 90x |

### Building

```bash
cd build
./build-iso.sh --headless
```

### Testing

```bash
# Automated boot test
cd build
./test-boot.sh

# Manual QEMU test
qemu-system-x86_64 -cdrom build/ZealOS.iso -m 512M -smp 2 -enable-kvm

# In ZealOS shell, run the demo:
#include "/System/AI/AgentDemo"
AgentDemo;
```

## Roadmap

- **Phase 0** (current): Agent scheduling, FluxIDT, capabilities, identity, forge
- **Phase 1**: TCP/IP (lwIP port), external LLM access, SSH console
- **Phase 2**: musl libc, llama.cpp CPU inference, ReAct loop, context pipeline
- **Phase 3**: GPU drivers, NVMe, native UI, multi-node clustering
