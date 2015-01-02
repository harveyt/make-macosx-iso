#!/bin/bash
#
# make-macosx-iso
# ===============
# 
# Create Mac OS X ISO image from App Store installation app.
# 
# Supports
# --------
# 
# * Mac OS X 10.9 "Mavericks"
# * Mac OS X 10.10 "Yosemite"
# 
# NOTE: You *must* have already downloaded the OS installer in the App Store.
# 
# Example
# -------
# 
# ```
# $ ./make-macosx-iso.sh -v Mavericks -o Mavericks-Install.iso
# ```
# 
# Thanks
# ------
# 
# Thanks to information from:
# 
# - http://forums.appleinsider.com/t/159955/howto-create-bootable-mavericks-iso
# - http://sqar.blogspot.de/2014/10/installing-yosemite-in-virtualbox.html
# - http://www.insanelymac.com/forum/topic/301988-how-to-create-a-bootable-yosemite-install-updated
# 
# License
# =======
#
# Copyright (c) 2015 Harvey John Thompson
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

DEFAULT_VERSION=Yosemite
DEFAULT_INSTALL_APP=
DEFAULT_OUTPUT_ISO=
DEFAULT_APPLICATIONS_DIRS="/Applications"

# Internal variables
VOLUMES_INSTALL_APP=/Volumes/install_app
VOLUMES_INSTALL_BUILD=/Volumes/install_build
TEMP_IMAGE=/tmp/install_image
SIZE_SPARSEBUNDLE=8g

# --------------------------------------------------------------------------------
usage()
{
    echo "usage: make-macosx-iso [-v version] [-i install.app] [-o image.iso]

-v version		Version of Mac OS X ISO to build. 
			Default: $DEFAULT_VERSION
			Supported versions:
				\"10.9\" or \"Mavericks\"
				\"10.10\" or \"Yosemite\"
-i install.app		Location of install application.
			Default: $DEFAULT_INSTALL_APP
-o image.iso		Location to output ISO image.iso
			Default: $DEFAULT_OUTPUT_ISO
" >&2
    exit 1
}

error()
{
    echo "make-macosx-iso: Error: $@" >&2
    exit 1
}

set_version()
{
    VERSION="$1"
    case $VERSION in
	10.9|Mavericks)
	    VERSION_ID="10.9"
	    VERSION_NAME="Mavericks"
	    ;;
	10.10|Yosemite)
	    VERSION_ID="10.10"
	    VERSION_NAME="Yosemite"
	    ;;
	*)
	    error "Unknown Mac OS X version \"$VERSION\""
	    ;;
    esac
    VERSION_TITLE="Mac OS X $VERSION_ID \"$VERSION_NAME\""
}

find_install_app()
{
    if [[ -n "$INSTALL_APP" ]]; then
	echo "$INSTALL_APP"
	return
    fi

    local app="Install OS X $VERSION_NAME.app"
    local dir path
    for dir in $DEFAULT_APPLICATIONS_DIRS
    do
	path=$dir/$app
	if [[ -d $path ]]; then
	    echo $path
	    return
	fi
    done
}

find_output_iso()
{
    if [[ -n "$OUTPUT_ISO" ]]; then
	echo "$OUTPUT_ISO"
	return
    fi
    echo ~/Desktop/$VERSION_NAME.iso
}

set_defaults()
{
    set_version $DEFAULT_VERSION
    DEFAULT_INSTALL_APP=$(find_install_app)
    DEFAULT_OUTPUT_ISO=$(find_output_iso)
}

set_params()
{
    set_version $VERSION
    INSTALL_APP=$(find_install_app)
    if [[ -z "$INSTALL_APP" ]]; then
	error "Cannot find $VERSION_TITLE installer, download it in App Store."
    fi
    OUTPUT_ISO=$(find_output_iso)
}

show_header()
{
    echo "
--------------------------------------------------------------------------------
Creating $VERSION_TITLE ISO...

Version:	$VERSION
Version Name:	$VERSION_NAME
Version ID:	$VERSION_ID
Version Title:	$VERSION_TITLE
Install App:	$INSTALL_APP
Output ISO:	$OUTPUT_ISO
--------------------------------------------------------------------------------
"
}

show_footer()
{
    echo "
--------------------------------------------------------------------------------
Succesfully created ISO: $OUTPUT_ISO
--------------------------------------------------------------------------------
"
}

error_cleanup()
{
    clear_safe_mode
    {
	hdiutil detach "$VOLUMES_INSTALL_APP"
	hdiutil detach "$VOLUMES_INSTALL_BUILD" 
	rm -f "$TEMP_IMAGE.sparseimage"
	rm -f "$TEMP_IMAGE.cdr"
    } >/dev/null 2>&1
}

set_safe_mode()
{
    trap 'set +o xtrace; exit 1' SIGHUP SIGINT SIGTERM
    trap 'set +o xtrace; error_cleanup' EXIT
    set -e errexit
    set -o noglob
    set -o nounset
    set -o pipefail
    set -o xtrace    
}

clear_safe_mode()
{
    set +o xtrace
    set +o pipefail
    set +o nounset
    set +o noglob
    set +e errexit
    trap - EXIT SIGHUP SIGINT SIGTERM
}

mount_installer_image()
{
    hdiutil attach "$INSTALL_APP/Contents/SharedSupport/InstallESD.dmg" -noverify -nobrowse -mountpoint "$VOLUMES_INSTALL_APP"
}

convert_bootimage_to_sparsebundle()
{
    hdiutil convert "$VOLUMES_INSTALL_APP/BaseSystem.dmg" -format UDSP -o "$TEMP_IMAGE"

    # Increase the sparse bundle capacity to accommodate the packages
    hdiutil resize -size "$SIZE_SPARSEBUNDLE" "$TEMP_IMAGE.sparseimage"

    # Mount the sparse bundle for package addition
    hdiutil attach "$TEMP_IMAGE.sparseimage" -noverify -nobrowse -mountpoint "$VOLUMES_INSTALL_BUILD"

    # Remove Package link and replace with actual files
    rm "$VOLUMES_INSTALL_BUILD/System/Installation/Packages"
    cp -rp "$VOLUMES_INSTALL_APP/Packages" "$VOLUMES_INSTALL_BUILD/System/Installation/"

    if [[ $VERSION_ID == "10.10" ]]; then
	# Copy Base System  
	cp -rp "$VOLUMES_INSTALL_APP/BaseSystem.dmg" "$VOLUMES_INSTALL_BUILD"
	cp -rp "$VOLUMES_INSTALL_APP/BaseSystem.chunklist" "$VOLUMES_INSTALL_BUILD"
    fi

    # Unmount the installer image
    hdiutil detach "$VOLUMES_INSTALL_APP"

    # Unmount the sparse bundle
    hdiutil detach "$VOLUMES_INSTALL_BUILD"

    # Calculate correct size in bytes
    newsize=$(hdiutil resize -limits "$TEMP_IMAGE.sparseimage" | tail -n 1 | awk '{ print $1 }')
    
    # Resize the partition in the sparse bundle to remove any free space
    hdiutil resize -size ${newsize}b "$TEMP_IMAGE.sparseimage"
}

convert_sparsebundle_to_iso()
{
    # Convert the sparse bundle to ISO/CD master
    hdiutil convert "$TEMP_IMAGE.sparseimage" -format UDTO -o "$TEMP_IMAGE"

    # Remove the sparse bundle
    rm "$TEMP_IMAGE.sparseimage"

    # Rename the ISO and move it to the correct location
    mv "$TEMP_IMAGE.cdr" "$OUTPUT_ISO"
}
    
# --------------------------------------------------------------------------------
# Main
#

set_defaults

while getopts v:i:o: c
do
    case $c in
	v)
	    VERSION=$OPTARG
	    ;;
	i)
	    INSTALL_APP=$OPTARG
	    ;;
	o)
	    OUTPUT_ISO=$OPTARG
	    ;;
	*)
	    usage
	    ;;
    esac
done

set_params
show_header

set_safe_mode
mount_installer_image
convert_bootimage_to_sparsebundle
convert_sparsebundle_to_iso
clear_safe_mode

show_footer
exit 0
