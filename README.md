# Linux MegaHack Installer

Install script to install MegaHack on Linux

## Requirements

- You need the following packages: unzip, (optional: xclip)
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
> [!IMPORTANT]
> Replace YOUR_USERNAME and YOUR_MEGAHACK_INSTALLER.zip to your actual user and MegaHack.<br>
> If you installed it somewhere else make sure to change *Downloads* to wherever your downloaded your MegaHack installer.zip.<br>
> After that, the installer will automatically find your steam path and confirm.
> If it isn't your steam path, then you'll need to manually type it in.

The installer will then ask you if you want to use v6's libcurl.dll method.
The libcurl method is easier (and faster) to set up, but it *WILL* break when MegaHack transitions to [Geode](https://geode-sdk.org/) (which it eventually will).
> [!NOTE]
> **If you are a v6 libcurl.dll user:** when MegaHack transitions to Geode, you will have to Verify Files for GD in Steam in order to restore the original libcurl.dll.
> **If you don't do this, things will break.**

The Megahack installer will show up, follow the MegaHack instructions to install and you should be good to go!

**This script has been made and tested on Arch Linux, I dont know if it will work anywhere else. Please try it no matter what distro you use and [report any issues you find](https://github.com/RoootTheFox/Linux-MegaHack-Installer/issues)!**<br>
Contributions are always welcome!
