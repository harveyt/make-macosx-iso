#!/bin/bash
#
# %%README%%
# %%LICENSE%%
#
VERSION=%%VERSION%%
DEFAULT_TYPE=Sierra
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
    echo "usage: make-macosx-iso [-v] [-t type] [-i install.app] [-o image.iso]

-v			Show version and exit.
-t type			Type of Mac OS X ISO to build. 
			Default: $DEFAULT_TYPE
			Supported types:
				\"10.9\" or \"Mavericks\"
				\"10.10\" or \"Yosemite\"
				\"10.11\" or \"El Capitan\"
				\"10.12\" or \"Sierra\"
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

set_type()
{
    TYPE="$1"
    case $TYPE in
	10.9|Mavericks|mavericks)
	    TYPE_ID="10.9"
	    TYPE_NAME="Mavericks"
	    INSTALL_NAME="Mavericks"
	    ;;
	10.10|Yosemite|yosemite)
	    TYPE_ID="10.10"
	    TYPE_NAME="Yosemite"
	    INSTALL_NAME="Yosemite"
	    ;;
	10.11|El\ Capitan|el\ capitan)
	    TYPE_ID="10.11"
	    TYPE_NAME="El Capitan"
	    INSTALL_NAME="El Capitan"
	    ;;
	10.12|Sierra|sierra)
	    TYPE_ID="10.12"
	    TYPE_NAME="Sierra"
	    INSTALL_NAME="macOS Sierra"
	    ;;
	*)
	    error "Unknown Mac OS X type \"$TYPE\""
	    ;;
    esac
    TYPE_TITLE="Mac OS X $TYPE_ID \"$TYPE_NAME\""
}

find_install_app()
{
    if [[ -n "$INSTALL_APP" ]]; then
	echo "$INSTALL_APP"
	return
    fi

    local app="Install OS X $INSTALL_NAME.app"
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
    echo ~/Desktop/$TYPE_NAME.iso
}

set_defaults()
{
    set_type $DEFAULT_TYPE
    DEFAULT_INSTALL_APP=$(find_install_app)
    DEFAULT_OUTPUT_ISO=$(find_output_iso)
}

set_params()
{
    set_type $TYPE
    INSTALL_APP=$(find_install_app)
    if [[ "$INSTALL_APP" == "" || ! -d "$INSTALL_APP" ]]; then
	error "Cannot find $TYPE_TITLE installer, download it in App Store."
    fi
    OUTPUT_ISO=$(find_output_iso)
    if [[ -e "$OUTPUT_ISO" ]]; then
	error "Output $OUTPUT_ISO already exists, use -o option to change output location."
    fi
}

show_version()
{
    program_path=$(type -p $0)
    echo "make-macosx-iso version $VERSION
Copyright (c) 2015 Harvey John Thompson
See $program_path for LICENSE."
}

show_header()
{
    echo "
--------------------------------------------------------------------------------
Creating $TYPE_TITLE ISO...

Type:		$TYPE
Type Name:	$TYPE_NAME
Type ID:	$TYPE_ID
Type Title:	$TYPE_TITLE
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

    if [[ $TYPE_ID != "10.9" ]]; then
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

while getopts vt:i:o: c
do
    case $c in
	v)
	    show_version
	    exit 0
	    ;;
	t)
	    TYPE=$OPTARG
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
show_version
show_header

set_safe_mode
mount_installer_image
convert_bootimage_to_sparsebundle
convert_sparsebundle_to_iso
clear_safe_mode

show_footer
exit 0
