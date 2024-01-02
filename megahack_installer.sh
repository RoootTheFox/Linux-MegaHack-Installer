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

printf "${LIME}%s${RESET}\n" "MegaHack Installer for Linux"

if [ "$DEBUG" == "1" ]; then
   info "Debug logging enabled!"
fi

# check for required packages
missing_packages=false
if ! hash unzip 2>/dev/null; then error "unzip is not installed!"; missing_packages=true; fi
if ! hash xclip 2>/dev/null; then warn "xclip is not installed, you will have to manually copy the MegaHack path!"; fi

echo
if [ $missing_packages == true ] ; then
   error "You are missing some programs."
   error "Please install them using your distro's package manager to continue."
   error "Additional information can be found above."
   exit 0
fi

# if fzf is installed, use it
if hash fzf 2>/dev/null; then
    pdir=$(pwd)
    cd ~ || cd_fail # we want fzf to use the home directory

    if hash fd 2>/dev/null; then
        export FZF_DEFAULT_COMMAND="fd --extension=zip"
    else
        export FZF_DEFAULT_COMMAND="find . -iname '*.zip'"
    fi

    megahack_zip=$(fzf -e --header="MegaHack Installer.zip selection" --prompt="Please enter the path to your MegaHack .zip file: ")
    megahack_zip=$(realpath "$megahack_zip")
    cd "$pdir" || cd_fail
else
    info "Please enter the path to your MegaHack .zip file"
    info "(most terminals support drag and drop)"
    read -p "> " megahack_zip
fi

echo
if ! [ -f "$megahack_zip" ]; then
   fatal "Could not find the file you specified!"
fi

megahack_zip=$(realpath "$megahack_zip")

echo "Finding your steam path ..."
if [ -f "$HOME/.steampid" ]; then
   steam_pid=$(cat "$HOME/.steampid")
   info "Steam PID: $steam_pid"
   possible_path=$(readlink -e "/proc/$steam_pid/cwd")
fi

if ! [ -d "$possible_path" ]; then
   warn "Steam is not running, couldn't find directory from process"
   warn "Searching manually, this can take a few seconds ..."
   possible_path=$(find ~ -name 'steamapps' | grep -v compatdata | sed 's/steamapps//g')
fi

function prompt_steam_path() {
   echo
   read -p "Please enter your Steam path: " in_path
   steam_path="$in_path"
}

steam_path=""
if [ -n "$possible_path" ]; then
   echo "Is this your Steam path?: $possible_path"
   echo
   read -p "[Y/n] :" answer
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
   echo "-- contents of /tmp/megahack --"
   echo "$megahack_dir"
   echo "-- -- -- -- -- - -- -- -- -- --"
fi

megahack_dir="/tmp/megahack/$megahack_dir"

megahack_dir_contents=$(ls "$megahack_dir")

if [ "$DEBUG" == "1" ]; then
   echo "MegaHack Directory: $megahack_dir"
   echo " -- Contents --"
   echo "$megahack_dir_contents"
   echo " -- -- -- -- --"
fi

megahack_exe=$(echo "$megahack_dir_contents" | grep ".exe")

success "Extracted MegaHack"
info "Directory: $megahack_dir"
info "Installer Executable: $megahack_exe"
echo

info " - Starting installation process - "

if [ "$DEBUG" == "1" ]; then echo "cd ${steam_path}/steamapps/compatdata/322170/pfx"; fi
cd "${steam_path}/steamapps/compatdata/322170/pfx"

info "Starting MegaHack installer ..."
echo
info "To install, press CTRL+V when you are in the exe selection window and click \"Open\""

# copy path to gd exe
gd_exe_path="Z:${steam_path}/steamapps/common/Geometry Dash/GeometryDash.exe"

info "Path to GD exe: ${gd_exe_path}"

if hash xclip 2>/dev/null; then
   echo "$gd_exe_path" | xclip -selection c
   success "Copied path to clipboard!"
else
   warn "xclip is not installed, please copy the path manually"
fi
echo

warn "If you want to install MegaHack v7, you will either have to"
warn "use MHv6's libcurl.dll OR add 'WINEDLLOVERRIDES=\"Xinput9_1_0=n,b\" %command%'"
warn "to Geometry Dash's start options in Steam OR MEGAHACK WON'T WORK!"
warn "Do you wan't to use v6's libcurl.dll method?"
read -p "[Y/n] :" answer_libcurl
   if [ "${answer_libcurl,,}" == "y" ] || [ "${answer_libcurl}" == "" ]; then
      use_v6_libcurl=1
fi

if [ "$DEBUG" == "1" ]; then
   echo "Starting MegaHack:"
   echo "STEAM_COMPAT_DATA_PATH=\"${steam_path}/steamapps/compatdata/322170\" WINEPREFIX=\"$PWD\" \"${proton_dir}/proton\" runinprefix \"${megahack_dir}/${megahack_exe}\""
fi

STEAM_COMPAT_DATA_PATH="${steam_path}/steamapps/compatdata/322170" WINEPREFIX="$PWD" "${proton_dir}/proton" runinprefix "${megahack_dir}/${megahack_exe}"

if [ "$use_v6_libcurl" == "1" ]; then
   warn "using v6's libcurl.dll to load!"
   # this allows megahack v7 to load
   cd "${steam_path}/steamapps/common/Geometry Dash"
   rm libcurl.dll
   info "Downloading v6 libcurl.dll"
   wget -O "/tmp/megahack/libcurl.dll" "https://raw.githubusercontent.com/RoootTheFox/Linux-MegaHack-Installer/main/libcurl.dll"
   cp "/tmp/megahack/libcurl.dll" .
   mv hackproldr.dll absoluteldr.dll
fi

echo
info "Cleaning up ..."
rm -rf "/tmp/megahack" 2>/dev/null
echo
success "If you followed the steps in the installer, MegaHack Pro should now be installed!"
success "Have fun!" 1
echo

sleep 0.2
exit 0
