#!/bin/sh
# =============================================================================
#  VM Weaver — upload, convert, serve & write VM disk images
#  Supports: VMDK · QCOW2 · VHD · VDI · RAW · OVA · IMG · QED
#  Requires: Alpine Linux  |  License: GPL-3.0
#
#  Author  : Sam Ndirangu <sndirangu7@gmail.com>
#  GitHub  : https://github.com/SamNdirangu/VM-Weaver
#  Version : 2.0.1
#  Created : 2025
#
#  POSIX sh compatible — works with BusyBox ash on Alpine Linux
# =============================================================================

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m';  LRED='\033[1;31m'
GRN='\033[0;32m';  LGRN='\033[1;32m'
YLW='\033[1;38;5;226m';  LYLW='\033[1;33m'
BLU='\033[38;5;33m';  LBLU='\033[1;38;5;33m'
MAG='\033[1;38;5;46m';  LMAG='\033[1;38;5;46m'
CYN='\033[1;36m';  LCYN='\033[1;36m'
WHT='\033[1;37m';  DIM='\033[2m'
BOLD='\033[1m';    RST='\033[0m'

# ── Privilege escalation ───────────────────────────────────────────────────────
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
elif command -v doas >/dev/null 2>&1; then
    SUDO="doas"
else
    SUDO=""
    echo "  [!]  No sudo/doas found — privileged commands may fail."
fi

# ── Config ────────────────────────────────────────────────────────────────────
DISK_DIR="${VM_DISK_DIR:-/home/user/vm_disks}"
CONVERTED_DIR="${DISK_DIR}/converted"
HTTP_PORT="${HTTP_PORT:-8080}"
HTTP_PID_FILE="/tmp/vm_weaver_http_server.pid"
DISK_EXTENSIONS="vmdk|qcow2|vhd|vdi|raw|ova|img|iso|parallels|qed|vpc"
VERSION="2.0"

# ── Banner ────────────────────────────────────────────────────────────────────
print_banner() {
    clear
    # Gradient rows: bright yellow → gold → orange → amber → burnt → deep red (light→dark top→bottom)
    C1='\033[38;5;226m'  # bright yellow           (row 1 - brightest)
    C2='\033[38;5;220m'  # gold                    (row 2)
    C3='\033[38;5;214m'  # warm orange             (row 3)
    C4='\033[38;5;208m'  # orange                  (row 4)
    C5='\033[38;5;202m'  # red-orange              (row 5)
    C6='\033[38;5;196m'  # bright red              (row 6 - darkest)
    FR='\033[0;32m'      # green frame (original dark-mode frame)
    WB='\033[1;37m'      # bright white for WEAVER tagline
    DM_B='\033[1;37m'    # bold bright white for subtitles
    RS='\033[0m'         # reset

    printf "${FR}  ╔══╡ VM WEAVER ╞═══════════════════════════════════════════════════════════════╗${RS}\n"
    printf "${FR}  ║ ${C1}██╗   ██╗███╗   ███╗   ██╗    ██╗███████╗ █████╗ ██╗   ██╗███████╗██████╗    ${FR}║${RS}\n"
    printf "${FR}  ║ ${C2}██║   ██║████╗ ████║   ██║    ██║██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗   ${FR}║${RS}\n"
    printf "${FR}  ║ ${C3}██║   ██║██╔████╔██║   ██║ █╗ ██║█████╗  ███████║██║   ██║█████╗  ██████╔╝   ${FR}║${RS}\n"
    printf "${FR}  ║ ${C4}╚██╗ ██╔╝██║╚██╔╝██║   ██║███╗██║██╔══╝  ██╔══██║╚██╗ ██╔╝██╔══╝  ██╔══██╗   ${FR}║${RS}\n"
    printf "${FR}  ║ ${C5} ╚████╔╝ ██║ ╚═╝ ██║   ╚███╔███╔╝███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║   ${FR}║${RS}\n"
    printf "${FR}  ║ ${C6}  ╚═══╝  ╚═╝     ╚═╝    ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝   ${FR}║${RS}\n"
    printf "${FR}  ╠══════════════════════════════════════════════════════════════════════════════╣${RS}\n"
    printf "${FR}  ║ ${WB}      ·.·´¯·.¸¸.·´¯·.¸  ~~ W · E · A · V · E · R ~~  ¸.·´¯·.¸¸.·´¯·.·        ${FR}║${RS}\n"
    printf "${FR}  ║ ${DM_B}           Upload · Convert · Serve · Write VM Disk Images                   ${FR}║${RS}\n"
    printf "${FR}  ║ ${DM_B}           v${VERSION} · github.com/SamNdirangu/VM-Weaver                           ${FR}║${RS}\n"
    printf "${FR}  ╚══════════════════════════════════════════════════════════════════════════════╝${RS}\n"
    echo
}

box_line() { printf "${CYN}  ├──────────────────────────────────────────────────────────────────────────────┤${RST}\n"; }
box_top()  { printf "${CYN}  ╔══════════════════════════════════════════════════════════════════════════════╗${RST}\n"; }
box_bot()  { printf "${CYN}  ╚══════════════════════════════════════════════════════════════════════════════╝${RST}\n"; }
box_row()  { printf "${CYN}  ║${RST} %-76s ${CYN}║${RST}\n" "$1"; }

info()    { printf "${LCYN}  [ℹ]${RST}  %s\n" "$*"; }
success() { printf "${LGRN}  [✔]${RST}  %s\n" "$*"; }
warn()    { printf "${LYLW}  [!]${RST}  %s\n" "$*"; }
error()   { printf "${LRED}  [✘]${RST}  %s\n" "$*"; }
heading() { printf "\n${LMAG}${BOLD}  ══  %s  ══${RST}\n\n" "$*"; }
prompt()  { printf "${LYLW}  ▶  ${WHT}%s${RST} " "$*"; }

spinner() {
    _sp_pid=$1
    _sp_msg="${2:-Working…}"
    _sp_frames='|/-\'
    _sp_i=0
    while kill -0 "$_sp_pid" 2>/dev/null; do
        _sp_frame=$(printf '%s' "$_sp_frames" | cut -c$((_sp_i + 1)))
        printf "\r${CYN}  %s${RST}  ${DIM}%s${RST}" "$_sp_frame" "$_sp_msg"
        _sp_i=$(( (_sp_i + 1) % 4 ))
        sleep 1
    done
    printf "\r%-70s\r" " "
}

hr() { printf "${DIM}  ────────────────────────────────────────────────────────────────────────────────${RST}\n"; }
pause() { echo; prompt "Press [Enter] to continue…"; read -r _dummy; }

get_ip() {
    ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}' \
        || hostname -i 2>/dev/null | awk '{print $1}' \
        || echo "127.0.0.1"
}

human_size() {
    _hs_f="$1"
    if [ -f "$_hs_f" ]; then
        du -h "$_hs_f" | cut -f1
    else
        echo "—"
    fi
}

ensure_dirs() {
    mkdir -p "$DISK_DIR" "$CONVERTED_DIR"
}

# Helper: convert string to lowercase
tolower() { echo "$1" | tr 'A-Z' 'a-z'; }

# Helper: convert string to uppercase
toupper() { echo "$1" | tr 'a-z' 'A-Z'; }

# Helper: check if string is a positive integer
is_number() { case "$1" in ''|*[!0-9]*) return 1;; *) return 0;; esac; }

# ── Alpine package helpers ─────────────────────────────────────────────────────
apk_installed() { apk info -e "$1" >/dev/null 2>&1; }

# ── Dependency installer ───────────────────────────────────────────────────────
install_deps() {
    print_banner
    heading "System Setup & Dependency Installer"

    info "This will install all required packages for VM Weaver."
    info "Packages: qemu-img, openssh, python3, rsync, curl, iproute2, pv, util-linux"
    echo
    prompt "Proceed with installation? [y/N]: "; read -r ans
    ans=$(tolower "$ans")
    [ "$ans" != "y" ] && warn "Aborted." && return

    echo
    info "Updating package list…"
    $SUDO apk update >/dev/null 2>&1 &
    spinner $! "Updating apk package list"
    success "Package list updated."

    for pkg in qemu-img openssh python3 rsync curl iproute2 pv util-linux; do
        info "Installing ${BOLD}${pkg}${RST}…"
        $SUDO apk add --no-cache "$pkg" >/dev/null 2>&1 &
        spinner $! "Installing $pkg"
        if apk_installed "$pkg"; then
            success "$pkg installed."
        else
            error "Failed to install $pkg — check your apk repositories."
        fi
    done

    echo
    info "Enabling & starting SSH server…"
    $SUDO rc-update add sshd default >/dev/null 2>&1
    $SUDO rc-service sshd start >/dev/null 2>&1
    success "SSH server active."

    echo
    info "Creating disk directories: ${BOLD}${DISK_DIR}${RST}  &  ${BOLD}${CONVERTED_DIR}${RST}"
    ensure_dirs
    success "Directories ready."

    # Install vm-weaver globally
    install_to_bin

    echo
    success "All dependencies installed and services configured."
    pause
}

# ── Install to /usr/local/bin ──────────────────────────────────────────────────
install_to_bin() {
    echo
    heading "Installing vm-weaver to /usr/local/bin"

    SCRIPT_PATH="$(realpath "$0")"
    TARGET="/usr/local/bin/vm-weaver"

    info "Creating symlink: ${BOLD}${TARGET}${RST} → ${SCRIPT_PATH}"
    $SUDO ln -sf "$SCRIPT_PATH" "$TARGET"
    $SUDO chmod +x "$SCRIPT_PATH"

    if [ -x "$TARGET" ]; then
        success "vm-weaver is now available system-wide."
        info "Run it from anywhere with:  ${BOLD}vm-weaver${RST}"
    else
        error "Failed to install to /usr/local/bin. You may need sudo."
    fi
}

check_deps() {
    missing=""
    command -v qemu-img >/dev/null 2>&1 || missing="$missing qemu-img"
    command -v python3  >/dev/null 2>&1 || missing="$missing python3"
    command -v rsync    >/dev/null 2>&1 || missing="$missing rsync"

    if [ -n "$missing" ]; then
        warn "Missing packages:$missing"
        prompt "Install now? [y/N]: "; read -r ans
        ans=$(tolower "$ans")
        if [ "$ans" = "y" ]; then
            $SUDO apk update >/dev/null 2>&1
            # shellcheck disable=SC2086
            $SUDO apk add --no-cache $missing
        fi
    else
        success "All core dependencies are present."
    fi
}

# ── Upload instructions ────────────────────────────────────────────────────────
show_upload_instructions() {
    print_banner
    heading "How to Upload VM Disk Files to This Server"

    MY_IP=$(get_ip)
    MY_USER=$(whoami)

    box_top
    box_row "  Supported formats: vmdk  qcow2  vhd  vdi  raw  ova  img"
    box_row "  Destination folder: $DISK_DIR"
    box_row ""
    box_row "  Server IP  : $MY_IP"
    box_row "  Username   : $MY_USER"
    box_line

    printf "${CYN}  ║${RST} ${LMAG}${BOLD} 1 — SFTP  (recommended)${RST}\n"
    box_row ""
    box_row "  sftp $MY_USER@$MY_IP"
    box_row "    sftp> cd $DISK_DIR"
    box_row "    sftp> put /local/path/disk.vmdk"
    box_row "    sftp> put /local/path/*.qcow2"
    box_row "    sftp> bye"
    box_line

    printf "${CYN}  ║${RST} ${LMAG}${BOLD} 2 — SCP (single file / glob)${RST}\n"
    box_row ""
    box_row "  scp /local/disk.vmdk $MY_USER@$MY_IP:$DISK_DIR/"
    box_row "  scp *.qcow2          $MY_USER@$MY_IP:$DISK_DIR/"
    box_line

    printf "${CYN}  ║${RST} ${LMAG}${BOLD} 3 — rsync (folder sync, resumable)${RST}\n"
    box_row ""
    box_row "  rsync -avP --progress /local/vm-folder/ \\"
    box_row "        $MY_USER@$MY_IP:$DISK_DIR/"
    box_line

    printf "${CYN}  ║${RST} ${LMAG}${BOLD} 4 — Windows / WinSCP GUI${RST}\n"
    box_row ""
    box_row "  Protocol : SFTP"
    box_row "  Host     : $MY_IP    Port: 22"
    box_row "  User     : $MY_USER"
    box_row "  Remote   : $DISK_DIR"
    box_bot

    echo
    info "Ensure SSH is running:  ${BOLD}$SUDO rc-service sshd start${RST}"
    info "Check open port 22:     ${BOLD}$SUDO iptables -A INPUT -p tcp --dport 22 -j ACCEPT${RST}"
    pause
}

# ── List disk files ────────────────────────────────────────────────────────────
list_disk_files() {
    print_banner
    heading "VM Disk Files in ${DISK_DIR}"
    ensure_dirs

    FILES=$(find "$DISK_DIR" -maxdepth 2 -type f \
        | grep -iE "\.(${DISK_EXTENSIONS})$" | sort)

    if [ -z "$FILES" ]; then
        warn "No VM disk files found in ${DISK_DIR}"
        info "Upload files first — see option 1 in the main menu."
        pause; return
    fi

    printf "\n${BOLD}${CYN}  %-4s %-40s %-8s %-10s %-20s${RST}\n" \
        "#" "Filename" "Size" "Format" "Modified"
    hr
    i=1
    echo "$FILES" | while IFS= read -r f; do
        fname=$(basename "$f")
        fsize=$(du -h "$f" 2>/dev/null | cut -f1)
        fext="${fname##*.}"
        fext_upper=$(toupper "$fext")
        # Alpine busybox: use stat -c '%y' (works in both busybox and gnu stat)
        fmod=$(stat -c '%y' "$f" 2>/dev/null | cut -d' ' -f1,2 | cut -c1-16) || fmod="unknown"
        fname_trunc=$(printf '%.39s' "$fname")
        printf "  ${LYLW}%-4s${RST} ${WHT}%-40s${RST} ${LGRN}%-8s${RST} ${LCYN}%-10s${RST} ${DIM}%-20s${RST}\n" \
            "$i" "$fname_trunc" "$fsize" "$fext_upper" "$fmod"
        i=$((i + 1))
    done

    file_count=$(echo "$FILES" | wc -l)
    hr
    success "Total: ${file_count} file(s) found."

    CFILES=$(find "$CONVERTED_DIR" -maxdepth 1 -type f \
        | grep -iE "\.(${DISK_EXTENSIONS})$" | sort)
    if [ -n "$CFILES" ]; then
        echo
        printf "${LMAG}  Converted files (${CONVERTED_DIR}):${RST}\n"
        hr
        j=1
        echo "$CFILES" | while IFS= read -r f; do
            fname=$(basename "$f")
            fsize=$(du -h "$f" 2>/dev/null | cut -f1)
            fext="${fname##*.}"
            fext_upper=$(toupper "$fext")
            fname_trunc=$(printf '%.39s' "$fname")
            printf "  ${LMAG}%-4s${RST} ${WHT}%-40s${RST} ${LGRN}%-8s${RST} ${LCYN}%-10s${RST}\n" \
                "$j" "$fname_trunc" "$fsize" "$fext_upper"
            j=$((j + 1))
        done
        hr
    fi
    pause
}

# ── Helper: select file from a list ──────────────────────────────────────────
# Usage: _select_file "$file_list" "$sel_number"
# Prints the Nth file from the newline-separated list (1-indexed)
_nth_line() {
    echo "$1" | sed -n "${2}p"
}

_line_count() {
    if [ -z "$1" ]; then
        echo 0
    else
        echo "$1" | wc -l
    fi
}

# ── Convert disk image ─────────────────────────────────────────────────────────
convert_disk() {
    print_banner
    heading "Convert VM Disk Image"

    if ! command -v qemu-img >/dev/null 2>&1; then
        error "qemu-img not found. Run option 9 to install dependencies."
        pause; return
    fi

    ensure_dirs
    FILES=$(find "$DISK_DIR" -maxdepth 2 -type f \
        | grep -iE "\.(${DISK_EXTENSIONS})$" | sort)

    if [ -z "$FILES" ]; then
        warn "No source disk files found in ${DISK_DIR}"
        pause; return
    fi

    file_count=$(_line_count "$FILES")

    # Select source
    printf "${LMAG}  Select source file:${RST}\n\n"
    i=1
    echo "$FILES" | while IFS= read -r f; do
        sz=$(du -h "$f" | cut -f1)
        printf "  ${LYLW}[%2d]${RST}  ${WHT}%-42s${RST}  ${LGRN}%s${RST}\n" \
            "$i" "$(basename "$f")" "$sz"
        i=$((i + 1))
    done
    echo
    prompt "Enter file number (1-${file_count}): "; read -r sel
    if ! is_number "$sel" || [ "$sel" -lt 1 ] || [ "$sel" -gt "$file_count" ]; then
        error "Invalid selection."; pause; return
    fi
    SRC=$(_nth_line "$FILES" "$sel")
    info "Source: ${BOLD}$(basename "$SRC")${RST}  ($(du -h "$SRC" | cut -f1))"

    # Select target format
    echo
    printf "${LMAG}  Select output format:${RST}\n\n"
    printf "  ${LYLW}[1]${RST}  ${WHT}%-10s${RST}  ${DIM}%s${RST}\n" "qcow2" "QEMU Copy-On-Write v2 (KVM/QEMU)"
    printf "  ${LYLW}[2]${RST}  ${WHT}%-10s${RST}  ${DIM}%s${RST}\n" "vmdk" "VMware Disk Format"
    printf "  ${LYLW}[3]${RST}  ${WHT}%-10s${RST}  ${DIM}%s${RST}\n" "vhd" "Virtual Hard Disk (Hyper-V/Azure)"
    printf "  ${LYLW}[4]${RST}  ${WHT}%-10s${RST}  ${DIM}%s${RST}\n" "vdi" "VirtualBox Disk Image"
    printf "  ${LYLW}[5]${RST}  ${WHT}%-10s${RST}  ${DIM}%s${RST}\n" "raw" "Raw disk image (max compat, bare-metal write)"
    printf "  ${LYLW}[6]${RST}  ${WHT}%-10s${RST}  ${DIM}%s${RST}\n" "qed" "QEMU Enhanced Disk"
    echo
    prompt "Enter format number (1-6): "; read -r fsel
    if ! is_number "$fsel" || [ "$fsel" -lt 1 ] || [ "$fsel" -gt 6 ]; then
        error "Invalid selection."; pause; return
    fi
    case "$fsel" in
        1) FMT="qcow2" ;; 2) FMT="vmdk" ;; 3) FMT="vhd" ;;
        4) FMT="vdi" ;;   5) FMT="raw" ;;  6) FMT="qed" ;;
    esac
    FMT_UPPER=$(toupper "$FMT")
    info "Output format: ${BOLD}${FMT_UPPER}${RST}"

    # Compression option (qcow2 only)
    COMPRESS_FLAG=""
    if [ "$FMT" = "qcow2" ]; then
        prompt "Enable compression? (smaller file, slower write) [y/N]: "; read -r comp
        comp=$(tolower "$comp")
        [ "$comp" = "y" ] && COMPRESS_FLAG="-c"
    fi

    # RAW-specific: trim/truncate to save space
    SPARSE_FLAG=""
    raw_opt=""
    if [ "$FMT" = "raw" ]; then
        echo
        warn "RAW files can be very large — they represent the full virtual disk."
        echo
        printf "${LMAG}  Space-saving option for RAW output:${RST}\n\n"
        printf "  ${LYLW}[1]${RST}  ${WHT}Full raw image${RST}         ${DIM}Exact copy, maximum compatibility${RST}\n"
        printf "  ${LYLW}[2]${RST}  ${WHT}Sparse (thin)${RST}          ${DIM}Skips empty blocks — smaller on disk, same logical size${RST}\n"
        printf "  ${LYLW}[3]${RST}  ${WHT}Trim to used data${RST}       ${DIM}Truncate output to actual last used byte (smallest file)${RST}\n"
        echo
        prompt "Choose [1-3] (default 1): "; read -r raw_opt
        case "${raw_opt}" in
            2) SPARSE_FLAG="-S 4k"
               info "Using sparse output — empty blocks will be skipped." ;;
            3) SPARSE_FLAG="-S 4k"  # sparse first, then we truncate after
               info "Will trim output to last used byte after conversion." ;;
            *) info "Full raw image selected." ;;
        esac
    fi

    # Output filename
    SRCBASE=$(basename "${SRC%.*}")
    OUTFILE="${CONVERTED_DIR}/${SRCBASE}.${FMT}"
    QFMT="$FMT"
    [ "$FMT" = "vhd" ] && QFMT="vpc"

    echo
    info "Output: ${BOLD}${OUTFILE}${RST}"
    prompt "Start conversion? [Y/n]: "; read -r go
    go=$(tolower "$go")
    [ "$go" = "n" ] && warn "Cancelled." && pause && return

    echo
    info "Converting… (this may take a while for large files)"
    hr

    SRC_SIZE=$(du -h "$SRC" | cut -f1)

    # shellcheck disable=SC2086
    qemu-img convert $COMPRESS_FLAG $SPARSE_FLAG -p -O "$QFMT" "$SRC" "$OUTFILE" &
    CONV_PID=$!
    spinner $CONV_PID "Converting ${SRCBASE} → ${FMT_UPPER}"
    wait $CONV_PID
    STATUS=$?

    if [ $STATUS -eq 0 ] && [ -f "$OUTFILE" ]; then
        # Truncate raw to last used byte if option 3 was chosen
        if [ "$FMT" = "raw" ] && [ "${raw_opt}" = "3" ]; then
            info "Trimming raw file to last used byte…"
            TRIM_SIZE=$(qemu-img info --output=json "$OUTFILE" 2>/dev/null \
                | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('actual-size', d.get('virtual-size', 0)))" 2>/dev/null || echo 0)
            if [ "$TRIM_SIZE" -gt 0 ] 2>/dev/null; then
                if truncate -s "$TRIM_SIZE" "$OUTFILE" 2>/dev/null; then
                    success "Trimmed to ${TRIM_SIZE} bytes."
                else
                    warn "Could not truncate — file left as-is."
                fi
            fi
        fi

        DST_SIZE=$(du -h "$OUTFILE" | cut -f1)
        echo
        success "Conversion complete!"
        hr
        printf "  ${DIM}Source : ${RST}${WHT}%s${RST}  →  ${DIM}Size: ${LGRN}%s${RST}\n" \
            "$(basename "$SRC")" "$SRC_SIZE"
        printf "  ${DIM}Output : ${RST}${WHT}%s${RST}  →  ${DIM}Size: ${LGRN}%s${RST}\n" \
            "$(basename "$OUTFILE")" "$DST_SIZE"
        hr
        echo

        # Offer to write directly to disk (especially useful for raw)
        if [ "$FMT" = "raw" ]; then
            prompt "Write this image directly to a physical disk now? [y/N]: "; read -r wd
            wd=$(tolower "$wd")
            if [ "$wd" = "y" ]; then
                write_to_disk "$OUTFILE"
                return
            fi
        fi

        prompt "Start HTTP download server now? [Y/n]: "; read -r srv
        srv=$(tolower "$srv")
        [ "$srv" != "n" ] && start_http_server
    else
        error "Conversion failed! Check disk space and file permissions."
    fi
    pause
}

# ── Write image to physical disk ───────────────────────────────────────────────
write_to_disk() {
    IMG_FILE="${1:-}"

    print_banner
    heading "Write Disk Image to Physical Disk"

    warn "This will OVERWRITE all data on the selected disk. This cannot be undone."
    echo

    # If no image passed in, let user choose one
    if [ -z "$IMG_FILE" ]; then
        ALL_IMGS=$(find "$CONVERTED_DIR" "$DISK_DIR" -maxdepth 2 -type f \
            | grep -iE "\.(${DISK_EXTENSIONS}|raw)$" | sort -u)

        if [ -z "$ALL_IMGS" ]; then
            error "No disk image files found. Convert a disk first."
            pause; return
        fi

        img_count=$(_line_count "$ALL_IMGS")

        printf "${LMAG}  Select image to write:${RST}\n\n"
        k=1
        echo "$ALL_IMGS" | while IFS= read -r f; do
            sz=$(du -h "$f" | cut -f1)
            printf "  ${LYLW}[%2d]${RST}  ${WHT}%-42s${RST}  ${LGRN}%s${RST}\n" \
                "$k" "$(basename "$f")" "$sz"
            k=$((k + 1))
        done
        echo
        prompt "Enter image number (1-${img_count}): "; read -r imgsel
        if ! is_number "$imgsel" || [ "$imgsel" -lt 1 ] || [ "$imgsel" -gt "$img_count" ]; then
            error "Invalid selection."; pause; return
        fi
        IMG_FILE=$(_nth_line "$ALL_IMGS" "$imgsel")
    fi

    info "Image: ${BOLD}$(basename "$IMG_FILE")${RST}  ($(du -h "$IMG_FILE" | cut -f1))"
    echo

    # List physical disks — exclude loop, ram, and the root disk
    printf "${LMAG}  Available physical disks:${RST}\n\n"
    hr

    DISKS=$(lsblk -dn -o NAME,SIZE,TYPE,MODEL 2>/dev/null \
        | awk '$3=="disk" {print $0}' | grep -v '^loop')

    if [ -z "$DISKS" ]; then
        error "No physical disks found (you may need to run as root or with sudo)."
        pause; return
    fi

    disk_count=$(_line_count "$DISKS")

    printf "  ${BOLD}${CYN}%-4s %-10s %-8s %-6s %-30s${RST}\n" \
        "#" "Device" "Size" "Type" "Model"
    hr
    d=1
    DISK_NAMES=""
    echo "$DISKS" | while IFS= read -r line; do
        dname=$(echo "$line" | awk '{print $1}')
        dsize=$(echo "$line" | awk '{print $2}')
        dtype=$(echo "$line" | awk '{print $3}')
        dmodel=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | xargs)

        # Warn if it looks like a system disk (has partitions mounted at /)
        IS_SYS=""
        if lsblk -no MOUNTPOINT "/dev/$dname" 2>/dev/null | grep -q "^/$"; then
            IS_SYS="${LRED}[SYSTEM DISK!]${RST}"
        fi

        printf "  ${LYLW}[%2d]${RST}  ${WHT}%-10s${RST} ${LGRN}%-8s${RST} ${LCYN}%-6s${RST} ${DIM}%-30s${RST} %b\n" \
            "$d" "/dev/$dname" "$dsize" "$dtype" "$(printf '%.29s' "$dmodel")" "$IS_SYS"
        d=$((d + 1))
    done
    hr
    echo
    warn "Do NOT select your system/boot disk. Look for the [SYSTEM DISK!] warning above."
    echo
    prompt "Enter disk number (1-${disk_count}): "; read -r dsel
    if ! is_number "$dsel" || [ "$dsel" -lt 1 ] || [ "$dsel" -gt "$disk_count" ]; then
        error "Invalid selection."; pause; return
    fi

    TARGET_DNAME=$(echo "$DISKS" | sed -n "${dsel}p" | awk '{print $1}')
    TARGET_DISK="/dev/${TARGET_DNAME}"

    # Double-confirm — this is destructive
    echo
    warn "You are about to write:"
    printf "    ${WHT}%s${RST}  →  ${LRED}%s${RST}\n" "$(basename "$IMG_FILE")" "$TARGET_DISK"
    echo
    warn "ALL EXISTING DATA ON ${TARGET_DISK} WILL BE PERMANENTLY DESTROYED."
    echo
    prompt "Type YES to confirm, anything else to cancel: "; read -r confirm
    if [ "$confirm" != "YES" ]; then
        warn "Cancelled. Nothing was written."
        pause; return
    fi

    # Unmount any mounted partitions on the target disk
    echo
    info "Unmounting any mounted partitions on ${TARGET_DISK}…"
    MOUNTED=$(lsblk -no PATH,MOUNTPOINT "/dev/${TARGET_DNAME}" \
        | awk '$2!="" {print $1}')
    if [ -n "$MOUNTED" ]; then
        echo "$MOUNTED" | while IFS= read -r mp; do
            $SUDO umount "$mp" 2>/dev/null && info "Unmounted $mp" || true
        done
    fi

    echo
    info "Writing image to disk…"
    info "This may take a long time depending on image size."
    hr

    IMG_SIZE_BYTES=$(stat -c '%s' "$IMG_FILE" 2>/dev/null || echo 0)

    if command -v pv >/dev/null 2>&1 && [ "$IMG_SIZE_BYTES" -gt 0 ] 2>/dev/null; then
        # Use pv for a nice progress bar
        $SUDO pv -pterb -s "$IMG_SIZE_BYTES" "$IMG_FILE" | $SUDO dd of="$TARGET_DISK" bs=4M conv=fsync 2>/dev/null &
        WRITE_PID=$!
        wait $WRITE_PID
        WRITE_STATUS=$?
    else
        $SUDO dd if="$IMG_FILE" of="$TARGET_DISK" bs=4M conv=fsync status=progress &
        WRITE_PID=$!
        spinner $WRITE_PID "Writing $(basename "$IMG_FILE") to ${TARGET_DISK}"
        wait $WRITE_PID
        WRITE_STATUS=$?
    fi

    echo
    if [ $WRITE_STATUS -eq 0 ]; then
        $SUDO sync
        success "Write complete!"
        hr
        printf "  ${DIM}Image  : ${RST}${WHT}%s${RST}\n" "$(basename "$IMG_FILE")"
        printf "  ${DIM}Target : ${RST}${LGRN}%s${RST}\n" "$TARGET_DISK"
        hr
        echo
        info "The disk is ready. You can now:"
        printf "  ${CYN}·${RST}  Detach it from this host\n"
        printf "  ${CYN}·${RST}  Attach it to another VM as a data disk\n"
        printf "  ${CYN}·${RST}  Boot from it directly on bare metal\n"
    else
        error "Write failed! Check dmesg or /var/log/messages for details."
        error "dd exit code: ${WRITE_STATUS}"
    fi
    pause
}


# ── HTTP download server ───────────────────────────────────────────────────────
start_http_server() {
    print_banner
    heading "HTTP File Download Server"
    ensure_dirs

    if [ -f "$HTTP_PID_FILE" ]; then
        OLD_PID=$(cat "$HTTP_PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            warn "Server is already running (PID ${OLD_PID})."
            MY_IP=$(get_ip)
            echo
            info "Download URL: ${BOLD}${LCYN}http://${MY_IP}:${HTTP_PORT}${RST}"
            list_download_links
            pause; return
        fi
    fi

    CFILES=$(find "$CONVERTED_DIR" -maxdepth 1 -type f \
        | grep -iE "\.(${DISK_EXTENSIONS})$" | sort)

    if [ -z "$CFILES" ]; then
        warn "No converted files found. The server will serve all files in:"
        info "${DISK_DIR}"
        SERVE_DIR="$DISK_DIR"
    else
        SERVE_DIR="$CONVERTED_DIR"
    fi

    # Alpine uses iptables instead of ufw
    if command -v iptables >/dev/null 2>&1; then
        $SUDO iptables -C INPUT -p tcp --dport "$HTTP_PORT" -j ACCEPT >/dev/null 2>&1 || \
            $SUDO iptables -A INPUT -p tcp --dport "$HTTP_PORT" -j ACCEPT >/dev/null 2>&1 && \
            success "Firewall: port ${HTTP_PORT} opened." || true
    fi

    ( cd "$SERVE_DIR" && python3 -m http.server "$HTTP_PORT" \
        >/tmp/vm_weaver_http.log 2>&1 ) &
    SRV_PID=$!
    echo $SRV_PID > "$HTTP_PID_FILE"
    sleep 1

    if ! kill -0 "$SRV_PID" 2>/dev/null; then
        error "Server failed to start. Check /tmp/vm_weaver_http.log"
        pause; return
    fi

    MY_IP=$(get_ip)
    echo
    success "HTTP server started!  PID: ${SRV_PID}"
    hr
    box_top
    box_row ""
    box_row "  Base URL:  http://$MY_IP:$HTTP_PORT"
    box_row "  Serving:   $SERVE_DIR"
    box_row "  Log:       /tmp/vm_weaver_http.log"
    box_row ""
    box_bot
    echo
    list_download_links "$SERVE_DIR" "$MY_IP"
    pause
}

list_download_links() {
    DIR="${1:-$CONVERTED_DIR}"
    IP="${2:-$(get_ip)}"
    FILES=$(find "$DIR" -maxdepth 1 -type f \
        | grep -iE "\.(${DISK_EXTENSIONS})$" | sort)
    if [ -n "$FILES" ]; then
        echo
        printf "${LMAG}  Download links:${RST}\n"
        hr
        echo "$FILES" | while IFS= read -r f; do
            fname=$(basename "$f")
            fsz=$(du -h "$f" | cut -f1)
            encoded=$(python3 -c \
                "import urllib.parse; print(urllib.parse.quote('$fname'))" \
                2>/dev/null || echo "$fname")
            printf "  ${LGRN}↓${RST}  ${LBLU}http://${IP}:${HTTP_PORT}/${encoded}${RST}  ${DIM}(%s)${RST}\n" "$fsz"
        done
        hr
    else
        warn "No converted files to serve yet."
    fi
}

stop_http_server() {
    print_banner
    heading "Stop HTTP Download Server"

    if [ ! -f "$HTTP_PID_FILE" ]; then
        warn "No PID file found — server may not be running."
        pause; return
    fi

    PID=$(cat "$HTTP_PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" && rm -f "$HTTP_PID_FILE"
        success "Server (PID ${PID}) stopped."
        # Remove the iptables rule added at start
        if command -v iptables >/dev/null 2>&1; then
            $SUDO iptables -D INPUT -p tcp --dport "$HTTP_PORT" -j ACCEPT >/dev/null 2>&1 && \
                info "Firewall: port ${HTTP_PORT} closed." || true
        fi
    else
        warn "Process ${PID} is not running. Cleaning up PID file."
        rm -f "$HTTP_PID_FILE"
    fi
    pause
}

# ── Server status ──────────────────────────────────────────────────────────────
server_status() {
    MY_IP=$(get_ip)
    if [ -f "$HTTP_PID_FILE" ]; then
        PID=$(cat "$HTTP_PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            printf "  HTTP Server: ${LGRN}● RUNNING${RST}  PID:%s  ${LBLU}http://%s:%s${RST}\n" "$PID" "$MY_IP" "$HTTP_PORT"
        else
            printf "  HTTP Server: ${LRED}● STOPPED${RST} (stale PID file)\n"
        fi
    else
        printf "  HTTP Server: ${DIM}○ not running${RST}\n"
    fi
}

# ── Check / install qemu-img ───────────────────────────────────────────────────
check_qemu() {
    print_banner
    heading "Check qemu-img Installation"

    if command -v qemu-img >/dev/null 2>&1; then
        VER=$(qemu-img --version | head -1)
        success "qemu-img is installed: ${BOLD}${VER}${RST}"
        info "Supported formats:"
        echo
        qemu-img --help 2>&1 | grep -A2 'Supported formats' | tail -1 | \
            fold -s -w 70 | sed 's/^/    /'
    else
        error "qemu-img not found."
        prompt "Install qemu-img now? [y/N]: "; read -r ans
        ans=$(tolower "$ans")
        if [ "$ans" = "y" ]; then
            $SUDO apk update >/dev/null 2>&1 &
            spinner $! "Updating apk"
            $SUDO apk add --no-cache qemu-img
            success "qemu-img installed."
        fi
    fi
    pause
}

# ── Main menu ──────────────────────────────────────────────────────────────────
main_menu() {
    while true; do
        print_banner
        server_status
        echo
        box_top
        box_row "  MAIN MENU"
        box_line
        box_row "  1 ›  Show upload instructions (SFTP / SCP / rsync)"
        box_row "  2 ›  List VM disk files"
        box_row "  3 ›  Convert a disk image"
        box_row "  4 ›  Write image directly to a physical disk"
        box_row "  5 ›  Start HTTP download server"
        box_row "  6 ›  Stop HTTP download server"
        box_row "  7 ›  Show download links"
        box_row "  8 ›  Check / install qemu-img"
        box_row "  9 ›  Install dependencies & register vm-weaver globally"
        box_row " 10 ›  Exit"
        box_bot
        echo
        prompt "Choose an option [1-10]: "; read -r CHOICE

        case "$CHOICE" in
            1)  show_upload_instructions ;;
            2)  list_disk_files ;;
            3)  convert_disk ;;
            4)  write_to_disk ;;
            5)  start_http_server ;;
            6)  stop_http_server ;;
            7)  print_banner; heading "Download Links"; list_download_links; pause ;;
            8)  check_qemu ;;
            9)  install_deps ;;
            10)
                echo
                success "Goodbye, weaver."
                if [ -f "$HTTP_PID_FILE" ]; then
                    PID=$(cat "$HTTP_PID_FILE")
                    if kill -0 "$PID" 2>/dev/null; then
                        warn "HTTP server (PID ${PID}) is still running in the background."
                    fi
                fi
                echo
                exit 0
                ;;
            *)
                error "Invalid option. Please choose 1–10."
                sleep 1
                ;;
        esac
    done
}

# ── Entry point ───────────────────────────────────────────────────────────────
ensure_dirs

case "${1:-}" in
    --install|-i)    install_deps; exit 0 ;;
    --check|-c)      check_qemu;   exit 0 ;;
    --serve|-s)      start_http_server; exit 0 ;;
    --write|-w)      write_to_disk "${2:-}"; exit 0 ;;
    --convert|-C)    convert_disk; exit 0 ;;
    --help|-h)
        echo
        printf "${LMAG}  VM Weaver v${VERSION}${RST} — VM Disk Image Manager\n"
        echo
        printf "  ${BOLD}Usage:${RST} vm-weaver [option]\n"
        echo
        printf "  ${LYLW}--install,  -i${RST}    Run first-time setup & register globally\n"
        printf "  ${LYLW}--check,    -c${RST}    Check qemu-img installation\n"
        printf "  ${LYLW}--serve,    -s${RST}    Start HTTP download server\n"
        printf "  ${LYLW}--write,    -w${RST}    Write an image directly to a physical disk\n"
        printf "  ${LYLW}--convert,  -C${RST}    Convert a disk image\n"
        printf "  ${LYLW}--help,     -h${RST}    Show this help\n"
        printf "  ${DIM}(no args)${RST}         Launch interactive menu\n"
        echo
        exit 0
        ;;
esac

main_menu
