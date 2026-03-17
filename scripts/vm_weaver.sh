#!/usr/bin/env bash
# =============================================================================
#  VM Weaver — upload, convert, serve & write VM disk images
#  Supports: VMDK · QCOW2 · VHD · VDI · RAW · OVA · IMG · QED
#  Requires: Ubuntu 20.04+  |  License: GPL-3.0
#
#  Author  : Sam Ndirangu <sndirangu7@gmail.com>
#  GitHub  : https://github.com/SamNdirangu/VM-Weaver
#  Version : 2.0.1
#  Created : 2025
# =============================================================================

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m';  LRED='\033[1;31m'
GRN='\033[0;32m';  LGRN='\033[1;32m'
YLW='\033[1;38;5;226m';  LYLW='\033[1;33m'
BLU='\033[38;5;33m;'  LBLU='\033[1;38;5;33m'
MAG='\033[1;38;5;46m';  LMAG='\033[1;38;5;46m'
CYN='\033[1;36m';  LCYN='\033[1;36m'
WHT='\033[1;37m';  DIM='\033[2m'
BOLD='\033[1m';    RST='\033[0m'


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
    local C1='\033[38;5;226m'  # bright yellow           (row 1 - brightest)
    local C2='\033[38;5;220m'  # gold                    (row 2)
    local C3='\033[38;5;214m'  # warm orange             (row 3)
    local C4='\033[38;5;208m'  # orange                  (row 4)
    local C5='\033[38;5;202m'  # red-orange              (row 5)
    local C6='\033[38;5;196m'  # bright red              (row 6 - darkest)
    local FR='\033[0;32m'      # green frame (original dark-mode frame)
    local WB='\033[1;37m'      # bright white for WEAVER tagline
    local DM='\033[1;37m'      # bold bright white for subtitles
    local RS='\033[0m'         # reset

    echo -e "${FR}  ╔══╡ VM WEAVER ╞═══════════════════════════════════════════════════════════════╗${RS}"
    echo -e "${FR}  ║ ${C1}██╗   ██╗███╗   ███╗   ██╗    ██╗███████╗ █████╗ ██╗   ██╗███████╗██████╗    ${FR}║${RS}"
    echo -e "${FR}  ║ ${C2}██║   ██║████╗ ████║   ██║    ██║██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗   ${FR}║${RS}"
    echo -e "${FR}  ║ ${C3}██║   ██║██╔████╔██║   ██║ █╗ ██║█████╗  ███████║██║   ██║█████╗  ██████╔╝   ${FR}║${RS}"
    echo -e "${FR}  ║ ${C4}╚██╗ ██╔╝██║╚██╔╝██║   ██║███╗██║██╔══╝  ██╔══██║╚██╗ ██╔╝██╔══╝  ██╔══██╗   ${FR}║${RS}"
    echo -e "${FR}  ║ ${C5} ╚████╔╝ ██║ ╚═╝ ██║   ╚███╔███╔╝███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║   ${FR}║${RS}"
    echo -e "${FR}  ║ ${C6}  ╚═══╝  ╚═╝     ╚═╝    ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝   ${FR}║${RS}"
    echo -e "${FR}  ╠══════════════════════════════════════════════════════════════════════════════╣${RS}"
    echo -e "${FR}  ║ ${WB}      ·.·´¯·.¸¸.·´¯·.¸  ~~ W · E · A · V · E · R ~~  ¸.·´¯·.¸¸.·´¯·.·        ${FR}║${RS}"
    echo -e "${FR}  ║ ${DM}           Upload · Convert · Serve · Write VM Disk Images                   ${FR}║${RS}"
    echo -e "${FR}  ║ ${DM}           v${VERSION} · github.com/SamNdirangu/VM-Weaver                           ${FR}║${RS}"
    echo -e "${FR}  ╚══════════════════════════════════════════════════════════════════════════════╝${RS}"
    echo
}

box_line() { echo -e "${CYN}  ├──────────────────────────────────────────────────────────────────────────────┤${RST}"; }
box_top()  { echo -e "${CYN}  ╔══════════════════════════════════════════════════════════════════════════════╗${RST}"; }
box_bot()  { echo -e "${CYN}  ╚══════════════════════════════════════════════════════════════════════════════╝${RST}"; }
box_row()  { printf "${CYN}  ║${RST} %-76s ${CYN}║${RST}\n" "$1"; }

info()    { echo -e "${LCYN}  [ℹ]${RST}  $*"; }
success() { echo -e "${LGRN}  [✔]${RST}  $*"; }
warn()    { echo -e "${LYLW}  [!]${RST}  $*"; }
error()   { echo -e "${LRED}  [✘]${RST}  $*"; }
heading() { echo -e "\n${LMAG}${BOLD}  ══  $*  ══${RST}\n"; }
prompt()  { echo -en "${LYLW}  ▶  ${WHT}$*${RST} "; }

spinner() {
    local pid=$1 msg=${2:-"Working…"}
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYN}  ${frames[$i]}${RST}  ${DIM}%s${RST}" "$msg"
        i=$(( (i+1) % ${#frames[@]} ))
        sleep 0.1
    done
    printf "\r%-70s\r" " "
}

hr() { echo -e "${DIM}  ────────────────────────────────────────────────────────────────────────────────${RST}"; }
pause() { echo; prompt "Press [Enter] to continue…"; read -r; }

get_ip() {
    hostname -I 2>/dev/null | awk '{print $1}' \
        || ip route get 1 2>/dev/null | awk '{print $7;exit}' \
        || echo "127.0.0.1"
}

human_size() {
    local f="$1"
    [[ -f "$f" ]] && du -h "$f" | cut -f1 || echo "—"
}

ensure_dirs() {
    mkdir -p "$DISK_DIR" "$CONVERTED_DIR"
}

# ── Dependency installer ───────────────────────────────────────────────────────
install_deps() {
    print_banner
    heading "System Setup & Dependency Installer"

     info "This will install all required packages for VM Weaver."
    info "Packages: qemu-utils, openssh-server, python3, rsync, curl, net-tools, pv"
    echo
    prompt "Proceed with installation? [y/N]: "; read -r ans
    [[ "${ans,,}" != "y" ]] && warn "Aborted." && return

    echo
    info "Updating package list…"
    sudo apt-get update -y &>/dev/null &
    spinner $! "Updating apt package list"
    success "Package list updated."

    local packages=(qemu-utils openssh-server python3 rsync curl net-tools pv)
    for pkg in "${packages[@]}"; do
        info "Installing ${BOLD}${pkg}${RST}…"
        sudo apt-get install -y "$pkg" &>/dev/null &
        spinner $! "Installing $pkg"
        if dpkg -s "$pkg" &>/dev/null; then
            success "$pkg installed."
        else
            error "Failed to install $pkg — check your apt sources."
        fi
    done

    echo
    info "Enabling & starting SSH server…"
    sudo systemctl enable ssh &>/dev/null
    sudo systemctl start ssh &>/dev/null
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

    local SCRIPT_PATH
    SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
    local TARGET="/usr/local/bin/vm-weaver"

    info "Creating symlink: ${BOLD}${TARGET}${RST} → ${SCRIPT_PATH}"
    sudo ln -sf "$SCRIPT_PATH" "$TARGET"
    sudo chmod +x "$SCRIPT_PATH"

    if [[ -x "$TARGET" ]]; then
        success "vm-weaver is now available system-wide."
        info "Run it from anywhere with:  ${BOLD}vm-weaver${RST}"
    else
        error "Failed to install to /usr/local/bin. You may need sudo."
    fi
}

check_deps() {
    local missing=()
    command -v qemu-img &>/dev/null || missing+=(qemu-utils)
    command -v python3  &>/dev/null || missing+=(python3)
    command -v rsync    &>/dev/null || missing+=(rsync)

    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Missing packages: ${missing[*]}"
        prompt "Install now? [y/N]: "; read -r ans
        if [[ "${ans,,}" == "y" ]]; then
            sudo apt-get update -y &>/dev/null
            sudo apt-get install -y "${missing[@]}"
        fi
    else
        success "All core dependencies are present."
    fi
}

# ── Upload instructions ────────────────────────────────────────────────────────
show_upload_instructions() {
    print_banner
    heading "How to Upload VM Disk Files to This Server"

    local MY_IP; MY_IP=$(get_ip)
    local MY_USER; MY_USER=$(whoami)

    box_top
    box_row "  Supported formats: vmdk  qcow2  vhd  vdi  raw  ova  img"
    box_row "  Destination folder: $DISK_DIR"
    box_row ""
    box_row "  Server IP  : $MY_IP"
    box_row "  Username   : $MY_USER"
    box_line

    echo -e "${CYN}  ║${RST} ${LMAG}${BOLD} 1 — SFTP  (recommended)${RST}"
    box_row ""
    box_row "  sftp $MY_USER@$MY_IP"
    box_row "    sftp> cd $DISK_DIR"
    box_row "    sftp> put /local/path/disk.vmdk"
    box_row "    sftp> put /local/path/*.qcow2"
    box_row "    sftp> bye"
    box_line

    echo -e "${CYN}  ║${RST} ${LMAG}${BOLD} 2 — SCP (single file / glob)${RST}"
    box_row ""
    box_row "  scp /local/disk.vmdk $MY_USER@$MY_IP:$DISK_DIR/"
    box_row "  scp *.qcow2          $MY_USER@$MY_IP:$DISK_DIR/"
    box_line

    echo -e "${CYN}  ║${RST} ${LMAG}${BOLD} 3 — rsync (folder sync, resumable)${RST}"
    box_row ""
    box_row "  rsync -avP --progress /local/vm-folder/ \\"
    box_row "        $MY_USER@$MY_IP:$DISK_DIR/"
    box_line

    echo -e "${CYN}  ║${RST} ${LMAG}${BOLD} 4 — Windows / WinSCP GUI${RST}"
    box_row ""
    box_row "  Protocol : SFTP"
    box_row "  Host     : $MY_IP    Port: 22"
    box_row "  User     : $MY_USER"
    box_row "  Remote   : $DISK_DIR"
    box_bot

    echo
    info "Ensure SSH is running:  ${BOLD}sudo systemctl start ssh${RST}"
    info "Check open port 22:     ${BOLD}sudo ufw allow 22${RST}"
    pause
}

# ── List disk files ────────────────────────────────────────────────────────────
list_disk_files() {
    print_banner
    heading "VM Disk Files in ${DISK_DIR}"
    ensure_dirs

    mapfile -t FILES < <(find "$DISK_DIR" -maxdepth 2 -type f \
        | grep -iE "\.(${DISK_EXTENSIONS})$" | sort)

    if [[ ${#FILES[@]} -eq 0 ]]; then
        warn "No VM disk files found in ${DISK_DIR}"
        info "Upload files first — see option 1 in the main menu."
        pause; return
    fi

    printf "\n${BOLD}${CYN}  %-4s %-40s %-8s %-10s %-20s${RST}\n" \
        "#" "Filename" "Size" "Format" "Modified"
    hr
    local i=1
    for f in "${FILES[@]}"; do
        local fname; fname=$(basename "$f")
        local fsize; fsize=$(du -h "$f" 2>/dev/null | cut -f1)
        local fext;  fext="${fname##*.}"
        local fmod;  fmod=$(date -r "$f" '+%Y-%m-%d %H:%M' 2>/dev/null \
            || stat -c '%y' "$f" | cut -d' ' -f1,2 | cut -c1-16)
        printf "  ${LYLW}%-4s${RST} ${WHT}%-40s${RST} ${LGRN}%-8s${RST} ${LCYN}%-10s${RST} ${DIM}%-20s${RST}\n" \
            "$i" "${fname:0:39}" "$fsize" "${fext^^}" "$fmod"
        (( i++ ))
    done
    hr
    success "Total: $((i-1)) file(s) found."

    mapfile -t CFILES < <(find "$CONVERTED_DIR" -maxdepth 1 -type f \
        | grep -iE "\.(${DISK_EXTENSIONS})$" | sort)
    if [[ ${#CFILES[@]} -gt 0 ]]; then
        echo
        echo -e "${LMAG}  Converted files (${CONVERTED_DIR}):${RST}"
        hr
        local j=1
        for f in "${CFILES[@]}"; do
            local fname; fname=$(basename "$f")
            local fsize; fsize=$(du -h "$f" 2>/dev/null | cut -f1)
            local fext;  fext="${fname##*.}"
            printf "  ${LMAG}%-4s${RST} ${WHT}%-40s${RST} ${LGRN}%-8s${RST} ${LCYN}%-10s${RST}\n" \
                "$j" "${fname:0:39}" "$fsize" "${fext^^}"
            (( j++ ))
        done
        hr
    fi
    pause
}

# ── Convert disk image ─────────────────────────────────────────────────────────
convert_disk() {
    print_banner
    heading "Convert VM Disk Image"

    if ! command -v qemu-img &>/dev/null; then
        error "qemu-img not found. Run option 9 to install dependencies."
        pause; return
    fi

    ensure_dirs
    mapfile -t FILES < <(find "$DISK_DIR" -maxdepth 2 -type f \
        | grep -iE "\.(${DISK_EXTENSIONS})$" | sort)

    if [[ ${#FILES[@]} -eq 0 ]]; then
        warn "No source disk files found in ${DISK_DIR}"
        pause; return
    fi

    # Select source
    echo -e "${LMAG}  Select source file:${RST}\n"
    local i=1
    for f in "${FILES[@]}"; do
        local sz; sz=$(du -h "$f" | cut -f1)
        printf "  ${LYLW}[%2d]${RST}  ${WHT}%-42s${RST}  ${LGRN}%s${RST}\n" \
            "$i" "$(basename "$f")" "$sz"
        (( i++ ))
    done
    echo
    prompt "Enter file number (1-$((i-1))): "; read -r sel
    if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel >= i )); then
        error "Invalid selection."; pause; return
    fi
    local SRC="${FILES[$((sel-1))]}"
    info "Source: ${BOLD}$(basename "$SRC")${RST}  ($(du -h "$SRC" | cut -f1))"

    # Select target format
    echo
    echo -e "${LMAG}  Select output format:${RST}\n"
    local FORMATS=(qcow2 vmdk vhd vdi raw qed)
    local FMT_DESCS=("QEMU Copy-On-Write v2 (KVM/QEMU)" "VMware Disk Format" \
        "Virtual Hard Disk (Hyper-V/Azure)" "VirtualBox Disk Image" \
        "Raw disk image (max compat, bare-metal write)" "QEMU Enhanced Disk")
    for j in "${!FORMATS[@]}"; do
        printf "  ${LYLW}[%d]${RST}  ${WHT}%-10s${RST}  ${DIM}%s${RST}\n" \
            "$((j+1))" "${FORMATS[$j]}" "${FMT_DESCS[$j]}"
    done
    echo
    prompt "Enter format number (1-${#FORMATS[@]}): "; read -r fsel
    if ! [[ "$fsel" =~ ^[0-9]+$ ]] || (( fsel < 1 || fsel > ${#FORMATS[@]} )); then
        error "Invalid selection."; pause; return
    fi
    local FMT="${FORMATS[$((fsel-1))]}"
    info "Output format: ${BOLD}${FMT^^}${RST}"

    # Compression option (qcow2 only)
    local COMPRESS_FLAG=""
    if [[ "$FMT" == "qcow2" ]]; then
        prompt "Enable compression? (smaller file, slower write) [y/N]: "; read -r comp
        [[ "${comp,,}" == "y" ]] && COMPRESS_FLAG="-c"
    fi

    # RAW-specific: trim/truncate to save space
    local SPARSE_FLAG=""
    if [[ "$FMT" == "raw" ]]; then
        echo
        warn "RAW files can be very large — they represent the full virtual disk."
        echo
        echo -e "${LMAG}  Space-saving option for RAW output:${RST}\n"
        echo -e "  ${LYLW}[1]${RST}  ${WHT}Full raw image${RST}         ${DIM}Exact copy, maximum compatibility${RST}"
        echo -e "  ${LYLW}[2]${RST}  ${WHT}Sparse (thin)${RST}          ${DIM}Skips empty blocks — smaller on disk, same logical size${RST}"
        echo -e "  ${LYLW}[3]${RST}  ${WHT}Trim to used data${RST}       ${DIM}Truncate output to actual last used byte (smallest file)${RST}"
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
    local SRCBASE; SRCBASE=$(basename "${SRC%.*}")
    local OUTFILE="${CONVERTED_DIR}/${SRCBASE}.${FMT}"
    local QFMT="$FMT"; [[ "$FMT" == "vhd" ]] && QFMT="vpc"

    echo
    info "Output: ${BOLD}${OUTFILE}${RST}"
    prompt "Start conversion? [Y/n]: "; read -r go
    [[ "${go,,}" == "n" ]] && warn "Cancelled." && pause && return

    echo
    info "Converting… (this may take a while for large files)"
    hr

    local SRC_SIZE; SRC_SIZE=$(du -h "$SRC" | cut -f1)

    qemu-img convert $COMPRESS_FLAG $SPARSE_FLAG -p -O "$QFMT" "$SRC" "$OUTFILE" &
    local CONV_PID=$!
    spinner $CONV_PID "Converting ${SRCBASE} → ${FMT^^}"
    wait $CONV_PID
    local STATUS=$?

    if [[ $STATUS -eq 0 && -f "$OUTFILE" ]]; then
        # Truncate raw to last used byte if option 3 was chosen
        if [[ "$FMT" == "raw" && "${raw_opt}" == "3" ]]; then
            info "Trimming raw file to last used byte…"
            local TRIM_SIZE
            TRIM_SIZE=$(qemu-img info --output=json "$OUTFILE" 2>/dev/null \
                | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('actual-size', d.get('virtual-size', 0)))" 2>/dev/null || echo 0)
            if [[ "$TRIM_SIZE" -gt 0 ]]; then
                truncate -s "$TRIM_SIZE" "$OUTFILE" 2>/dev/null \
                    && success "Trimmed to ${TRIM_SIZE} bytes." \
                    || warn "Could not truncate — file left as-is."
            fi
        fi

        local DST_SIZE; DST_SIZE=$(du -h "$OUTFILE" | cut -f1)
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
        if [[ "$FMT" == "raw" ]]; then
            prompt "Write this image directly to a physical disk now? [y/N]: "; read -r wd
            if [[ "${wd,,}" == "y" ]]; then
                write_to_disk "$OUTFILE"
                return
            fi
        fi

        prompt "Start HTTP download server now? [Y/n]: "; read -r srv
        [[ "${srv,,}" != "n" ]] && start_http_server
    else
        error "Conversion failed! Check disk space and file permissions."
    fi
    pause
}

# ── Write image to physical disk ───────────────────────────────────────────────
write_to_disk() {
    local IMG_FILE="${1:-}"

    print_banner
    heading "Write Disk Image to Physical Disk"

    warn "This will OVERWRITE all data on the selected disk. This cannot be undone."
    echo

    # If no image passed in, let user choose one
    if [[ -z "$IMG_FILE" ]]; then
        local ALL_IMGS=()
        mapfile -t ALL_IMGS < <(find "$CONVERTED_DIR" "$DISK_DIR" -maxdepth 2 -type f \
            | grep -iE "\.(${DISK_EXTENSIONS}|raw)$" | sort -u)

        if [[ ${#ALL_IMGS[@]} -eq 0 ]]; then
            error "No disk image files found. Convert a disk first."
            pause; return
        fi

        echo -e "${LMAG}  Select image to write:${RST}\n"
        local k=1
        for f in "${ALL_IMGS[@]}"; do
            local sz; sz=$(du -h "$f" | cut -f1)
            printf "  ${LYLW}[%2d]${RST}  ${WHT}%-42s${RST}  ${LGRN}%s${RST}\n" \
                "$k" "$(basename "$f")" "$sz"
            (( k++ ))
        done
        echo
        prompt "Enter image number (1-$((k-1))): "; read -r imgsel
        if ! [[ "$imgsel" =~ ^[0-9]+$ ]] || (( imgsel < 1 || imgsel >= k )); then
            error "Invalid selection."; pause; return
        fi
        IMG_FILE="${ALL_IMGS[$((imgsel-1))]}"
    fi

    info "Image: ${BOLD}$(basename "$IMG_FILE")${RST}  ($(du -h "$IMG_FILE" | cut -f1))"
    echo

    # List physical disks — exclude loop, ram, and the root disk
    echo -e "${LMAG}  Available physical disks:${RST}\n"
    hr

    local DISKS=()
    mapfile -t DISKS < <(lsblk -dn -o NAME,SIZE,TYPE,MODEL,TRAN \
        | awk '$3=="disk" {print $0}' | grep -v '^loop')

    if [[ ${#DISKS[@]} -eq 0 ]]; then
        error "No physical disks found (you may need to run as root or with sudo)."
        pause; return
    fi

    printf "  ${BOLD}${CYN}%-4s %-10s %-8s %-6s %-30s %-6s${RST}\n" \
        "#" "Device" "Size" "Type" "Model" "Bus"
    hr
    local d=1
    local DISK_NAMES=()
    for line in "${DISKS[@]}"; do
        local dname; dname=$(echo "$line" | awk '{print $1}')
        local dsize; dsize=$(echo "$line" | awk '{print $2}')
        local dtype; dtype=$(echo "$line" | awk '{print $3}')
        local dmodel; dmodel=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | xargs)
        DISK_NAMES+=("$dname")

        # Warn if it looks like a system disk (has partitions mounted at /)
        local IS_SYS=""
        if lsblk -no MOUNTPOINT "/dev/$dname" 2>/dev/null | grep -q "^/$"; then
            IS_SYS="${LRED}[SYSTEM DISK!]${RST}"
        fi

        printf "  ${LYLW}[%2d]${RST}  ${WHT}%-10s${RST} ${LGRN}%-8s${RST} ${LCYN}%-6s${RST} ${DIM}%-30s${RST} %b\n" \
            "$d" "/dev/$dname" "$dsize" "$dtype" "${dmodel:0:29}" "$IS_SYS"
        (( d++ ))
    done
    hr
    echo
    warn "Do NOT select your system/boot disk. Look for the [SYSTEM DISK!] warning above."
    echo
    prompt "Enter disk number (1-$((d-1))): "; read -r dsel
    if ! [[ "$dsel" =~ ^[0-9]+$ ]] || (( dsel < 1 || dsel >= d )); then
        error "Invalid selection."; pause; return
    fi

    local TARGET_DISK="/dev/${DISK_NAMES[$((dsel-1))]}"

    # Double-confirm — this is destructive
    echo
    warn "You are about to write:"
    echo -e "    ${WHT}$(basename "$IMG_FILE")${RST}  →  ${LRED}${TARGET_DISK}${RST}"
    echo
    warn "ALL EXISTING DATA ON ${TARGET_DISK} WILL BE PERMANENTLY DESTROYED."
    echo
    prompt "Type YES to confirm, anything else to cancel: "; read -r confirm
    if [[ "$confirm" != "YES" ]]; then
        warn "Cancelled. Nothing was written."
        pause; return
    fi

    # Unmount any mounted partitions on the target disk
    echo
    info "Unmounting any mounted partitions on ${TARGET_DISK}…"
    local MOUNTED
    mapfile -t MOUNTED < <(lsblk -no PATH,MOUNTPOINT "/dev/${DISK_NAMES[$((dsel-1))]}" \
        | awk '$2!="" {print $1}')
    for mp in "${MOUNTED[@]}"; do
        sudo umount "$mp" 2>/dev/null && info "Unmounted $mp" || true
    done

    echo
    info "Writing image to disk…"
    info "This may take a long time depending on image size."
    hr

    local IMG_SIZE_BYTES; IMG_SIZE_BYTES=$(stat -c '%s' "$IMG_FILE" 2>/dev/null || echo 0)

    if command -v pv &>/dev/null && [[ "$IMG_SIZE_BYTES" -gt 0 ]]; then
        # Use pv for a nice progress bar
        sudo pv -pterb -s "$IMG_SIZE_BYTES" "$IMG_FILE" | sudo dd of="$TARGET_DISK" bs=4M conv=fsync 2>/dev/null &
        local WRITE_PID=$!
        wait $WRITE_PID
        local WRITE_STATUS=$?
    else
        sudo dd if="$IMG_FILE" of="$TARGET_DISK" bs=4M conv=fsync status=progress &
        local WRITE_PID=$!
        spinner $WRITE_PID "Writing $(basename "$IMG_FILE") to ${TARGET_DISK}"
        wait $WRITE_PID
        local WRITE_STATUS=$?
    fi

    echo
    if [[ $WRITE_STATUS -eq 0 ]]; then
        sudo sync
        success "Write complete!"
        hr
        printf "  ${DIM}Image  : ${RST}${WHT}%s${RST}\n" "$(basename "$IMG_FILE")"
        printf "  ${DIM}Target : ${RST}${LGRN}%s${RST}\n" "$TARGET_DISK"
        hr
        echo
        info "The disk is ready. You can now:"
        echo -e "  ${CYN}·${RST}  Detach it from this host"
        echo -e "  ${CYN}·${RST}  Attach it to another VM as a data disk"
        echo -e "  ${CYN}·${RST}  Boot from it directly on bare metal"
    else
        error "Write failed! Check dmesg or /var/log/syslog for details."
        error "dd exit code: ${WRITE_STATUS}"
    fi
    pause
}

# ── Custom Python HTTP server (pretty UI) ─────────────────────────────────────
# Writes a self-contained Python script that serves a branded dark-theme page.
write_http_server_script() {
    local SERVE_DIR="$1"
    local PORT="$2"
    local SERVER_SCRIPT="/tmp/vm_weaver_server.py"

    cat > "$SERVER_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3
import os, sys, json, mimetypes, math
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import unquote, quote

SERVE_DIR = sys.argv[1]
PORT      = int(sys.argv[2])

FORMAT_ICONS = {
    "vmdk":  ("💿", "#f97316"),
    "qcow2": ("🖥",  "#a855f7"),
    "vhd":   ("💽", "#3b82f6"),
    "vdi":   ("📦", "#06b6d4"),
    "raw":   ("🗜️",  "#22c55e"),
    "img":   ("🗜️",  "#22c55e"),
    "iso":   ("💿", "#eab308"),
    "qed":   ("⚡", "#ec4899"),
    "ova":   ("📦", "#f59e0b"),
}
DEFAULT_ICON = ("📄", "#94a3b8")

def human_size(n):
    if n == 0: return "0 B"
    units = ["B","KB","MB","GB","TB"]
    i = int(math.floor(math.log(n, 1024)))
    i = min(i, len(units)-1)
    return f"{n / (1024**i):.1f} {units[i]}"

def build_index(files, host):
    cards = ""
    for f in files:
        fname  = os.path.basename(f)
        fsize  = os.path.getsize(f)
        ext    = fname.rsplit(".", 1)[-1].lower() if "." in fname else ""
        icon, color = FORMAT_ICONS.get(ext, DEFAULT_ICON)
        encoded = quote(fname)
        url     = f"http://{host}/{encoded}"
        cards += f"""
        <div class="card">
          <div class="card-icon" style="color:{color}">{icon}</div>
          <div class="card-body">
            <div class="card-name" title="{fname}">{fname}</div>
            <div class="card-meta">
              <span class="badge" style="background:{color}22;color:{color};">{ext.upper() or "FILE"}</span>
              <span class="card-size">{human_size(fsize)}</span>
            </div>
          </div>
          <div class="card-actions">
            <a class="btn-dl" href="/{encoded}" download="{fname}">⬇ Download</a>
            <button class="btn-copy" onclick="copyLink(this)" data-url="{url}">🔗 Copy</button>
          </div>
        </div>"""

    if not cards:
        cards = '<div class="empty">No disk images found in the serve directory.</div>'

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>VM Weaver — Disk Image Server</title>
<style>
  :root {{
    --bg:      #0d0d14;
    --surface: #13131f;
    --card:    #1a1a2e;
    --border:  #2a2a45;
    --accent:  #a855f7;
    --text:    #e2e8f0;
    --muted:   #64748b;
    --green:   #22c55e;
  }}
  *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    background: var(--bg);
    color: var(--text);
    font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
    min-height: 100vh;
    padding: 2rem 1rem;
  }}
  header {{
    text-align: center;
    margin-bottom: 2.5rem;
  }}
  .logo {{
    font-size: 2.4rem;
    font-weight: 800;
    letter-spacing: 0.04em;
    background: linear-gradient(135deg, #a855f7, #3b82f6, #06b6d4);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }}
  .tagline {{
    color: var(--muted);
    font-size: 0.9rem;
    margin-top: 0.35rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }}
  .web-decoration {{
    font-size: 0.8rem;
    color: #3b3b5c;
    margin-top: 0.5rem;
    letter-spacing: 0.15em;
  }}
  .container {{
    max-width: 860px;
    margin: 0 auto;
  }}
  .section-title {{
    font-size: 0.75rem;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--muted);
    margin-bottom: 1rem;
    padding-left: 0.25rem;
  }}
  .cards {{
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }}
  .card {{
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 1.1rem 1.25rem;
    display: flex;
    align-items: center;
    gap: 1rem;
    transition: border-color 0.2s, transform 0.15s;
  }}
  .card:hover {{
    border-color: var(--accent);
    transform: translateY(-1px);
  }}
  .card-icon {{
    font-size: 2rem;
    flex-shrink: 0;
    width: 2.5rem;
    text-align: center;
  }}
  .card-body {{
    flex: 1;
    min-width: 0;
  }}
  .card-name {{
    font-weight: 600;
    font-size: 0.95rem;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    color: var(--text);
  }}
  .card-meta {{
    display: flex;
    align-items: center;
    gap: 0.6rem;
    margin-top: 0.3rem;
  }}
  .badge {{
    font-size: 0.65rem;
    font-weight: 700;
    letter-spacing: 0.08em;
    padding: 0.15rem 0.5rem;
    border-radius: 999px;
  }}
  .card-size {{
    font-size: 0.78rem;
    color: var(--muted);
  }}
  .card-actions {{
    display: flex;
    gap: 0.5rem;
    flex-shrink: 0;
  }}
  .btn-dl, .btn-copy {{
    font-size: 0.78rem;
    font-weight: 600;
    padding: 0.45rem 0.9rem;
    border-radius: 8px;
    border: none;
    cursor: pointer;
    text-decoration: none;
    transition: opacity 0.15s;
  }}
  .btn-dl {{
    background: linear-gradient(135deg, #a855f7, #3b82f6);
    color: #fff;
  }}
  .btn-copy {{
    background: var(--border);
    color: var(--text);
  }}
  .btn-dl:hover, .btn-copy:hover {{ opacity: 0.82; }}
  .btn-copy.copied {{
    background: #15803d44;
    color: var(--green);
  }}
  .empty {{
    text-align: center;
    color: var(--muted);
    padding: 3rem;
    border: 1px dashed var(--border);
    border-radius: 12px;
  }}
  footer {{
    text-align: center;
    margin-top: 3rem;
    color: var(--muted);
    font-size: 0.75rem;
    letter-spacing: 0.06em;
  }}
  footer a {{ color: var(--accent); text-decoration: none; }}
  @media (max-width: 560px) {{
    .card {{ flex-wrap: wrap; }}
    .card-actions {{ width: 100%; }}
    .btn-dl, .btn-copy {{ flex: 1; text-align: center; }}
  }}
</style>
</head>
<body>
<header>
  <div class="logo">⟨ VM Weaver ⟩</div>
  <div class="tagline">Upload · Convert · Serve · Write VM Disk Images</div>
  <div class="web-decoration">&#xB7;&#xB4;&#xAF;&#xB7;.&#xB8;&#xB8;.&#xB7;&#xB4;&#xAF;&#xB7;.&#xB8;&#xB8;.&#xB7;&#xB4;&#xAF;&#xB7;.&#xB8;&#xB8;.&#xB7;&#xB4;&#xAF;&#xB7;.&#xB8;&#xB8;.&#xB7;</div>
</header>
<div class="container">
  <div class="section-title">Available disk images</div>
  <div class="cards">
    {cards}
  </div>
</div>
<footer>
  Served by <a href="https://github.com/SamNdirangu/vm-weaver">VM Weaver</a> &nbsp;·&nbsp; {host}
</footer>
<script>
function copyLink(btn) {{
  navigator.clipboard.writeText(btn.dataset.url).then(() => {{
    btn.textContent = '✓ Copied';
    btn.classList.add('copied');
    setTimeout(() => {{ btn.textContent = '🔗 Copy'; btn.classList.remove('copied'); }}, 2000);
  }});
}}
</script>
</body>
</html>"""

class VMWeaverHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # suppress default per-request stdout noise

    def do_GET(self):
        path = unquote(self.path.lstrip("/"))

        # Root → serve the pretty index
        if path == "" or path == "/":
            self._serve_index()
            return

        # File download
        target = os.path.join(SERVE_DIR, path)
        target = os.path.realpath(target)
        # Security: must stay inside SERVE_DIR
        if not target.startswith(os.path.realpath(SERVE_DIR)):
            self._respond(403, b"Forbidden")
            return
        if not os.path.isfile(target):
            self._respond(404, b"Not found")
            return

        mime, _ = mimetypes.guess_type(target)
        mime = mime or "application/octet-stream"
        size = os.path.getsize(target)
        self.send_response(200)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(size))
        self.send_header("Content-Disposition", f'attachment; filename="{os.path.basename(target)}"')
        self.end_headers()
        with open(target, "rb") as fh:
            while True:
                chunk = fh.read(65536)
                if not chunk:
                    break
                self.wfile.write(chunk)

    def _serve_index(self):
        exts = {".vmdk",".qcow2",".vhd",".vdi",".raw",".ova",
                ".img",".iso",".parallels",".qed",".vpc"}
        files = sorted(
            [os.path.join(SERVE_DIR, f) for f in os.listdir(SERVE_DIR)
             if os.path.isfile(os.path.join(SERVE_DIR, f))
             and os.path.splitext(f)[1].lower() in exts]
        )
        host = self.headers.get("Host", f"localhost:{PORT}")
        html = build_index(files, host).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(html)))
        self.end_headers()
        self.wfile.write(html)

    def _respond(self, code, body):
        self.send_response(code)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

if __name__ == "__main__":
    os.chdir(SERVE_DIR)
    server = HTTPServer(("0.0.0.0", PORT), VMWeaverHandler)
    server.serve_forever()
PYEOF
    echo "$SERVER_SCRIPT"
}

# ── HTTP download server ───────────────────────────────────────────────────────
start_http_server() {
    print_banner
    heading "HTTP File Download Server"
    ensure_dirs

    if [[ -f "$HTTP_PID_FILE" ]]; then
        local OLD_PID; OLD_PID=$(cat "$HTTP_PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            warn "Server is already running (PID ${OLD_PID})."
            local MY_IP; MY_IP=$(get_ip)
            echo
            info "Download URL: ${BOLD}${LCYN}http://${MY_IP}:${HTTP_PORT}${RST}"
            list_download_links
            pause; return
        fi
    fi

    mapfile -t CFILES < <(find "$CONVERTED_DIR" -maxdepth 1 -type f \
        | grep -iE "\.(${DISK_EXTENSIONS})$" | sort)

    if [[ ${#CFILES[@]} -eq 0 ]]; then
        warn "No converted files found. The server will serve all files in:"
        info "${DISK_DIR}"
        local SERVE_DIR="$DISK_DIR"
    else
        local SERVE_DIR="$CONVERTED_DIR"
    fi

    if command -v ufw &>/dev/null; then
        sudo ufw allow "$HTTP_PORT/tcp" &>/dev/null && \
            success "Firewall: port ${HTTP_PORT} opened." || true
    fi

    local SERVER_SCRIPT
    SERVER_SCRIPT=$(write_http_server_script "$SERVE_DIR" "$HTTP_PORT")

    ( python3 "$SERVER_SCRIPT" "$SERVE_DIR" "$HTTP_PORT" \
        &>/tmp/vm_weaver_http.log ) &
    local SRV_PID=$!
    echo $SRV_PID > "$HTTP_PID_FILE"
    sleep 1

    if ! kill -0 "$SRV_PID" 2>/dev/null; then
        error "Server failed to start. Check /tmp/vm_weaver_http.log"
        pause; return
    fi

    local MY_IP; MY_IP=$(get_ip)
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
    local DIR="${1:-$CONVERTED_DIR}"
    local IP="${2:-$(get_ip)}"
    mapfile -t FILES < <(find "$DIR" -maxdepth 1 -type f \
        | grep -iE "\.(${DISK_EXTENSIONS})$" | sort)
    if [[ ${#FILES[@]} -gt 0 ]]; then
        echo
        echo -e "${LMAG}  Download links:${RST}"
        hr
        for f in "${FILES[@]}"; do
            local fname; fname=$(basename "$f")
            local fsz;   fsz=$(du -h "$f" | cut -f1)
            local encoded
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

    if [[ ! -f "$HTTP_PID_FILE" ]]; then
        warn "No PID file found — server may not be running."
        pause; return
    fi

    local PID; PID=$(cat "$HTTP_PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" && rm -f "$HTTP_PID_FILE"
        success "Server (PID ${PID}) stopped."
        if command -v ufw &>/dev/null; then
            sudo ufw delete allow "$HTTP_PORT/tcp" &>/dev/null && \
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
    local MY_IP; MY_IP=$(get_ip)
    if [[ -f "$HTTP_PID_FILE" ]]; then
        local PID; PID=$(cat "$HTTP_PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo -e "  HTTP Server: ${LGRN}● RUNNING${RST}  PID:${PID}  ${LBLU}http://${MY_IP}:${HTTP_PORT}${RST}"
        else
            echo -e "  HTTP Server: ${LRED}● STOPPED${RST} (stale PID file)"
        fi
    else
        echo -e "  HTTP Server: ${DIM}○ not running${RST}"
    fi
}

# ── Check / install qemu-img ───────────────────────────────────────────────────
check_qemu() {
    print_banner
    heading "Check qemu-img Installation"

    if command -v qemu-img &>/dev/null; then
        local VER; VER=$(qemu-img --version | head -1)
        success "qemu-img is installed: ${BOLD}${VER}${RST}"
        info "Supported formats:"
        echo
        qemu-img --help 2>&1 | grep -A2 'Supported formats' | tail -1 | \
            fold -s -w 70 | sed 's/^/    /'
    else
        error "qemu-img not found."
        prompt "Install qemu-utils now? [y/N]: "; read -r ans
        if [[ "${ans,,}" == "y" ]]; then
            sudo apt-get update -y &>/dev/null &
            spinner $! "Updating apt"
            sudo apt-get install -y qemu-utils
            success "qemu-utils installed."
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
                if [[ -f "$HTTP_PID_FILE" ]]; then
                    local PID; PID=$(cat "$HTTP_PID_FILE")
                    kill -0 "$PID" 2>/dev/null && \
                        warn "HTTP server (PID ${PID}) is still running in the background."
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
        echo -e "${LMAG}  VM Weaver v${VERSION}${RST} — VM Disk Image Manager"
        echo
        echo -e "  ${BOLD}Usage:${RST} vm-weaver [option]"
        echo
        echo -e "  ${LYLW}--install,  -i${RST}    Run first-time setup & register globally"
        echo -e "  ${LYLW}--check,    -c${RST}    Check qemu-img installation"
        echo -e "  ${LYLW}--serve,    -s${RST}    Start HTTP download server"
        echo -e "  ${LYLW}--write,    -w${RST}    Write an image directly to a physical disk"
        echo -e "  ${LYLW}--convert,  -C${RST}    Convert a disk image"
        echo -e "  ${LYLW}--help,     -h${RST}    Show this help"
        echo -e "  ${DIM}(no args)${RST}         Launch interactive menu"
        echo
        exit 0
        ;;
esac

main_menu