#!/bin/bash
clear
echo "MegaHack Pro Installer for Linux"
echo ""

# check for required packages
missing_packages=false
if ! hash unzip 2>/dev/null; then echo "unzip is not installed!"; missing_packages=true; fi
if ! hash 7z 2>/dev/null; then echo "p7zip is not installed!"; missing_packages=true; fi
if ! hash xclip 2>/dev/null; then echo "xclip is not installed!"; missing_packages=true; fi

echo ""
if [ $missing_packages == true ] ; then
   echo "You are missing some programs."
   echo "Please install them using your distro's package manager to continue."
   echo "Additional information can be found above."
   exit 0
fi

tput cuu 1
tput el
echo "(most terminals support drag and drop)"
printf "Please enter the path to your MegaHack Pro .zip / .7z file: "
read megahack_zip
echo ""
if ! [ -f "$megahack_zip" ]; then
   echo "Could not find the file you specified!"
   exit
fi

echo "Finding your steam path ..."
possible_path=`find ~ -name 'steamapps' | grep -v compatdata | sed 's/steamapps//g'`

steam_path=""
if ! [ -z "$possible_path" ]; then
   echo "Is this your Steam path?: $possible_path"
   echo ""
   tput cuu 1
   tput el
   printf "[y/N] :"
   read answer
   if [ "${answer,,}" == "y" ] || [ "${anser}" == "" ]; then
      steam_path="$possible_path"
   fi
   if [ "${answer,,}" == "n" ]; then
      echo ""
      tput cuu 1
      tput el
      printf "Please enter your Steam path: "
      read in_path
      steam_path="$in_path"
   fi
else
   echo ""
   tput cuu 1
   tput el
   printf "Please enter your Steam path: "
   read in_path
   steam_path="$in_path"
fi

steam_path=${steam_path%/}
echo "Using Steam path: $steam_path"

# find proton version
if [ -d "${steam_path}/steamapps/common/Proton - Experimental" ]; then proton_dir="Proton - Experimental"; fi
if [ -d "${steam_path}/steamapps/common/Proton 6.3" ]; then proton_dir="Proton 6.3"; fi # preferred version; more stable

if [ ! -d "${steam_path}/steamapps/common/${proton}" ]; then
   echo "You dont have Proton Experimental or Proton 6.3 installed!"
   echo "Please set Geometry Dash to use Proton 6.3 or Experimental"
   echo "To do that, go to GD's Steam page, click \"Properties\" > \"Compatibility\", enable \"Force the use of a specific Steam Play compatibility tool\" and select Proton 6.3 or Proton Experimental!"
   echo "You have to start Geometry Dash at least once after changing it for steam to download the new Proton version."
   exit 1
fi

echo "Using ${proton_dir}"

sleep 2
# clear temporary files
rm -rf "/tmp/megahack" 2>/dev/null
mkdir "/tmp/megahack" 2>/dev/null

echo "Extracting MegaHack Patcher ..."
echo "$megahack_zip"
if [[ $megahack_zip == *.zip ]]; then
   echo "zip"
   unzip "$megahack_zip" -d /tmp/megahack
else
   if [[ $megahack_zip == *.7z ]]; then
      echo "7z"
      7z x "$megahack_zip" -o/tmp/megahack
   else
      echo "unsupported file type"
      exit
   fi
fi

# find out where megahack is
megahack_dir=`ls /tmp/megahack`
megahack_dir="/tmp/megahack/$megahack_dir"

megahack_exe=`ls "$megahack_dir" | grep ".exe"`

echo "Extracted MegaHack"
echo "Directory: $megahack_dir"
echo "Installer Executable: $megahack_exe"
echo ""

echo " - Starting installation process - "

echo "Setting exe path to our GD exe ..."
# this sets the predefined path to geometry dash in the megahack installer
# sometimes it works sometimes it doesnt for some reason
reg_out=/tmp/megahack/tmp.reg
echo "Windows Registry Editor Version 5.00" > $reg_out
echo "" >> $reg_out
echo "[HKEY_CURRENT_USER\Software\QtProject\OrganizationDefaults\FileDialog]" >> $reg_out
echo "\"history\"=hex(7):00,00" >> $reg_out
echo "\"lastVisited\"=\"file:///Z:${steam_path}/steamapps/common/Geometry Dash\"" >> $reg_out

echo "cd ${steam_path}/steamapps/compatdata/322170/pfx"
cd "${steam_path}/steamapps/compatdata/322170/pfx"

STEAM_COMPAT_DATA_PATH="${steam_path}/steamapps/compatdata/322170" WINEPREFIX="$PWD" "${steam_path}/steamapps/common/${proton_dir}/proton" runinprefix regedit /tmp/megahack/tmp.reg

clear
echo "Starting MegaHack installer ..."
echo ""
echo "To install, press CTRL+V when you are in the exe selection window."
# copy path to gd exe in case the regedit above didnt work
echo "Z:${steam_path}/steamapps/common/Geometry Dash/GeometryDash.exe" | sed 's:/:\\:g'
echo "Z:${steam_path}/steamapps/common/Geometry Dash/GeometryDash.exe" | sed 's:/:\\:g' | xclip -selection c
echo ""

STEAM_COMPAT_DATA_PATH="${steam_path}/steamapps/compatdata/322170" WINEPREFIX="$PWD" "${steam_path}/steamapps/common/${proton_dir}/proton" runinprefix "${megahack_dir}/${megahack_exe}"
#clear

# this allows megahack v7 to load
cd "${steam_path}/steamapps/common/Geometry Dash"
rm libcurl.dll
echo "Downloading v6 libcurl.dll"
wget -O "/tmp/megahack/libcurl.dll" "https://raw.githubusercontent.com/RoootTheFox/Linux-MegaHack-Installer/main/libcurl.dll"
cp "/tmp/megahack/libcurl.dll" .
mv hackproldr.dll absoluteldr.dll

echo ""
echo "Cleaning up ..."
rm -rf "/tmp/megahack" 2>/dev/null
echo ""
echo "If you followed the steps in the installer, MegaHack Pro should now be installed!"
echo "Have fun!"
echo ""
sleep 0.2
exit 0
