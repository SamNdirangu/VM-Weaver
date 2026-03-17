# VM Weaver

> **Upload · Convert · Serve · Write VM disk images — all from one tool.**

VM Weaver is a terminal-based utility for Linux (Ubuntu 20.04+) that handles the full lifecycle of VM disk image management: upload files to a server via SFTP/SCP/rsync, convert between formats (VMDK, QCOW2, VHD, VDI, RAW, and more), serve them for download over HTTP, or write them directly to a physical disk — no manual `dd` needed.

```
  ╔══╡ VM WEAVER ╞════════════════════════════════════════════════════╗
  ║ ██╗   ██╗███╗   ███╗  ██╗    ██╗███████╗ █████╗ ██╗   ██╗██████╗ ║
  ║ ██║   ██║████╗ ████║  ██║    ██║██╔════╝██╔══██╗██║   ██║██╔══██╗║
  ║ ██║   ██║██╔████╔██║  ██║ █╗ ██║█████╗  ███████║██║   ██║██████╔╝║
  ║ ╚██╗ ██╔╝██║╚██╔╝██║  ██║███╗██║██╔══╝  ██╔══██║╚██╗ ██╔╝██╔══██╗║
  ║  ╚████╔╝ ██║ ╚═╝ ██║  ╚███╔███╔╝███████╗██║  ██║ ╚████╔╝ ██║  ██║║
  ║   ╚═══╝  ╚═╝     ╚═╝   ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚═╝  ╚═╝║
  ╠═══════════════════════════════════════════════════════════════════╣
  ║  ·.·´¯·.¸¸.·´¯·.¸  ~~ W · E · A · V · E · R ~~  ¸.·´¯·.·      ║
  ║     Upload · Convert · Serve · Write VM Disk Images               ║
  ╚═══════════════════════════════════════════════════════════════════╝
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
git clone https://github.com/yourname/vm-weaver.git
cd vm-weaver
sudo bash scripts/vm_weaver.sh --install
```

This will:
1. Install all required packages (`qemu-utils`, `openssh-server`, `python3`, `rsync`, `pv`, etc.)
2. Create the `~/vm_disks` working directory
3. Register `vm-weaver` in `/usr/local/bin` so you can call it from anywhere

### Manual install (no git)

```bash
curl -O https://raw.githubusercontent.com/yourname/vm-weaver/main/scripts/vm_weaver.sh
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

## Packaging & distribution

### Quick one-liner install (recommended)

The script is fully self-contained. Easiest way to install on any Ubuntu/Debian machine:

```bash
curl -fsSL https://raw.githubusercontent.com/SamNdirangu/VM-Weaver/main/scripts/vm_weaver.sh \
  -o vm_weaver.sh && sudo bash vm_weaver.sh --install
```

This downloads the script, runs first-time setup, and registers `vm-weaver` in `/usr/local/bin`.

### As a `.deb` package (apt install)

To make VM Weaver discoverable via `apt install vm-weaver`, you need a Launchpad PPA:

**1. Build the `.deb` package:**

```
vm-weaver/
├── DEBIAN/
│   └── control          ← package metadata
└── usr/
    └── local/
        └── bin/
            └── vm-weaver  ← the script
```

`DEBIAN/control`:
```
Package: vm-weaver
Version: 2.0
Architecture: all
Maintainer: Your Name <you@example.com>
Depends: bash, qemu-utils, python3, openssh-server, rsync, pv
Description: VM disk image manager — upload, convert, serve and write VM disks
 VM Weaver handles the full lifecycle of VM disk image management from
 a single interactive terminal tool.
```

Build it:
```bash
dpkg-deb --build vm-weaver/
```

**2. Publish to a Launchpad PPA:**

- Create an account at [launchpad.net](https://launchpad.net)
- Create a PPA (`launchpad.net/~yourname/+archive/ubuntu/vm-weaver`)
- Upload your source package with `dput`

**3. Users install with:**
```bash
sudo add-apt-repository ppa:yourname/vm-weaver
sudo apt update
sudo apt install vm-weaver
```

> **Faster alternative:** Use [Packagecloud](https://packagecloud.io) or [Gemfury](https://gemfury.com) for private/public `.deb` hosting without needing a Launchpad account or GPG signing.

---

## Should you split the script into multiple files?

**Short answer: probably not right now.**

The current single-file design is actually a strength — `vm-weaver` is one file you can `curl`, `chmod +x`, and run anywhere with zero extra setup. Splitting into modules (e.g. `lib/convert.sh`, `lib/server.sh`) would require either:

- A **wrapper that sources them** — which means all files must be present and co-located, breaking the simple `curl | bash` install.
- A **build step** that concatenates them back into one file before distribution — adding tooling complexity.

The right time to split is when the script grows beyond ~2,000 lines and becomes genuinely hard to navigate. At that point, use a build step (e.g. a `Makefile` that `cat`s partials into `dist/vm-weaver`) so the distribution artifact is still a single file.

---

## Website / download page

The HTTP server built into VM Weaver already provides a branded download page for serving converted disk images on your local network (accessible at `http://<your-ip>:8080`).

For a **public project page**, the recommended approach is a static site hosted on GitHub Pages:

1. Add a `docs/` folder to the repo with an `index.html` (or use a static site generator like [Hugo](https://gohugo.io) or [Jekyll](https://jekyllrb.com))
2. Enable GitHub Pages in repo Settings → Pages → Source: `docs/` branch `main`
3. Your page is live at `https://yourname.github.io/vm-weaver`

A `docs/index.html` with download instructions, usage examples, and a copy of the banner makes for a clean project landing page with zero hosting costs.

---

## License

[GNU General Public License v3.0](LICENSE)
