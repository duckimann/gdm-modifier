#!/bin/bash

# Check if script is run by root.
if [ "$(id -u)" -ne 0 ] ; then
	echo 'This script must be run as root or with the sudo command.'
	exit 1
fi

# Check what linux distro is being used.
distro="$(lsb_release -c | cut -f 2)"
if ! [[ "$distro" =~ (focal|groovy|hirsute|impish) ]]; then
	echo 'Sorry, this script only works with focal, groovy, hirsute or impish distros.'
	exit 1
fi

# Check if glib 2.0 development libraries are installed.
if [ ! -x "$(command -v glib-compile-resources)" ]; then
	echo 'Additional glib 2.0 libraries need to be installed.'
	read -p 'Type y or Y to proceed. Any other key to exit: ' -n 1
	if [[ "$REPLY" =~ ^[yY]$ ]]; then
		apt install libglib2.0-dev-bin -y
	else
		echo "This tool can't run without required libraries"
		echo "Exiting."
		echo
		exit 1
	fi
fi

# Define main variables.
# Assign the default gdm theme file path.
gdm3Resource=/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource
lsbRelease="$(lsb_release -i | awk '{print $3}')"
if [ "$lsbRelease" == "Pop" ]; then
	gdm3Resource=/usr/share/gnome-shell/theme/Pop/gnome-shell-theme.gresource
fi
gdm3xml=$(basename "$gdm3Resource").xml
workDir="/tmp/gdm3-theme"

# Assign the default gdm css file path
gdmCssDefault="$workDir"/theme/gdm3.css
if  [[ "$distro" == "impish" ]]; then
	gdmCssDefault="$workDir"/theme/gdm.css
fi

# Create a backup file of the original theme if there isn't one.
[ ! -f "$gdm3Resource"~ ] && cp "$gdm3Resource" "$gdm3Resource~"

# Check backup version, does it match with the os distro?
chksum=$(sha256sum "$gdm3Resource~" | cut -d " " -f 1)
declare -A hashtable=(
	[Ubuntu_impish]="e85672d3cd5e1ef45e24d2a990971324b470d85279b6842225233141ac5f2807"
	[Ubuntu_hirsute]="0a7427981087bf9eb48cc55e9ad3bce1d72235f151cf625415c350475ac25fc4"
	[Pop_hirsute]="91de15c933229c1385de005cfe603b4e06c52134554542fb0442eadb9821b867"
);
if [[ "$chksum" != ${hashtable["${lsbRelease}_${distro}"]} ]]; then
	echo "Force making new backup."
	echo "${hashtable[$lsbRelease_$distro]}"
	cp -f "$gdm3Resource" "$gdm3Resource~"
fi


Restore () {
	cp -f "$gdm3Resource~" "$gdm3Resource";
	if [ "$?" -eq 0 ]; then
		chmod 644 "$gdm3Resource";
		echo "GDM background sucessfully restored.";
		read -p "Do you want to restart gdm to apply change? (y/n): " -n 1
		echo
		if [[ "$REPLY" =~ ^[yY]$ ]]; then
			service gdm restart
		else
			echo "Restart GDM service to apply change."
			exit 0
		fi
	fi
}

# Create directories from resource list.
CreateDirs() {
	for resource in `gresource list "$gdm3Resource~"`; do
		resource="${resource#\/org\/gnome\/shell\/}"
		if [ ! -d "$workDir"/"${resource%/*}" ]; then
			mkdir -p "$workDir"/"${resource%/*}"
		fi
	done
}

# Extract resources from binary file.
ExtractRes() {
	for resource in `gresource list "$gdm3Resource~"`; do
		gresource extract "$gdm3Resource~" "$resource" > \
		"$workDir"/"${resource#\/org\/gnome\/shell\/}"
	done
}

# Compile resources into a gresource binary file.
CompileRes() {
	echo -e '<?xml version="1.0" encoding="UTF-8"?>\n<gresources>\n\t<gresource prefix="/org/gnome/shell/theme">' > "$workDir"/theme/"$gdm3xml";
	for file in `gresource list "$gdm3Resource~"`; do
		echo -e "\t\t<file>${file#\/org\/gnome/shell\/theme\/}</file>" >> "$workDir"/theme/"$gdm3xml";
	done
	if [[ "$1" != "" ]]; then
		echo -e "\t\t<file>$1</file>" >> "$workDir"/theme/"$gdm3xml";
	fi
	echo -e '\t\t</gresource>\n</gresources>' >> "$workDir"/theme/"$gdm3xml";
	glib-compile-resources --sourcedir=$workDir/theme/ $workDir/theme/"$gdm3xml";
}

# Moves the newly created resource to its default place.
MoveRes() {
	mv $workDir/theme/gnome-shell-theme.gresource $gdm3Resource;
}

# Check if gresource was sucessfuly moved to its default folder.
Check() {
	if [ "$?" -eq 0 ]; then
	# Solve a permission change issue (thanks to @huepf from github).
		chmod 644 "$gdm3Resource";
		echo "GDM background sucessfully changed.";
		read -p "Do you want to restart gdm to apply change? (y/n): " -n 1;
		echo
		# If change was successful apply ask for gdm restart.
		if [[ "$REPLY" =~ ^[yY]$ ]]; then
			service gdm restart;
		else
			echo "Change will be applied only after restarting gdm";
			echo
		fi
	else
		# If something went wrong, restore backup file.
		echo "Something went wrong.";
		Restore
		echo "No changes were applied.";
	fi
}

CleanUp() {
	# Remove temporary directories and files.
	rm -r "$workDir";
	exit 0;
}

ReplaceBg() {
	local newBg="#lockDialogGroup {
    background: $1;
    background-size: cover; }";
	local oldBg="#lockDialogGroup \{\n?.*?\}";
	perl -i -0777 -pe "s/$oldBg/$newBg/s" $gdmCssDefault;
}

ReplaceDialogBg() {
	local cssClass=".login-dialog"
	if  [[ "$distro" == "impish" || "$lsbRelease" == "Pop" ]]; then # to Ubuntu 21.10 or PopOS
		cssClass=".unlock-dialog";
	fi;
	local oldDialog="$cssClass {\n  border: none;\n  background-color: transparent;";
	local newDialog="$cssClass {\n  border: none;\n  background-color: $1";
	perl -i -0777 -pe "s/$oldDialog/$newDialog/s" $gdmCssDefault;
}

ReplaceDialogFont() {
	# $1 = #343434
	# $2 = Font family
	local oldFontProps=".user-widget-label {\n?\s+?color: #eeeeec; }";
	local newFontProps=".user-widget-label { color: $1; font-family: '$2' }";
	if [[ "$lsbRelease" == "Pop" ]]; then
		oldFontProps=".user-widget-label {\n?\s+?color: #F6F6F6; }";
	fi;
	perl -i -0777 -pe "s/$oldFontProps/$newFontProps/s" $gdmCssDefault;
}

ValidatePhoto() {
	if [[ $(file --mime-type -b "$1") == image/*g ]]; then
		# Define image variables.
		local gdmBgImg=$(realpath "$1")
		local imgFile=$(basename "$gdmBgImg")

		cp "$gdmBgImg" "$workDir"/theme # Copy selected image to the resources directory.
		echo $imgFile;
	else 
		echo "";
		echo "Photo $1 is not valid.";
		exit 0;
	fi
}

ValidateColor() {
	if [[ "$(echo $1 | grep -Eo "^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$|rgba?\([0-9]+,\s?[0-9]+,\s?[0-9]+(,\s?(0\.)?[0-9]+)?\)")" != "" ]]; then
		echo "$1";
	else
		echo "";
		echo "Color $1 is not valid."
		exit 0;
	fi
	# if [[ "$(echo $1 | grep -Eo "^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$")" != "" ]]; then echo "$1"; fi
	# if [[ "$(echo $1 | grep -Eo "rgba?\([0-9]+,\s?[0-9]+,\s?[0-9]+(,\s?(0\.)?[0-9]+)?\)")" != "" ]]; then echo "$1"; fi
}

ValidateFont() {
	font="$(fc-list | grep -Pio "$1" | head -1)";
	if [[ "$font" != "" ]]; then
		echo "$font";
	else 
		echo "Font $1 is not valid";
		exit 0;
	fi;
}


# Process will look like this.
# Call procedures to create directories and extract resources to them.
CreateDirs
ExtractRes

anyChanges=0;
img="";

if [[ -z "$1" ]]; then
cat << EOF
Invalid Arguments.
--

--image                   | Set background to an image
--color                   | Set background to an color
--dialog-background       | Set login dialog background to an color
--dialog-font             | Set login dialog font & font color
--fix-streched-background | Fix background stretched on 2+ monitor setup (Experimental)

Syntax:
--image "path_to_image"
--color "color_in_hex_or_rgba_color"
--dialog-background "color_in_hex_or_rgba_color"
--dialog-font "font_color" "font_name

Example:
sudo ./gdm-modifier.sh --image ./00.jpg
sudo ./gdm-modifier.sh --color \#343434
sudo ./gdm-modifier.sh --color "rgb(0,0,0)"
sudo ./gdm-modifier.sh --dialog-background "rgba(0,0,0,0.5)"
sudo ./gdm-modifier.sh --dialog-font "#343434" "FreeMono"

Note: If you're using HEX color, please put a backslash before the hash. E.g. \#343434
EOF
CleanUp;
fi;

while (( "$#" )); do
	case "$1" in
		--image)
			if [[ -n "$2" ]]; then
				img="$(ValidatePhoto "$2")";
				ReplaceBg "url('resource:\/\/\/org\/gnome\/shell\/theme\/$img');";
				anyChanges=1;
				shift 2;
			else 
				echo "Error: Argument for $1 is missing.";
				Cleanup;
			fi
		;;
		--color)
			if [[ -n "$2" ]]; then
				echo "$2";
				ReplaceBg "$(ValidateColor "$2")";
				anyChanges=1;
				shift 2;
			else 
				echo "Error: Argument for $1 is missing.";
			fi
		;;
		--dialog-background)
			if [[ -n "$2" ]]; then
				ReplaceDialogBg "$(ValidateColor "$2")";
				anyChanges=1;
				shift 2;
			else 
				echo "Error: Argument for $1 is missing.";
			fi
		;;
		--dialog-font)
			# --dialog-font "FontColor" "FontName"
			if [[ -n "$2" && -n "$3" ]]; then
				ReplaceDialogFont "$(ValidateColor "$2")" "$(ValidateFont "$3")";
				anyChanges=1;
				shift 3;
			else 
				echo "Error: Argument for $1 is missing.";
			fi
		;;
		--restore)
			Restore;
		;;
		--fix-streched-background)
			sudo cp ~/.config/monitors.xml `grep gdm /etc/passwd | awk -F ":" '{print $6}'`/.config/; # https://github.com/thiggy01/change-gdm-background/issues/15
		;;
	esac
done

if [[ $anyChanges == 1 ]]; then
	CompileRes $img;
	MoveRes; # Move gresource to the default place.
	Check; # Check if everything was successful.
fi;

CleanUp; # Remove temporary files and exit.
