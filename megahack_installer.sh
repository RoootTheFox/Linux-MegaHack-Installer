#!/bin/bash
clear

# colors :3
RESET="\033[0m"
RED="\033[0;31m"
BOLD_RED="\033[1;31m"
CYAN="\033[0;96m"
BOLD_CYAN="\033[1;96m"
LIME="\033[0;92m"
BOLD_LIME="\033[1;92m"
YELLOW="\033[0;33m"
BOLD_YELLOW="\033[1;33m"

# logging functions
error() {
    if [ "$2" == "1" ]; then
        printf "        ${RED}%s${RESET}\n" "$1"
    else
        printf "${BOLD_RED}(error)${RED} %s${RESET}\n" "$1"
    fi
}

fatal() {
    if [ "$2" == "1" ]; then
        printf "        ${RED}%s${RESET}\n" "$1"
    else
        printf "${BOLD_RED}(fatal)${RED} %s${RESET}\n" "$1"
    fi
    exit 1
}

warn() { printf "${BOLD_YELLOW}(warn)${YELLOW} %s${RESET}\n" "$1"; }

info() { printf "${BOLD_CYAN}(info)${CYAN} %s${RESET}\n" "$1"; }

cd_fail() {
    error "failed to change directory - line $(caller)"
    exit 1
}

success() {
    if [ "$2" == "1" ]; then
        printf "          ${LIME}%s${RESET}\n" "$1"
    else
        printf "${BOLD_LIME}(success)${LIME} %s${RESET}\n" "$1"
    fi
}

function copy_to_clipboard() {
    CLIPBOARD_COMMAND=""
    if [ "$XDG_SESSION_TYPE" != "wayland" ]; then
        if [ -x "$(command -v xclip)" ]; then
            CLIPBOARD_COMMAND="xclip -selection c"
	    else
            warn "xclip is not installed, please copy content manually"
	    fi
    else
        if [ -x "$(command -v wl-copy)" ]; then
            CLIPBOARD_COMMAND="wl-copy"
	    else
            warn "wl-clipboard is not installed, please copy content manually"
        fi
    fi

    if [ -n "$CLIPBOARD_COMMAND" ]; then
        printf "%s" "$1" | $CLIPBOARD_COMMAND
        success "Copied to clipboard!"
    fi
}

printf "${LIME}%s${RESET}\n" "MegaHack Installer for Linux"

if [ "$DEBUG" == "1" ]; then
    info "Debug logging enabled!"
fi

# check for required packages
missing_packages=false
download_tool_missing=false
if [ ! -x "$(command -v wget)" ] && [ ! -x "$(command -v curl)" ]; then
    download_tool_missing=true

    warn "neither wget nor curl are installed!"
    warn "you will be unable to use the deprecated v6 libcurl.dll method!"
    warn "note that this method is deprecated and will be removed in the future"
    info "The newer Xinput9_1_0 method requires you to add a start argument"
    info "to Geometry Dash, which will be explained later."
    info "(you can ignore this warning if you want to use the newer Xinput9_1_0 method)"
    warn "do you want to continue?"

    read -r -p "[Y/n] :" answer
    if [ "${answer,,}" != "y" ] && [ "${answer}" != "" ]; then
        info "please install either curl or wget to continue"
        exit 0
    fi
fi

[ ! -x "$(command -v unzip)" ] && error "unzip is not installed!" && missing_packages=true
if [ "$XDG_SESSION_TYPE" != "wayland" ]; then
    [ ! -x "$(command -v xclip)" ] && warn "xclip is not installed, you will have to manually copy the MegaHack path!"
else
    [ ! -x "$(command -v wl-copy)" ] && warn "wl-clipboard is not installed, you will have to manually copy the MegaHack path!"
fi

printf "\n"
if [ $missing_packages == true ]; then
    error "You are missing some programs."
    error "Please install them using your distro's package manager to continue."
    error "Additional information can be found above."
    exit 0
fi

# if fzf is installed, use it
if [ -x "$(command -v fzf)" ]; then
    pushd ~ || cd_fail # we want fzf to use the home directory

    if [ "$(command -v fd)" ]; then
        export FZF_DEFAULT_COMMAND="fd --extension=zip"
    else
        export FZF_DEFAULT_COMMAND="find . -path '*/.*' -prune -o -iname '*.zip' -print"
    fi

    megahack_zip="$(fzf -e --header="MegaHack Installer.zip selection" --prompt="Please enter the path to your MegaHack .zip file: ")"
    megahack_zip="$(realpath "$megahack_zip")"
    popd || cd_fail
else
    info "Please enter the path to your MegaHack .zip file"
    info "(most terminals support drag and drop)"
    read -r -p "> " megahack_zip
fi

printf "\n"
[ ! -f "$megahack_zip" ] && fatal "Could not find the file you specified!"

megahack_zip="$(realpath "$megahack_zip")"

printf "Finding your steam path ...\n"
if [ -f "$HOME/.steampid" ]; then
    steam_pid=$(cat "$HOME/.steampid")
    info "Steam PID: $steam_pid"
    possible_path=$(readlink -e "/proc/$steam_pid/cwd")
fi

if [ ! -d "$possible_path" ]; then
    warn "Steam is not running, couldn't find directory from process"
    warn "Searching manually, this can take a few seconds ..."

    if [ -x "$(command -v fd)" ]; then
        info "found fd, using it instead of find"
        possible_paths=$(fd -a -s -H 'steamapps' --base-directory ~ | grep 'steamapps$\|steamapps/$')
    else
        possible_paths=$(find ~ -path '*/.cache*' -prune -o -name 'steamapps' -print 2>/dev/null)
    fi

    possible_paths=$(printf "%s" "${possible_paths}" | grep -v 'compatdata\|Program Files (x86)/Steam')
    possible_path=$(printf "%s" "${possible_paths}" | head -n1 | sed 's/steamapps//g; s/\/\/$/\//g')
fi

function prompt_steam_path() {
    printf "\n"
    read -r -p "Please enter your Steam path: " in_path
    steam_path="$in_path"
}

steam_path=""
if [ -n "$possible_path" ]; then
    printf "Is this your Steam path?: %s\n\n" "${possible_path}"
    read -r -p "[Y/n] :" answer
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
info "Using Steam path: ${steam_path}"

# find proton version
config_file="${steam_path}/steamapps/compatdata/322170/config_info"
found=false

while IFS= read -r line; do
    temp_dir="$line"
    declare -A visited_paths

    while [[ "$temp_dir" != "/" ]] && [[ "$temp_dir" != "~/" ]]; do
        [[ -n ${visited_paths["$temp_dir"]} ]] && break # catch other loops
        visited_paths["$temp_dir"]=1

        current_directory=$(dirname "$temp_dir")
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
    success "Proton directory found: $proton_dir"
else
    fatal "Could not find Proton directory within config: $config_file"
fi

info "Using Proton: ${proton_dir}"

# clear temporary files
rm -rf "/tmp/megahack" 2>/dev/null
mkdir "/tmp/megahack" 2>/dev/null

info "Extracting MegaHack Patcher ..."
info "$megahack_zip"
if [[ $megahack_zip == *.zip ]]; then
    unzip "$megahack_zip" -d /tmp/megahack
else
    fatal "unsupported file type - are you sure you're selecting a .zip file?"
fi

# find out where megahack is
megahack_dir=$(ls /tmp/megahack)
if [ "$DEBUG" == "1" ]; then
    printf "-- contents of /tmp/megahack --\n"
    printf "%s\n" "$megahack_dir"
    printf "-- -- -- -- -- - -- -- -- -- --\n"
fi

megahack_dir="/tmp/megahack/$megahack_dir"

megahack_dir_contents=$(ls "$megahack_dir")

if [ "$DEBUG" == "1" ]; then
    printf "MegaHack Directory: %s\n" "$megahack_dir"
    printf " -- Contents --\n"
    printf "%s\n" "$megahack_dir_contents"
    printf " -- -- -- -- --\n"
fi

megahack_exe=$(printf "%s" "$megahack_dir_contents" | grep ".exe")

if [ -z "$megahack_exe" ]; then
    fatal "there's no executable in the provided zip file!"
fi

success "Extracted MegaHack"
info "Directory: $megahack_dir"
info "Installer Executable: $megahack_exe"
printf "\n"

info " - Starting installation process - "

[ "$DEBUG" == "1" ] && printf "cd %s\n" "${steam_path}/steamapps/compatdata/322170/pfx"
cd "${steam_path}/steamapps/compatdata/322170/pfx" || cd_fail

info "Starting MegaHack installer ..."
printf "\n"
info "To install, press CTRL+V when you are in the exe selection window and click \"Open\""

# copy path to gd exe
gd_exe_path=$(printf "%s" "Z:${steam_path}/steamapps/common/Geometry Dash/GeometryDash.exe" | sed 's:/:\\:g')

info "Path to GD exe: ${gd_exe_path}"

copy_to_clipboard "$gd_exe_path"

printf "\n"

function print_xinput_instructions() {
    info "to use to Xinput9_1_0 method, you will have to add a launch argument"
    info "to Geometry Dash in the Steam launch options."
    info "To do this, right-click Geometry Dash in your Steam library and"
    info "click 'Properties'. A window will open, with a text box labeled"
    info "'Launch Options' (under 'General') Copy the following into the text box:"
    info "WINEDLLOVERRIDES=\"Xinput9_1_0=n,b\" %command%"
}

if [ "$download_tool_missing" == "true" ]; then
    info "you are missing a download tool (curl or wget)"
    info "and will therefore be unable to use the deprecated v6 libcurl.dll method"
    print_xinput_instructions
    use_v6_libcurl=0
else
    warn "If you want to install MegaHack v7, you will either have to"
    warn "use MHv6's libcurl.dll OR use the newer Xinput9_1_0 method,"
    warn "which requires you to add a start argument to GD."
    warn "It is recommended to use the newer Xinput9_1_0 method:"
    print_xinput_instructions

    warn "Do you want to use the DEPRECATED v6 libcurl.dll method?"
    read -r -p "[y/N] :" answer_libcurl
    if [ "${answer_libcurl,,}" == "y" ]; then
        use_v6_libcurl=1
    fi
fi

if [ "$DEBUG" == "1" ]; then
    printf "Starting MegaHack:\n"
    printf "STEAM_COMPAT_DATA_PATH=\"%s\" WINEPREFIX=\"%s\" \"%s\" runinprefix \"%s\"\n" "${steam_path}/steamapps/compatdata/322170" "$PWD" "${proton_dir}/proton" "${megahack_dir}/${megahack_exe}"
fi

STEAM_COMPAT_DATA_PATH="${steam_path}/steamapps/compatdata/322170" WINEPREFIX="$PWD" "${proton_dir}/proton" runinprefix "${megahack_dir}/${megahack_exe}"

if [ "$use_v6_libcurl" == "1" ]; then
    warn "using v6's libcurl.dll to load!"
    # this allows megahack v7 to load
    cd "${steam_path}/steamapps/common/Geometry Dash" || cd_fail
    rm libcurl.dll
    info "Downloading v6 libcurl.dll"
    if [ -x "$(command -v curl)" ]; then
        curl -s -o "/tmp/megahack/libcurl.dll" "https://raw.githubusercontent.com/RoootTheFox/Linux-MegaHack-Installer/main/libcurl.dll"
    else
        wget -qO "/tmp/megahack/libcurl.dll" "https://raw.githubusercontent.com/RoootTheFox/Linux-MegaHack-Installer/main/libcurl.dll"
    fi
    cp "/tmp/megahack/libcurl.dll" .
    mv hackproldr.dll absoluteldr.dll
else
    info "using Xinput9_1_0 method"
    print_xinput_instructions
    copy_to_clipboard "WINEDLLOVERRIDES=\"Xinput9_1_0=n,b\" %command%"
fi

printf "\n"
info "Cleaning up ..."
rm -rf "/tmp/megahack" 2>/dev/null
printf "\n"
success "If you followed the steps in the installer, MegaHack Pro should now be installed!"
success "Have fun!" 1
printf "\n"

sleep 0.2
exit 0
