#!/usr/bin/env bash
# =============================================================================
#  VM Disk Manager — upload, convert & serve VMDK/QCOW2/VHD/VDI/RAW images
#  Requires: Ubuntu 20.04+
# =============================================================================

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m';  LRED='\033[1;31m'
GRN='\033[0;32m';  LGRN='\033[1;32m'
YLW='\033[0;33m';  LYLW='\033[1;33m'
BLU='\033[0;34m';  LBLU='\033[1;34m'
MAG='\033[0;35m';  LMAG='\033[1;35m'
CYN='\033[0;36m';  LCYN='\033[1;36m'
WHT='\033[1;37m';  DIM='\033[2m'
BOLD='\033[1m';    RST='\033[0m'

# ── Config ────────────────────────────────────────────────────────────────────
DISK_DIR="${VM_DISK_DIR:-$HOME/vm_disks}"
CONVERTED_DIR="${DISK_DIR}/converted"
HTTP_PORT="${HTTP_PORT:-8080}"
HTTP_PID_FILE="/tmp/vm_disk_http_server.pid"
DISK_EXTENSIONS="vmdk|qcow2|vhd|vdi|raw|ova|img|iso|parallels|qed|vpc"

# ── Helpers ───────────────────────────────────────────────────────────────────
print_banner() {
    clear
    echo -e "${LMAG}"
    echo '  ╔══════════════════════════════════════════════════════════════╗'
    echo '  ║                                                              ║'
    echo '  ║    ██╗   ██╗███╗   ███╗    ██████╗ ██╗███████╗██╗  ██╗     ║'
    echo '  ║    ██║   ██║████╗ ████║    ██╔══██╗██║██╔════╝██║ ██╔╝     ║'
    echo '  ║    ██║   ██║██╔████╔██║    ██║  ██║██║███████╗█████╔╝      ║'
    echo '  ║    ╚██╗ ██╔╝██║╚██╔╝██║    ██║  ██║██║╚════██║██╔═██╗      ║'
    echo '  ║     ╚████╔╝ ██║ ╚═╝ ██║    ██████╔╝██║███████║██║  ██╗     ║'
    echo '  ║      ╚═══╝  ╚═╝     ╚═╝    ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝    ║'
    echo '  ║                                                              ║'
    echo '  ║              M A N A G E R   v1.0                           ║'
    echo '  ║        Upload · Convert · Serve VM Disk Images              ║'
    echo '  ╚══════════════════════════════════════════════════════════════╝'
    echo -e "${RST}"
}

box_line() { echo -e "${CYN}  ├──────────────────────────────────────────────────────────────┤${RST}"; }
box_top()  { echo -e "${CYN}  ╔══════════════════════════════════════════════════════════════╗${RST}"; }
box_bot()  { echo -e "${CYN}  ╚══════════════════════════════════════════════════════════════╝${RST}"; }
box_row()  { printf "${CYN}  ║${RST} %-62s ${CYN}║${RST}\n" "$1"; }

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
    printf "\r%-60s\r" " "
}

hr() { echo -e "${DIM}  ──────────────────────────────────────────────────────────────${RST}"; }

pause() { echo; prompt "Press [Enter] to continue…"; read -r; }

get_ip() {
    hostname -I 2>/dev/null | awk '{print $1}' || ip route get 1 2>/dev/null | awk '{print $7;exit}' || echo "127.0.0.1"
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

    info "This will install all required packages for VM Disk Manager."
    info "Packages: qemu-utils, openssh-server, python3, rsync, curl, net-tools"
    echo
    prompt "Proceed with installation? [y/N]: "; read -r ans
    [[ "${ans,,}" != "y" ]] && warn "Aborted." && return

    echo
    info "Updating package list…"
    sudo apt-get update -y &>/dev/null &
    spinner $! "Updating apt package list"
    success "Package list updated."

    local packages=(qemu-utils openssh-server python3 rsync curl net-tools)
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

    echo
    success "All dependencies installed and services configured."
    pause
}

check_deps() {
    local missing=()
    command -v qemu-img &>/dev/null  || missing+=(qemu-utils)
    command -v python3  &>/dev/null  || missing+=(python3)
    command -v rsync    &>/dev/null  || missing+=(rsync)

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

    printf "\n${BOLD}${CYN}  %-4s %-38s %-8s %-10s %-20s${RST}\n" \
        "#" "Filename" "Size" "Format" "Modified"
    hr
    local i=1
    for f in "${FILES[@]}"; do
        local fname; fname=$(basename "$f")
        local fsize; fsize=$(du -h "$f" 2>/dev/null | cut -f1)
        local fext;  fext="${fname##*.}"
        local fmod;  fmod=$(date -r "$f" '+%Y-%m-%d %H:%M' 2>/dev/null || stat -c '%y' "$f" | cut -d' ' -f1,2 | cut -c1-16)
        printf "  ${LYLW}%-4s${RST} ${WHT}%-38s${RST} ${LGRN}%-8s${RST} ${LCYN}%-10s${RST} ${DIM}%-20s${RST}\n" \
            "$i" "${fname:0:37}" "$fsize" "${fext^^}" "$fmod"
        (( i++ ))
    done
    hr
    success "Total: $((i-1)) file(s) found."

    # Also list converted files
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
            printf "  ${LMAG}%-4s${RST} ${WHT}%-38s${RST} ${LGRN}%-8s${RST} ${LCYN}%-10s${RST}\n" \
                "$j" "${fname:0:37}" "$fsize" "${fext^^}"
            (( j++ ))
        done
        hr
    fi
    pause
}

# ── Convert disk image ─────────────────────────────────────────────────────────
convert_disk() {
    print_banner
    heading "Convert VM Disk Image with qemu-img"

    if ! command -v qemu-img &>/dev/null; then
        error "qemu-img not found. Run option 7 to install dependencies."
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
        printf "  ${LYLW}[%2d]${RST}  ${WHT}%-40s${RST}  ${LGRN}%s${RST}\n" \
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
        "Raw disk image (max compat)" "QEMU Enhanced Disk")
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

    # Compression option (qcow2 supports it natively)
    local COMPRESS_FLAG=""
    if [[ "$FMT" == "qcow2" ]]; then
        prompt "Enable compression? (smaller file, slower write) [y/N]: "; read -r comp
        [[ "${comp,,}" == "y" ]] && COMPRESS_FLAG="-c"
    fi

    # Output filename
    local SRCBASE; SRCBASE=$(basename "${SRC%.*}")
    local OUTFILE="${CONVERTED_DIR}/${SRCBASE}.${FMT}"
    # vhd uses vpc internally
    local QFMT="$FMT"; [[ "$FMT" == "vhd" ]] && QFMT="vpc"

    echo
    info "Output: ${BOLD}${OUTFILE}${RST}"
    prompt "Start conversion? [Y/n]: "; read -r go
    [[ "${go,,}" == "n" ]] && warn "Cancelled." && pause && return

    echo
    info "Converting… (this may take a while for large files)"
    hr

    local SRC_SIZE; SRC_SIZE=$(du -h "$SRC" | cut -f1)

    # Run qemu-img in background for spinner
    qemu-img convert $COMPRESS_FLAG -p -O "$QFMT" "$SRC" "$OUTFILE" &
    local CONV_PID=$!
    spinner $CONV_PID "Converting ${SRCBASE} → ${FMT^^}"
    wait $CONV_PID
    local STATUS=$?

    if [[ $STATUS -eq 0 && -f "$OUTFILE" ]]; then
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
        prompt "Start HTTP download server now? [Y/n]: "; read -r srv
        [[ "${srv,,}" != "n" ]] && start_http_server
    else
        error "Conversion failed! Check disk space and file permissions."
    fi
    pause
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
        # Also allow serving all disk files if no converted ones exist
        warn "No converted files found. The server will serve all files in:"
        info "${DISK_DIR}"
        local SERVE_DIR="$DISK_DIR"
    else
        local SERVE_DIR="$CONVERTED_DIR"
    fi

    # Open firewall port
    if command -v ufw &>/dev/null; then
        sudo ufw allow "$HTTP_PORT/tcp" &>/dev/null && \
            success "Firewall: port ${HTTP_PORT} opened." || true
    fi

    # Start server
    ( cd "$SERVE_DIR" && python3 -m http.server "$HTTP_PORT" \
        --bind 0.0.0.0 &>/tmp/vm_disk_http.log ) &
    local SRV_PID=$!
    echo $SRV_PID > "$HTTP_PID_FILE"
    sleep 1

    if ! kill -0 "$SRV_PID" 2>/dev/null; then
        error "Server failed to start. Check /tmp/vm_disk_http.log"
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
    box_row "  Log:       /tmp/vm_disk_http.log"
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
            local encoded; encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$fname'))" 2>/dev/null || echo "$fname")
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
        # Close firewall port
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
        box_row "  3 ›  Convert a disk image (qemu-img)"
        box_row "  4 ›  Start HTTP download server"
        box_row "  5 ›  Stop HTTP download server"
        box_row "  6 ›  Show download links"
        box_row "  7 ›  Check / install qemu-img"
        box_row "  8 ›  Install all dependencies (first-time setup)"
        box_row "  9 ›  Exit"
        box_bot
        echo
        prompt "Choose an option [1-9]: "; read -r CHOICE

        case "$CHOICE" in
            1) show_upload_instructions ;;
            2) list_disk_files ;;
            3) convert_disk ;;
            4) start_http_server ;;
            5) stop_http_server ;;
            6) print_banner; heading "Download Links"; list_download_links; pause ;;
            7) check_qemu ;;
            8) install_deps ;;
            9)
                echo
                success "Goodbye!"
                if [[ -f "$HTTP_PID_FILE" ]]; then
                    local PID; PID=$(cat "$HTTP_PID_FILE")
                    kill -0 "$PID" 2>/dev/null && \
                        warn "HTTP server (PID ${PID}) is still running in the background."
                fi
                echo
                exit 0
                ;;
            *)
                error "Invalid option. Please choose 1–9."
                sleep 1
                ;;
        esac
    done
}

# ── Entry point ───────────────────────────────────────────────────────────────
ensure_dirs

# Handle CLI flags
case "${1:-}" in
    --install|-i)  install_deps; exit 0 ;;
    --check|-c)    check_qemu;   exit 0 ;;
    --serve|-s)    start_http_server; exit 0 ;;
    --help|-h)
        echo "Usage: $0 [--install|-i] [--check|-c] [--serve|-s] [--help|-h]"
        echo "  --install / -i   Run first-time dependency installer"
        echo "  --check  / -c   Check qemu-img installation"
        echo "  --serve  / -s   Start HTTP download server immediately"
        echo "  (no args)        Launch interactive menu"
        exit 0
        ;;
esac

main_menu
