#!/bin/bash
#
# Activation watermark simulator
# for the Trinity desktop.
#
# Released into Public Domain.
#
# This is meant to be a joke, please do not
# use it in any serious manner whatsoever.
#
# Also this shows the flexibility of many
# Trinity components, in this case the desktop
# and Superkaramba, which can be scripted
# with dcop and simple shell scripts.
#
# This script applies some special settings
# to your desktop configuration and comes
# with the restore functionality. That
# should not mess up your previous setup
# unless you do some changes to the configuration
# while in "watermark mode", in which case you
# will lose any changes made in that mode and
# which is not recommended anyway.
#
# You can inspect the way this script works
# to see that nothing nefarious takes place
# behind the scenes.

PATH_KARAMBA=${PATH_KARAMBA:-/tmp/joke-activate.theme}
PATH_BG_BACKUP=${PATH_BG_BACKUP:-/tmp/joke-bg-backup}

# Don't touch the definitions below unless necessary
ALL_FILES="$PATH_KARAMBA $PATH_BG_BACKUP"
THEME_NAME=$(basename $PATH_KARAMBA | sed "s:\.theme::g")

do_checks() {
	# Needed tools
	for t in superkaramba xrandr kreadconfig kwriteconfig
	do
		which $t >/dev/null 2>&1 || {
			echo "Error: '$t' not found in PATH"
			exit 2
		}
	done

	# Write permission for directory to store the superkaramba theme
	for p in $ALL_FILES
	do
		dir=$(dirname $p)
		touch $dir/.perms-test 2>/dev/null || {
			echo "Error: you don't have write permissions for $dir"
			echo "Please adjust PATH_KARAMBA and retry."
			exit 3
		}
		rm $dir/.perms-test
	done

	# Whether the action has been already performed (leftovers)
	found=0
	for f in $ALL_FILES
	do
		test -f $f && found=1
	done
	test $found -eq 1 -a "$ACTION" == "on" && {
		echo "The joke has already been enabled. Use '$0 off' to deactivate it."
		echo "If you are sure that this is not the case, backup or delete"
		echo "the following files:"
		for f in $ALL_FILES
		do
			test -f $f && echo -e "\t* $f"
		done
		exit 4
	}
}

exit_usage() {
	echo "usage: $0 {on | off}"
	exit 1
}

get_watermark_pos() {
	# Because Superkaramba does not understand negative x/y positions...
	screen_res=$(xrandr | grep '*' | grep -Eo '[0-9]*x[0-9]*')
	screen_w=$(echo $screen_res|cut -d'x' -f1)
	screen_h=$(echo $screen_res|cut -d'x' -f2)
	wm_x=$((screen_w - 550))
	wm_y=$((screen_h - 150))
	echo "x=${wm_x} y=${wm_y}"
}

write_karamba() {
	xy=`get_watermark_pos`
	cat > $PATH_KARAMBA << _EOF_
karamba $xy w=500 h=100 interval=86400000

defaultfont font="Sans Serif" fontsize=16 color=255,255,255

text x=10 y=10 fontsize=22 value="Your Trinity Desktop is not activated."
text x=10 y=45 value="This copy of TDE is not genuine."
text x=10 y=65 value="Please activate your copy or Konqui will eat your soul ^_^."
_EOF_
}

register_karamba() {
	superkaramba $PATH_KARAMBA &
	echo "Registered SuperKaramba theme"
}

unregister_karamba() {
	dcop $(dcopfind superkaramba-\*) closeTheme $THEME_NAME
	echo "Unregistered SuperKaramba theme"
}

read_desktop_settings() {
	desk=$1
	key=$2
	kreadconfig --file kdesktoprc --group "Desktop${desk}" --key "$key"
}

write_desktop_settings() {
	desk=$1
	key=$2
	val=$3
	kwriteconfig --file kdesktoprc --group "Desktop${desk}" --key "$key" "$val"
}

max_desktop=0
save_bg_settings() {
	test "$(dcop kdesktop KBackgroundIface isCommon)" == "true" && lim=0 || lim=19

	for d in $(seq 0 $lim)
	do
		wmode=`read_desktop_settings $d WallpaperMode`
		test -z "$wmode" && break
		bmode=`read_desktop_settings $d BackgroundMode`
		color=`read_desktop_settings $d Color1`
		echo "$wmode $bmode $color" >> $PATH_BG_BACKUP
	done
	max_desktop=$d # store for later
	echo "Current desktop settings backup created"
}

restore_bg_settings() {
	test -f $PATH_BG_BACKUP || {
		echo "Oops! The wallpaper backup data seems to have been misplaced!"
		exit
	}
	d=0
	while read -r l
	do
		wmode=$(echo $l | cut -d' ' -f1)
		bmode=$(echo $l | cut -d' ' -f2)
		color=$(echo $l | cut -d' ' -f3)

		write_desktop_settings $d WallpaperMode $wmode
		write_desktop_settings $d BackgroundMode $bmode
		write_desktop_settings $d Color1 $color

		d=$(($d+1))
	done < $PATH_BG_BACKUP
	echo "Previous desktop settings restored"
}

black_out_bg() {
	for d in $(seq 0 $max_desktop)
	do
		write_desktop_settings $d WallpaperMode NoWallpaper
		write_desktop_settings $d BackgroundMode Flat
		write_desktop_settings $d Color1 0,0,0
	done
}

apply_new_settings() {
	dcop kdesktop KBackgroundIface configure
	test $? -eq 0 && echo "New settings applied" || echo "You need to restart KDesktop manually."
}

cleanup() {
	for f in $ALL_FILES
	do
		rm $f
	done
}

### MAIN BODY ###
test -z "$1" && exit_usage

ACTION="$1"

case $ACTION in
	"on")
		do_checks
		write_karamba
		register_karamba
		save_bg_settings
		black_out_bg
		apply_new_settings

		echo -e "\nHave fun!"
		;;

	"off")
		restore_bg_settings
		apply_new_settings
		cleanup

		echo -e "\nThank you!"
		;;

	*)
		exit_usage
		;;
esac
