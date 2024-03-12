#!/bin/bash
clear

RESET="\033[0m"
RED="\033[0;31m"
BOLD_RED="\033[1;31m"
CYAN="\033[0;96m"
BOLD_CYAN="\033[1;96m"
LIME="\033[0;92m"
BOLD_LIME="\033[1;92m"
YELLOW="\033[0;33m"
BOLD_YELLOW="\033[1;33m"

log_error() {
    local message="$1"
    local is_fatal="${2:-0}"
    if [ "$is_fatal" == "1" ]; then
        printf "${BOLD_RED}(fatal)${RED} %s${RESET}\n" "$message"
        exit 1
    else
        printf "${BOLD_RED}(error)${RED} %s${RESET}\n" "$message"
    fi
}

log_warn() {
    printf "${BOLD_YELLOW}(warn)${YELLOW} %s${RESET}\n" "$1"
}

log_info() {
    printf "${BOLD_CYAN}(info)${CYAN} %s${RESET}\n" "$1"
}

log_success() {
    local message="$1"
    local is_sub="${2:-0}"
    if [ "$is_sub" == "1" ]; then
        printf "          ${LIME}%s${RESET}\n" "$message"
    else
        printf "${BOLD_LIME}(success)${LIME} %s${RESET}\n" "$message"
    fi
}

copy_to_clipboard() {
    local clipboard_command=""
    if [ "$XDG_SESSION_TYPE" != "wayland" ]; then
        clipboard_command="xclip -selection c"
        [ -x "$(command -v xclip)" ] || log_warn "xclip is not installed, please copy content manually."
    else
        clipboard_command="wl-copy"
        [ -x "$(command -v wl-copy)" ] || log_warn "wl-clipboard is not installed, please copy content manually."
    fi

    if [ -n "$clipboard_command" ]; then
        printf "%s" "$1" | $clipboard_command
        log_success "Copied to clipboard!"
    fi
}

prompt_steam_path() {
    printf "\n"
    read -r -p "Please enter your Steam path: " steam_path
}

find_steam_path() {
    local possible_path
    if [ -f "$HOME/.steampid" ]; then
        local steam_pid=$(<"$HOME/.steampid")
        log_info "Steam PID: $steam_pid"
        possible_path=$(readlink -e "/proc/$steam_pid/cwd")
    fi

    if [ ! -d "$possible_path" ]; then
        log_warn "Steam is not running, couldn't find directory from process."
        log_info "Searching manually, this can take a few seconds..."

        if command -v fd &>/dev/null; then
            log_info "found fd, using it instead of find"
            possible_path=$(fd -a -s -H 'steamapps' --base-directory ~ | grep 'steamapps$\|steamapps/$')
        else
            possible_path=$(find ~ -path '*/.cache*' -prune -o -name 'steamapps' -print 2>/dev/null)
        fi

        possible_path=$(printf "%s" "${possible_path}" | grep -v 'compatdata\|Program Files (x86)/Steam')
        possible_path=$(printf "%s" "${possible_path}" | head -n1 | sed 's/steamapps//g; s/\/\/$/\//g')
    fi

    printf "%s" "$possible_path"
}

find_proton_directory() {
    local config_file="${steam_path}/steamapps/compatdata/322170/config_info"
    local found=false
    local proton_dir

    while IFS= read -r line; do
        local temp_dir="$line"
        declare -A visited_paths

        while [[ "$temp_dir" != "/" ]] && [[ "$temp_dir" != "~/" ]]; do
            [[ -n ${visited_paths["$temp_dir"]} ]] && break
            visited_paths["$temp_dir"]=1

            local current_directory=$(dirname "$temp_dir")
            if [[ "$current_directory" =~ .*/steamapps/common$ ]] || [[ "$current_directory" =~ .*/compatibilitytools.d$ ]]; then
                if [[ -f "$temp_dir/proton" ]]; then
                    proton_dir="$temp_dir"
                    found=true
                    break
                fi
            fi
            temp_dir="$current_directory"
        done
    done < "$config_file"

    if [[ "$found" == true ]]; then
        printf "%s" "$proton_dir"
    else
        log_error "Could not find Proton directory within config: $config_file" 1
    fi
}

log_info "Mega Hack Installer for Linux"

[ "$DEBUG" == "1" ] && log_info "Debug logging enabled!"

missing_packages=false
command -v unzip &>/dev/null || { log_error "unzip is not installed!" 1; missing_packages=true; }
if [ "$XDG_SESSION_TYPE" != "wayland" ] && ! command -v xclip &>/dev/null; then
    log_warn "xclip is not installed, you will have to manually copy the Mega Hack path!"
fi
if [ "$XDG_SESSION_TYPE" == "wayland" ] && ! command -v wl-copy &>/dev/null; then
    log_warn "wl-clipboard is not installed, you will have to manually copy the Mega Hack path!"
fi

if "$missing_packages"; then
    log_error "You are missing some programs. Please install them using your distro's package manager to continue."
    exit 1
fi

use_v6_libcurl=0
if [ "$download_tool_missing" == "true" ]; then
    log_warn "You are missing a download tool (curl or wget) and will therefore be unable to use the deprecated v6 libcurl.dll method."
    use_v6_libcurl=0
else
    log_warn "If you want to install Mega Hack v7, you will either have to use MHv6's libcurl.dll OR use the newer Xinput9_1_0 method."
    log_warn "Do you want to use the DEPRECATED v6 libcurl.dll method?"
    read -r -p "[y/n] :" answer_libcurl
    if [ "${answer_libcurl,,}" == "y" ]; then
        use_v6_libcurl=1
    fi
fi

steam_path=""
possible_path=$(find_steam_path)
if [ -n "$possible_path" ]; then
    log_info "Is this your Steam path?: $possible_path"
    read -r -p "[y/n] :" answer
    if [ "${answer,,}" == "y" ] || [ "${answer}" == "" ]; then
        steam_path="$possible_path"
    fi
    if [ "${answer,,}" == "n" ]; then
        prompt_steam_path
    fi
else
    prompt_steam_path
fi

steam_path=${steam_path%/}
log_info "Using Steam path: ${steam_path}"

proton_dir=$(find_proton_directory)
log_success "Proton directory found: $proton_dir"

rm -rf "/tmp/megahack" 2>/dev/null
mkdir "/tmp/megahack" 2>/dev/null

log_info "Extracting Mega Hack patcher..."
if [[ $megahack_zip == *.zip ]]; then
    unzip "$megahack_zip" -d /tmp/megahack
else
    log_error "Unsupported file type - are you sure you're selecting a .zip file?" 1
fi

megahack_dir=$(ls /tmp/megahack)
[ "$DEBUG" == "1" ] && log_info "Mega Hack Directory: $megahack_dir"

megahack_dir="/tmp/megahack/$megahack_dir"
megahack_dir_contents=$(ls "$megahack_dir")
[ "$DEBUG" == "1" ] && log_info "Mega Hack Directory: $megahack_dir, Contents: $megahack_dir_contents"

megahack_exe=$(printf "%s" "$megahack_dir_contents" | grep ".exe")
if [ -z "$megahack_exe" ]; then
    log_error "There's no executable in the provided zip file!" 1
fi

log_success "Extracted Mega Hack"
log_info "Directory: $megahack_dir"
log_info "Installer Executable: $megahack_exe"
printf "\n"

log_info "Starting installation process..."

cd "${steam_path}/steamapps/compatdata/322170/pfx" || { log_error "Failed to change directory" 1; }

log_info "Starting Mega Hack installer..."
printf "\n"
log_info "To install, press CTRL+V when you are in the .exe selection window and click \"Open\"."

gd_exe_path=$(printf "Z:${steam_path}/steamapps/common/Geometry Dash/GeometryDash.exe" | sed 's:/:\\:g')
log_info "Path to GD exe: ${gd_exe_path}"
copy_to_clipboard "$gd_exe_path"
printf "\n"

if [ "$use_v6_libcurl" == "1" ]; then
    log_info "Using v6's libcurl.dll to load."
    log_info "Downloading v6 libcurl.dll..."
    cd "${steam_path}/steamapps/common/Geometry Dash" || { log_error "Failed to change directory" 1; }
    if command -v curl &>/dev/null; then
        curl -s -o "/tmp/megahack/libcurl.dll" "https://raw.githubusercontent.com/RoootTheFox/Linux-MegaHack-Installer/main/libcurl.dll"
    else
        wget -qO "/tmp/megahack/libcurl.dll" "https://raw.githubusercontent.com/RoootTheFox/Linux-MegaHack-Installer/main/libcurl.dll"
    fi
    cp "/tmp/megahack/libcurl.dll" .
    mv hackproldr.dll absoluteldr.dll
else
    log_info "Using Xinput9_1_0 method."
    log_info "To use Xinput9_1_0 method, add this launch argument to Geometry Dash in the Steam launch options:"
    log_info "WINEDLLOVERRIDES=\"Xinput9_1_0=n,b\" %command%"
    copy_to_clipboard "WINEDLLOVERRIDES=\"Xinput9_1_0=n,b\" %command%"
fi

printf "\n"
log_info "Cleaning up..."
rm -rf "/tmp/megahack" 2>/dev/null
printf "\n"
log_success "If you followed the steps in the installer, Mega Hack should now be installed!"
log_success "Have fun!"
printf "\n"

sleep 0.2
exit 0
