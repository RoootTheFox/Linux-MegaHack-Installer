# Linux-MegaHack-Installer

Install script to install MegaHack v6 on Linux

## Requirements

- You need the following packages: unzip, p7zip, xclip
- You need a paid copy of MegaHack

## Usage

- Download the script
- Extract the zip file
- Change your directory to the Linux-MegaHack-Installer-main folder
- Make it executable: `chmod +x megahack_installer.sh`
- Run it: `./megahack_installer.sh`

Alternatively, you can use this one-liner to run the script: `sh -c "$(curl -fsSL https://raw.github.com/RoootTheFox/Linux-MegaHack-Installer/main/megahack_installer.sh)"`

## Installation

Once you run the script, enter the path to your MegaHack .zip file.
Most terminals allow you to drag and drop the zip file into your terminal.
If that does not work then you're gonna need to manually type your path.

If you have the file in your Downloads folder then your path should look something like this:
`/home/YOUR_USERNAME/Downloads/YOUR_MEGAHACK_INSTALLER.zip`
Remplace YOUR_USERNAME and YOUR_MEGAHACK_INSTALLER.zip to your actual user and megahack folder.
If you installed it somewhere else make sure to change Downloads to wherever your downloaded your megahack .zip folder

After that, the installer will automatically find your steam path and confirm.
If it isn't your steam path, then you'll need to manually type it in.

The installer will also ask you if you want to use v6's libcurl.dll method.
For most recent versions of megahack (v7/v8), you'll need it.

The Megahack installer will show up, follow the megahack instructions to install megahack and you should be good to go!

**This script has been made and tested on Arch Linux, I dont know if it will work anywhere else. Please try it no matter what distro you use and [report any issues you find](https://github.com/RoootTheFox/Linux-MegaHack-Installer/issues)!**<br>
Contributions are always welcome!
