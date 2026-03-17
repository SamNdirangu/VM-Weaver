# VM Weaver

> **Upload · Convert · Serve · Write VM disk images — all from one tool.**

VM Weaver is a terminal-based utility for Linux (Ubuntu 20.04+) that handles the full lifecycle of VM disk image management: upload files to a server via SFTP/SCP/rsync, convert between formats (VMDK, QCOW2, VHD, VDI, RAW, and more), serve them for download over HTTP, or write them directly to a physical disk — no manual `dd` needed.

```
  ╔══╡ VM WEAVER ╞═══════════════════════════════════════════════════════════╗
  ║ ██╗   ██╗███╗   ███╗  ██╗    ██╗███████╗ █████╗ ██╗   ██╗███████╗██████╗ ║
  ║ ██║   ██║████╗ ████║  ██║    ██║██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗║
  ║ ██║   ██║██╔████╔██║  ██║ █╗ ██║█████╗  ███████║██║   ██║█████╗  ██████╔╝║
  ║ ╚██╗ ██╔╝██║╚██╔╝██║  ██║███╗██║██╔══╝  ██╔══██║╚██╗ ██╔╝██╔══╝  ██╔══██╗║
  ║  ╚████╔╝ ██║ ╚═╝ ██║  ╚███╔███╔╝███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║║
  ║   ╚═══╝  ╚═╝     ╚═╝   ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝║
  ╠══════════════════════════════════════════════════════════════════════════╣
  ║  ·.·´¯·.¸¸.·´¯·.¸  ~~ W · E · A · V · E · R ~~  ¸.·´¯·.·´¯·.¸¸.·´¯·                 ║
  ║     Upload · Convert · Serve · Write VM Disk Images                      ║
  ╚══════════════════════════════════════════════════════════════════════════╝
```

---

## Features

| Feature | Description |
|---|---|
| **Format conversion** | VMDK ↔ QCOW2 ↔ VHD ↔ VDI ↔ RAW ↔ QED via `qemu-img` |
| **RAW size control** | Choose full, sparse (thin-provisioned), or trimmed output to save disk space |
| **Write to disk** | Convert and write directly to a physical disk — replaces manual `dd` workflows |
| **HTTP server** | Serve converted images for download over the network in one click |
| **Upload guide** | Built-in instructions for SFTP, SCP, rsync, and WinSCP |
| **Global install** | Registers `vm-weaver` in `/usr/local/bin` so you can run it from any directory |
| **Dependency installer** | One-command setup installs all required packages |

---

## Requirements

- Ubuntu 20.04 or later (Debian-based)
- `bash` 4.0+
- `sudo` access (for package installation and disk writes)

---

## Installation

### Quick install (one command)

```bash
git clone https://github.com/SamNdirangu/vm-weaver.git
cd vm-weaver
sudo bash scripts/vm_weaver.sh --install
```

This will:
1. Install all required packages (`qemu-utils`, `openssh-server`, `python3`, `rsync`, `pv`, etc.)
2. Create the `~/vm_disks` working directory
3. Register `vm-weaver` in `/usr/local/bin` so you can call it from anywhere

### Manual install (no git)

```bash
curl -O https://raw.githubusercontent.com/SamNdirangu/vm-weaver/main/scripts/vm_weaver.sh
chmod +x vm_weaver.sh
sudo ./vm_weaver.sh --install
```

---

## Usage

### Interactive menu

```bash
vm-weaver
```

Launches a full interactive terminal menu with all options.

### Command-line flags

```
vm-weaver [option]

  --install,  -i    First-time setup: install deps & register globally
  --check,    -c    Check qemu-img version and supported formats
  --serve,    -s    Start HTTP download server immediately
  --write,    -w    Write a disk image to a physical disk
  --convert,  -C    Convert a disk image (interactive)
  --help,     -h    Show help
```

---

## Workflow examples

### Convert a VMDK to QCOW2 for KVM

```bash
vm-weaver --convert
# Follow prompts: select source → select qcow2 → optionally enable compression
```

### Convert to RAW and save space

When converting to RAW, VM Weaver offers three options:

| Option | Description |
|---|---|
| **Full raw** | Exact byte-for-byte copy. Maximum compatibility. |
| **Sparse (thin)** | Skips empty/zero blocks. Same logical size, smaller on disk. |
| **Trim to used data** | Truncates the file to the last used byte. Smallest possible output. |

RAW images without any trimming can be as large as the virtual disk size (e.g. a 100 GB VM = 100 GB RAW file). Using sparse or trim can reduce this dramatically for VMs that aren't fully utilized.

### Write an image directly to a physical disk

```bash
vm-weaver --write
```

Or from within the menu (option 4), or automatically after a conversion.

VM Weaver will:
1. List all available physical disks with sizes and model names
2. Flag your system/boot disk with a `[SYSTEM DISK!]` warning
3. Require you to type `YES` to confirm before writing
4. Unmount any mounted partitions on the target disk
5. Write the image using `dd` with a live progress bar (`pv` if installed)
6. Run `sync` to flush all writes

This replaces the manual workflow of:
```bash
# Old way — manual
qemu-img convert -O raw input.vmdk output.raw
sudo dd if=output.raw of=/dev/sdX bs=4M conv=fsync status=progress
```

The resulting disk can be detached from the host and attached to another VM as a data disk, or used for bare-metal boots.

### Serve converted images for download

```bash
vm-weaver --serve
# Outputs direct HTTP download links for all converted files
```

---

## Configuration

VM Weaver uses environment variables for configuration — no config file needed:

| Variable | Default | Description |
|---|---|---|
| `VM_DISK_DIR` | `~/vm_disks` | Root directory for disk images |
| `HTTP_PORT` | `8080` | Port used by the HTTP download server |

Example — use a custom directory and port:

```bash
VM_DISK_DIR=/mnt/storage/vms HTTP_PORT=9000 vm-weaver
```

---

## Supported formats

| Format | Extension | Notes |
|---|---|---|
| QEMU Copy-On-Write v2 | `.qcow2` | Native KVM/QEMU format, supports snapshots and compression |
| VMware | `.vmdk` | VMware Workstation / ESXi |
| Virtual Hard Disk | `.vhd` | Hyper-V, Azure |
| VirtualBox | `.vdi` | VirtualBox native |
| Raw | `.raw` / `.img` | Bare-metal compatible, works with `dd` and direct disk writes |
| QEMU Enhanced Disk | `.qed` | Lightweight QEMU format |

---

## License

[GNU General Public License v3.0](LICENSE)
