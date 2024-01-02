#!/bin/bash
clear
echo "MegaHack Pro Installer for Linux"
echo ""

if [ "$DEBUG" == "1" ]; then
   echo "Debug logging enabled!"
fi

# check for required packages
missing_packages=false
if ! hash unzip 2>/dev/null; then echo "unzip is not installed!"; missing_packages=true; fi
if ! hash xclip 2>/dev/null; then echo "xclip is not installed, you will have to manually copy the MegaHack path!"; fi

echo ""
if [ $missing_packages == true ] ; then
   echo "You are missing some programs."
   echo "Please install them using your distro's package manager to continue."
   echo "Additional information can be found above."
   exit 0
fi

echo "(most terminals support drag and drop)"

# if fzf is installed, use it
if hash fzf 2>/dev/null; then
    megahack_zip=$(fzf --header="MegaHack Installer.zip selection" --prompt="Please enter the path to your MegaHack .zip file: ")
else
    read -p "Please enter the path to your MegaHack .zip file: " megahack_zip
fi

echo ""
if ! [ -f "$megahack_zip" ]; then
   echo "Could not find the file you specified!"
   exit
fi

megahack_zip=$(realpath "$megahack_zip")

echo "Finding your steam path ..."
if [ -f "$HOME/.steampid" ]; then
   steam_pid=$(cat "$HOME/.steampid")
   echo "Steam PID: $steam_pid"
   possible_path=$(readlink -e "/proc/$steam_pid/cwd")
fi

if ! [ -d "$possible_path" ]; then
   echo "Steam is not running, couldn't find directory from process"
   echo "Searching manually, this can take a few seconds ..."
   possible_path=$(find ~ -name 'steamapps' | grep -v compatdata | sed 's/steamapps//g')
fi

function prompt_steam_path() {
   echo ""
   read -p "Please enter your Steam path: " in_path
   steam_path="$in_path"
}

steam_path=""
if [ -n "$possible_path" ]; then
   echo "Is this your Steam path?: $possible_path"
   echo ""
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
echo "Using Steam path: $steam_path"

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
    echo "Proton directory found: $proton_dir"
else
    echo "Could not find Proton directory within config: $config_file"
    exit 1
fi


echo "Using Proton: ${proton_dir}"

# clear temporary files
rm -rf "/tmp/megahack" 2>/dev/null
mkdir "/tmp/megahack" 2>/dev/null

echo "Extracting MegaHack Patcher ..."
echo "$megahack_zip"
if [[ $megahack_zip == *.zip ]]; then
   echo "zip"
   unzip "$megahack_zip" -d /tmp/megahack
else
   echo "unsupported file type - are you sure you're selecting a .zip file?"
   exit
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

echo "Extracted MegaHack"
echo "Directory: $megahack_dir"
echo "Installer Executable: $megahack_exe"
echo ""

echo " - Starting installation process - "

if [ "$DEBUG" == "1" ]; then echo "cd ${steam_path}/steamapps/compatdata/322170/pfx"; fi
cd "${steam_path}/steamapps/compatdata/322170/pfx"

STEAM_COMPAT_DATA_PATH="${steam_path}/steamapps/compatdata/322170" WINEPREFIX="$PWD" "${proton_dir}/proton" runinprefix regedit /tmp/megahack/tmp.reg

if ! [ "$DEBUG" == "1" ]; then clear; fi
echo "Starting MegaHack installer ..."
echo ""
echo "To install, press CTRL+V when you are in the exe selection window and click \"Open\""

# copy path to gd exe
gd_exe_path=$(echo "Z:${steam_path}/steamapps/common/Geometry Dash/GeometryDash.exe" | sed 's:/:\\:g')

echo "Path to GD exe: $gd_exe_path"

if hash xclip 2>/dev/null; then
   echo "$gd_exe_path" | xclip -selection c
   echo "Copied path to clipboard!"
else
   echo "xclip is not installed, please copy the path manually"
fi
echo ""

echo "WARNING! If you want to install MegaHack v7, you will either have to"
echo "use MHv6's libcurl.dll OR add 'WINEDLLOVERRIDES=\"Xinput9_1_0=n,b\" %command%'"
echo "to Geometry Dash's start options in Steam OR MEGAHACK WON'T WORK!"
echo "Do you wan't to use v6's libcurl.dll method?"
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
   echo "Warning: using v6's libcurl.dll to load!"
   # this allows megahack v7 to load
   cd "${steam_path}/steamapps/common/Geometry Dash"
   rm libcurl.dll
   echo "Downloading v6 libcurl.dll"
   wget -O "/tmp/megahack/libcurl.dll" "https://raw.githubusercontent.com/RoootTheFox/Linux-MegaHack-Installer/main/libcurl.dll"
   cp "/tmp/megahack/libcurl.dll" .
   mv hackproldr.dll absoluteldr.dll
fi

echo ""
echo "Cleaning up ..."
rm -rf "/tmp/megahack" 2>/dev/null
echo ""
echo "If you followed the steps in the installer, MegaHack Pro should now be installed!"
echo "Have fun!"
echo ""

sleep 0.2
exit 0
