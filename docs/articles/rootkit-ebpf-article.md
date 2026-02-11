# How I Built a Linux Rootkit Hunter with eBPF and 280 Signatures

> *Draft for HackerNoon / Medium*

---

Traditional rootkit detection tools like rkhunter and chkrootkit haven't fundamentally changed in years. They still primarily rely on file-based signature scanning — checking for known rootkit files on disk. But modern rootkits have evolved far beyond dropping files in `/usr/lib`.

In 2024, I started building [rupurt](https://github.com/bad-antics/rupurt), a rootkit detection tool that combines traditional signatures with eBPF-based behavioral monitoring. Here's what I learned about the state of rootkits in 2026 and how eBPF changes the detection game.

## The Problem with Traditional Detection

Traditional rootkit scanners work by:
1. Comparing system binaries against known-good hashes
2. Checking for files associated with known rootkits
3. Looking for suspicious strings in binaries
4. Verifying system call integrity (basic)

This misses several modern attack types:

**Memory-only rootkits** never touch the filesystem. They inject directly into running processes or kernel memory and persist through techniques like kthread manipulation.

**eBPF rootkits** like TripleCross use the kernel's own eBPF mechanism to hook functions. Since eBPF is a legitimate kernel feature, many scanners don't flag it.

**DKOM (Direct Kernel Object Manipulation)** modifies kernel data structures without hooking any functions. A process can be hidden by unlinking its `task_struct` from the process list.

## Enter eBPF-Based Detection

eBPF (extended Berkeley Packet Filter) lets you run sandboxed programs inside the Linux kernel. Security tools use it for tracing, monitoring, and enforcement. But it's also a double-edged sword — attackers use it too.

rupurt uses eBPF on the defense side. Instead of just scanning files, it monitors kernel behavior in real-time:

### System Call Integrity

We attach eBPF probes to key system calls and verify they haven't been redirected:

```c
SEC("kprobe/sys_getdents64")
int check_getdents(struct pt_regs *ctx) {
    // Verify this syscall comes from the expected kernel address
    // If redirected, it may indicate a rootkit hook
    u64 ip = PT_REGS_IP(ctx);
    if (!is_valid_kernel_text(ip)) {
        report_syscall_hook("getdents64", ip);
    }
    return 0;
}
```

### Hidden Process Detection

By comparing `/proc` enumeration results with what the kernel's `task_struct` list actually contains, we can find processes that have been hidden from userspace:

```c
SEC("tp/sched/sched_process_fork")
int detect_hidden_fork(struct trace_event_raw_sched_process_fork *ctx) {
    u32 child_pid = ctx->child_pid;
    // Record every fork — later compare against /proc listing
    bpf_map_update_elem(&known_pids, &child_pid, &one, BPF_ANY);
    return 0;
}
```

### eBPF Program Enumeration

The ironic twist: we use eBPF to detect malicious eBPF. rupurt enumerates all loaded eBPF programs and compares them against an allowlist:

```c
// Userspace enumeration
while (bpf_prog_get_next_id(id, &id) == 0) {
    fd = bpf_prog_get_fd_by_id(id);
    bpf_obj_get_info_by_fd(fd, &info, sizeof(info));
    
    if (info.type == BPF_PROG_TYPE_KPROBE && !is_allowlisted(&info)) {
        alert("Suspicious eBPF kprobe: %s (id=%d)", info.name, id);
    }
}
```

## The Signature Database

Behavioral detection catches novel threats, but you still need signatures for known ones. rupurt ships with 280+ signatures covering:

| Category | Count | Example |
|----------|-------|---------|
| LKM rootkits | 45 | Diamorphine, Reptile, Kovid |
| eBPF rootkits | 20 | TripleCross, pamspy, ebpfkit |
| Userland rootkits | 35 | Azazel, Jynx2, Vlany |
| APT implants | 40 | Drovorub (GRU), Winnti |
| Backdoors | 50+ | Turla, cd00r, Prism |
| Generic patterns | 90+ | Behavioral indicators |

Signatures are community-contributed JSON files. Adding your own is as simple as:

```json
{
    "name": "my_rootkit",
    "type": "lkm",
    "indicators": {
        "files": ["/lib/modules/*/kernel/drivers/my_rootkit.ko"],
        "strings": ["my_rootkit_hide", "my_rootkit_hook"],
        "kernel_symbols": ["my_rootkit_init"]
    }
}
```

## Results and Lessons

After testing rupurt against 15 known rootkits in controlled environments:

- **Traditional scanning** (file + string matching) caught 11/15
- **eBPF behavioral detection** caught 14/15
- **Combined approach** caught 15/15

The one rootkit that evaded behavioral detection used a novel eBPF technique we hadn't seen before — which led to a new detection module.

## Key Takeaways

1. **File-based detection is necessary but insufficient.** You still need signatures for known threats.
2. **eBPF is the most powerful tool for kernel-level monitoring** — on both offense and defense.
3. **The detection-evasion arms race never ends.** Every detection technique has a bypass. Defense in depth is the only real strategy.
4. **Open-source detection tools matter.** The security community benefits when detection logic is transparent and auditable.

rupurt is open source: [github.com/bad-antics/rupurt](https://github.com/bad-antics/rupurt)

---

*About the author: I'm a security researcher who builds open-source security tools. 680+ projects on [GitHub](https://github.com/bad-antics).*
