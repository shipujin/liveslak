#!/bin/sh
#
# Copyright 1993,1994,1999  Patrick Volkerding, Moorhead, Minnesota USA
# Copyright 2001, 2003, 2004  Slackware Linux, Inc., Concord, CA
# Copyright 2006, 2007  Patrick Volkerding, Sebeka, Minnesota USA
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is 
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# As always, bug reports, suggestions, etc: volkerdi@slackware.com
#
# Modifications 2016, 2017, 2019, 2020 by Eric Hameleers <alien@slackware.com>
#

# -------------------------------------------- #
#   Slackware Live Edition - check the media   #
# -------------------------------------------- #

# The Slackware setup depends on english language settings because it
# parses program output like that of "fdisk -l". So, we need to override
# the Live user's local language settings here:
export LANG=C
export LC_ALL=C

if [ ! -d /mnt/livemedia/@LIVEMAIN@/system ]; then
 dialog  --backtitle "@CDISTRO@ Linux Setup (Live Edition)" \
  --title "LIVE MEDIA NOT ACCESSIBLE" --msgbox "\
\n\
Before you can install software, complete the following tasks:\n\
\n\
1. Mount your Live media partition on /mnt/livemedia." 16 68
  exit 1
fi

# ------------------------------------------------ #
#   Slackware Live Edition - end check the media   #
# ------------------------------------------------ #

TMP=/var/log/setup/tmp
if [ ! -d $TMP ]; then
  mkdir -p $TMP
fi
# Wipe the probe md5sum to force rescanning partitions if setup is restarted:
rm -f $TMP/SeTpartition.md5
rm -f $TMP/SeT*
# If a keymap was set up, restore that data:
if [ -r $TMP/Pkeymap ]; then
  cp $TMP/Pkeymap $TMP/SeTkeymap
fi
echo "on" > $TMP/SeTcolor # turn on color menus
PATH="$PATH:/usr/share/@LIVEMAIN@"
export PATH;
export COLOR=on
dialog --backtitle "@CDISTRO@ Linux Setup (Live Edition)" --infobox "\n
Scanning your system for partition information...\n
\n" 5 55
# In case the machine is full of fast SSDs:
sleep 1
# Before probing, activate any LVM partitions
# that may exist from before the boot:
vgchange -ay 1> /dev/null 2> /dev/null
if probe -l 2> /dev/null | grep -E 'Linux$' 1> /dev/null 2> /dev/null ; then
 RUNPART=no
 probe -l 2> /dev/null | grep -E 'Linux$' | sort 1> $TMP/SeTplist 2> /dev/null
 dialog --backtitle "@CDISTRO@ Linux Setup (Live Edition)" \
  --title "LINUX PARTITIONS DETECTED" \
  --yes-label "Continue" --no-label "Skip" --defaultno \
  --yesno "Setup detected partitions on this machine of type Linux.\n\
You probably created these before running '$(basename $0)'. Great!\n\n\
If you would like to re-consider your partitioning scheme, \
you can click 'Continue' now to start 'cfdisk' (MBR disk) \
and/or 'cgdisk' (GPT disk) for all your hard drives.\n\
Otherwise, select 'Skip' to skip disk partitioning and go on with the setup." \
12 64
 if [ $? -eq 0 ]; then
  RUNPART=yes
 fi
else
 RUNPART=yes
 dialog --backtitle "@CDISTRO@ Linux Setup (Live Edition)" \
  --title "NO LINUX PARTITIONS DETECTED" \
  --msgbox "There don't seem to be any partitions on this machine of type \
Linux.  You'll need to make at least one of these to install Linux.  \
To do this, you'll get a chance to make these partitions now using \
'cfdisk' (MBR partitions) or 'cgdisk' (GPT partitions)." 10 64
fi
if [ -d /sys/firmware/efi ]; then
  if ! probe -l 2> /dev/null | grep "EFI System Partition" 1> /dev/null 2> /dev/null ; then
    RUNPART=yes
    dialog --backtitle "@CDISTRO@ Linux Setup (Live Edition)" \
     --title "NO EFI SYSTEM PARTITION DETECTED" \
     --msgbox "This machine appears to be using EFI/UEFI, but no EFI System \
Partition was found.  You'll need to make an EFI System Partition in order \
to boot from the hard drive. In the next step, using cfdisk/cgdisk, \
make a 100MB partition of type EF00." 10 64
  fi
fi
if [ "$RUNPART" = "yes" ]; then

  # ------------------------------------------------------- #
  #   Slackware Live Edition - find/partition the disk(s)   #
  # ------------------------------------------------------- #

  SeTudiskpart
  if [ ! $? = 0 ]; then
    # No disks found or user canceled, means: abort.
    exit 1
  fi

  # ----------------------------------------------------------- #
  #   Slackware Live Edition - end find/partition the disk(s)   #
  # ----------------------------------------------------------- #

fi # End RUNPART = yes

T_PX="/setup2hd"
mkdir -p ${T_PX}
echo "$T_PX" > $TMP/SeTT_PX
ROOT_DEVICE="`mount | grep "on / " | cut -f 1 -d ' '`"
echo "$ROOT_DEVICE" > $TMP/SeTrootdev
if mount | grep /var/log/mount 1> /dev/null 2> /dev/null ; then # clear source location:
  # In case of bind mounts, try to unmount them first:
  umount /var/log/mount/dev 2> /dev/null
  umount /var/log/mount/proc 2> /dev/null
  umount /var/log/mount/sys 2> /dev/null
  # Unmount target partition:
  umount /var/log/mount
fi
# Anything mounted on /var/log/mount now is a fatal error:
if mount | grep /var/log/mount 1> /dev/null 2> /dev/null ; then
  echo "Can't umount /var/log/mount.  Reboot machine and run setup again."
  exit
fi
# If the mount table is corrupt, the above might not do it, so we will
# try to detect Linux and FAT32 partitions that have slipped by:
if [ -d /var/log/mount/lost+found -o -d /var/log/mount/recycled \
     -o -r /var/log/mount/io.sys ]; then
  echo "Mount table corrupt.  Reboot machine and run setup again."
  exit
fi
rm -f /var/log/mount 2> /dev/null
rmdir /var/log/mount 2> /dev/null
mkdir /var/log/mount 2> /dev/null

while [ 0 ]; do

 dialog --title "@CDISTRO@ Linux Setup (version @SL_VERSION@)" \
  --backtitle "@CDISTRO@ Linux Setup (Live Edition)" \
  --menu "Welcome to @CDISTRO@ Linux Setup (Live Edition).\n\
Select an option below using the UP/DOWN keys and SPACE or ENTER.\n\
Alternate keys may also be used: '+', '-', and TAB." 18 72 9 \
"HELP" "Read the @CDISTRO@ Setup HELP file" \
"KEYMAP" "Remap your keyboard if you're not using a US one" \
"ADDSWAP" "Set up your swap partition(s)" \
"TARGET" "Set up your target partitions" \
"INSTALL" "Install @CDISTRO@ Live to disk" \
"CONFIGURE" "Reconfigure your Linux system" \
"EXIT" "Exit @CDISTRO@ Linux Setup" 2> $TMP/hdset
 if [ ! $? = 0 ]; then
  rm -f $TMP/hdset $TMP/SeT*
  exit
 fi
 MAINSELECT="`cat $TMP/hdset`"
 rm $TMP/hdset

 # Start checking what to do. Some modules may reset MAINSELECT to run the
 # next item in line.

 if [ "$MAINSELECT" = "HELP" ]; then
  SeTfdHELP
 fi

 if [ "$MAINSELECT" = "KEYMAP" ]; then
  SeTkeymap
  if [ -r $TMP/SeTkeymap ]; then
   MAINSELECT="ADDSWAP" 
  fi
 fi
 
 if [ "$MAINSELECT" = "MAKE TAGS" ]; then
  SeTmaketag
 fi
 
 if [ "$MAINSELECT" = "ADDSWAP" ]; then
  SeTswap
  if [ -r $TMP/SeTswap ]; then
   MAINSELECT="TARGET"
  elif [ -r $TMP/SeTswapskip ]; then
   # Go ahead to TARGET without swap space:
   MAINSELECT="TARGET"
  fi
 fi

 if [ "$MAINSELECT" = "TARGET" ]; then
  SeTpartitions
  SeTEFI
  SeTDOS
  if [ -r $TMP/SeTnative ]; then
   MAINSELECT="INSTALL"
  fi
 fi

 if [ "$MAINSELECT" = "INSTALL" ]; then
  if [ ! -r $TMP/SeTnative ]; then
   dialog --backtitle "@CDISTRO@ Linux Setup (Live Edition)" \
    --title "CANNOT INSTALL SOFTWARE YET" --msgbox "\
\n\
Before you can install software, complete the following tasks:\n\
\n\
1. Set up your target Linux partition(s).\n\
\n\
You may also optionally remap your keyboard and set up your\n\
swap partition(s). \n\
\n\
Press ENTER to return to the main menu." 16 68
   continue
  fi

  # --------------------------------------------- #
  #   Slackware Live Edition - install to disk:   #
  # --------------------------------------------- #

  # Buy us some time while we are calculating disk usage:
  dialog --backtitle "@CDISTRO@ Linux Setup (Live Edition)" \
   --title "WELCOME TO @UDISTRO@ LIVE (@LIVEDE@)" --infobox \
   "\nCalculating disk usage, please be patient ..." 5 65

  ACT_MODS=$(ls -rt --indicator-style=none /mnt/live/modules/ |wc -l)
  TOT_MODS=$(find /mnt/livemedia/@LIVEMAIN@/ -type f -name "*.sxz" |wc -l)
  DU_LIVE=$(du -s /mnt/live/modules/ 2>/dev/null |tr -s '\t' ' ' |cut -f1 -d' ')
  PARTFREE=$(df -P -BM $T_PX |tail -1 |tr -s '\t' ' ' |cut -d' ' -f4)
  PARTFREE=${PARTFREE%M}

  # Warn when it looks we have insufficient room:
  if [ $PARTFREE -lt $(($DU_LIVE/1024)) ]; then
    dialog --backtitle "@CDISTRO@ Linux Setup (Live Edition)" \
     --title "WELCOME TO @UDISTRO@ LIVE (@LIVEDE@)" --yesno \
     "\nAvailable space: $PARTFREE MB\nRequired space: $(($DU_LIVE/1024))\nIt looks like your hard drive partition is too small.\nDo you want to continue?" 10 65
    retval=$?
    if [ $retval = 1 ]; then
      umount $T_PX
      exit 1
    fi
  else
    dialog --backtitle "@CDISTRO@ Linux Setup (Live Edition)" \
     --title "WELCOME TO @UDISTRO@ LIVE (@LIVEDE@)" --msgbox \
     "\nAvailable space: $PARTFREE MB\nRequired space: $(($DU_LIVE/1024)) MB\nIt looks like you're good to go!" 10 65
  fi

  (
    # Install the Live OS by rsyncing the readonly overlay to the harddisk:
    rsync -HAXav --whole-file --checksum-choice=none --inplace --progress --no-inc-recursive \
      /mnt/@LIVEMAIN@fs/ $T_PX/ \
      | awk '{ if (index($0, "to-chk=") > 0) { split($0, pieces, "to-chk="); split(pieces[2], term, ")"); split(term[1], division, "/"); print (1-(division[1]/division[2]))*100 };  fflush(); }' \
      | sed --unbuffered 's/^\([0-9]*\).*/\1/'
  ) | dialog --backtitle "@CDISTRO@ Linux Setup (Live Edition)" \
       --title "INSTALLING @UDISTRO@ LIVE (@LIVEDE@) TO DISK" --gauge \
       "\nProcessing ${TOT_MODS} @CDISTRO@ Live modules ($(( $DU_LIVE/1024 )) MB)" 8 65

  #
  # Live OS Post Install routine. If you want, you can override this routine
  # by (re-)defining this function "live_post_install()" in a file called
  # "/usr/share/@LIVEMAIN@/setup2hd.@DISTRO@".
  #

  live_post_install () {
    # Re-use some of the custom configuration from 0099-@DISTRO@_zzzconf-*.sxz
    # (some of these may not be present but the command will not fail):
    dialog --backtitle "@CDISTRO@ Linux Setup (Live Edition)" \
     --title "POST-INSTALL @UDISTRO@ LIVE (@LIVEDE@) DATA" --infobox \
     "\nCopying Live modifications to hard disk ..." 5 65
    sleep 1 # It's too fast...
    # Do not overwrite a custom keymap:
    if [ ! -f $T_PX/etc/rc.d/rc.keymap ]; then
      unsquashfs -f -dest $T_PX \
        /mnt/livemedia/@LIVEMAIN@/system/0099*zzzconf*.sxz \
        /etc/rc.d/rc.keymap
    fi
    unsquashfs -f -dest $T_PX \
      /mnt/livemedia/@LIVEMAIN@/system/0099*zzzconf*.sxz \
      /etc/X11/xdm/liveslak-xdm \
      /etc/X11/xorg.conf.d/30-keyboard.conf \
      /etc/inittab \
      /etc/skel \
      /etc/profile.d/lang.sh \
      /etc/rc.d/rc.font \
      /etc/rc.d/rc.gpm \
      /etc/slackpkg \
      /etc/vconsole.conf
    # Point xdm to the custom /etc/X11/xdm/liveslak-xdm/xdm-config:
    sed -i ${T_PX}/etc/rc.d/rc.4 -e 's,bin/xdm -nodaemon,& -config /etc/X11/xdm/liveslak-xdm/xdm-config,'
    # Remove the marker file from the filesystem root:
    rm -f ${T_PX}/@MARKER@

    # ---------------------
    # Set up a user account,
    dialog --title "@UDISTRO@ (@LIVEDE@) USER CREATION" \
     --backtitle "@CDISTRO@ Linux Setup (Live Edition)" \
     --msgbox "You will first get the chance to create your user account, \
and set its password.\nYour account will be added to sudoers and suauth.\n\n\
Next you will be asked to set root's password." 9 55
    # This will set UFULLNAME, UACCOUNT and USHELL variables:
    SeTuacct 2>&1 1> $TMP/tempresult
    if [ $? = 0 ]; then
      # User filled out the form, so let's get the results for
      # UFULLNAME, UACCOUNT and USHELL:
      source $TMP/tempresult
      rm -f $TMP/tempresult
      # Set a password for the new account:
      UPASS=$(SeTupass $UACCOUNT)
      # Create the account and set the password:
      chroot ${T_PX} /usr/sbin/useradd -c "$UFULLNAME" -g users -G wheel,audio,cdrom,floppy,plugdev,video,power,netdev,lp,scanner,kmem,dialout,games,disk,input -u 1000 -d /home/${UACCOUNT} -m -s ${USHELL} ${UACCOUNT}
      echo "${UACCOUNT}:${UPASS}" | chroot ${T_PX} /usr/sbin/chpasswd
      unset UPASS

      # Configure suauth:
      cat <<EOT >${T_PX}/etc/suauth
root:${UACCOUNT}:OWNPASS
root:ALL EXCEPT GROUP wheel:DENY
EOT
      chmod 600 ${LIVE_ROOTDIR}/etc/suauth

      # Configure sudoers:
      chmod 640 ${T_PX}/etc/sudoers
      sed -i ${T_PX}/etc/sudoers -e 's/# *\(%wheel\sALL=(ALL)\sALL\)/\1/'
      chmod 440 ${T_PX}/etc/sudoers
    fi # End user creation
    # ---------------------------

    if [ "$(cat $T_PX/etc/shadow | grep 'root:' | cut -f 2 -d :)" = "" ]; then
      # There is no root password yet:
      UPASS=$(SeTupass root)
      echo "root:${UPASS}" | chroot ${T_PX} /usr/sbin/chpasswd
      unset UPASS
    fi

    cat << EOF > $TMP/tempmsg

 @CDISTRO@ Live Edition (@LIVEDE@) has been installed to your hard drive!
 We installed the ${ACT_MODS} active modules (out of ${TOT_MODS} available).
 The following configuration was copied from the Live OS to your harddisk:
  - console font
  - default runlevel
  - keyboard layout
  - language setting
 After finishing system configuration and before rebooting, you can add any further Live modules from /@LIVEMAIN@/addons/ and /@LIVEMAIN@/optional/ to your hard drive, using a command similar to this:
    # unsquashfs -f -dest $T_PX /mnt/livemedia/@LIVEMAIN@/addons/mymodule.sxz

EOF
    dialog --backtitle "@CDISTRO@ Linux Setup (Live Edition)" \
      --title "POST INSTALL HINTS AND TIPS" --msgbox "`cat $TMP/tempmsg`" \
      20 65
    rm $TMP/tempmsg

    MAINSELECT="CONFIGURE"
  } # END live_post_install() function


  if [ -f /usr/share/@LIVEMAIN@/setup2hd.@DISTRO@ ]; then
    # If the setup2hd post-configuration file exists, source it.
    # The file should re-define the live_post_install() function.
    . /usr/share/@LIVEMAIN@/setup2hd.@DISTRO@
  fi

  # Now, execute the function - either our own built-in version
  # or the re-defined function from the custom setup2hd.@DISTRO@ file.
  live_post_install

  # --------------------------------------------- #
  # Slackware Live Edition - end install to disk: #
  # --------------------------------------------- #

 fi

 if [ "$MAINSELECT" = "CONFIGURE" ]; then
  # Patch (e)liloconfig on the target systems to remove hardcoded /mnt:
  if [ -f /sbin/liloconfig -a -f $T_PX/sbin/liloconfig ]; then
    cat /sbin/liloconfig > $T_PX/sbin/liloconfig
  fi
  if [ -f /usr/sbin/eliloconfig -a -f $T_PX/usr/sbin/eliloconfig ]; then
    cat /usr/sbin/eliloconfig > $T_PX/usr/sbin/eliloconfig
  fi
  # Make bind mounts for /dev, /proc, and /sys:
  mount -o bind /dev $T_PX/dev 2> /dev/null
  mount -o bind /proc $T_PX/proc 2> /dev/null
  mount -o bind /sys $T_PX/sys 2> /dev/null
  SeTconfig
  REPLACE_FSTAB=Y
  if [ -r $TMP/SeTnative ]; then
   if [ -r $T_PX/etc/fstab ]; then
    dialog --title "REPLACE /etc/fstab?" --yesno "You already have an \
/etc/fstab on your install partition.  If you were just adding software, \
you should probably keep your old /etc/fstab.  If you've changed your \
partitioning scheme, you should use the new /etc/fstab.  Do you want \
to replace your old /etc/fstab with the new one?" 10 58
    if [ ! $? = 0 ]; then
     REPLACE_FSTAB=N
    fi
   fi
   if [ "$REPLACE_FSTAB" = "Y" ]; then
    cat /dev/null > $T_PX/etc/fstab
    if [ -r $TMP/SeTswap ]; then
     cat $TMP/SeTswap > $T_PX/etc/fstab
    fi
    cat $TMP/SeTnative >> $T_PX/etc/fstab
    if [ -r $TMP/SeTDOS ]; then
     cat $TMP/SeTDOS >> $T_PX/etc/fstab
    fi
    printf "%-16s %-16s %-11s %-16s %-3s %s\n" "#/dev/cdrom" "/mnt/cdrom" "auto" "noauto,owner,ro,comment=x-gvfs-show" "0" "0" >> $T_PX/etc/fstab
    printf "%-16s %-16s %-11s %-16s %-3s %s\n" "/dev/fd0" "/mnt/floppy" "auto" "noauto,owner" "0" "0" >> $T_PX/etc/fstab
    printf "%-16s %-16s %-11s %-16s %-3s %s\n" "devpts" "/dev/pts" "devpts" "gid=5,mode=620" "0" "0" >> $T_PX/etc/fstab
    printf "%-16s %-16s %-11s %-16s %-3s %s\n" "proc" "/proc" "proc" "defaults" "0" "0" >> $T_PX/etc/fstab
    printf "%-16s %-16s %-11s %-16s %-3s %s\n" "tmpfs" "/dev/shm" "tmpfs" "defaults" "0" "0" >> $T_PX/etc/fstab
   fi
   dialog --title "SETUP COMPLETE" --msgbox "System configuration \
and installation is complete. \
\n\nYou may now reboot your system." 7 55
  fi
 fi

 if [ "$MAINSELECT" = "EXIT" ]; then
  break
 fi

done # end of main loop
sync

chmod 755 $T_PX
if [ -d $T_PX/tmp ]; then
 chmod 1777 $T_PX/tmp
fi
if mount | grep /var/log/mntiso 1> /dev/null 2> /dev/null ; then
 umount -f /var/log/mntiso
fi
if mount | grep /var/log/mount 1> /dev/null 2> /dev/null ; then
 umount /var/log/mount
fi
# Anything mounted on /var/log/mount now is a fatal error:
if mount | grep /var/log/mount 1> /dev/null 2> /dev/null ; then
  exit
fi
# If the mount table is corrupt, the above might not do it, so we will
# try to detect Linux and FAT32 partitions that have slipped by:
if [ -d /var/log/mount/lost+found -o -d /var/log/mount/recycled \
     -o -r /var/log/mount/io.sys ]; then
  exit
fi
rm -f /var/log/mount 2> /dev/null
rmdir /var/log/mount 2> /dev/null
mkdir /var/log/mount 2> /dev/null
chmod 755 /var/log/mount

# An fstab file is indicative of an OS installation, rather than
# just loading the "setup" script and selecting "EXIT"
if [ -f ${T_PX}/etc/fstab ]; then
  # umount CD:
  if [ -r $TMP/SeTCDdev ]; then
    if mount | grep iso9660 > /dev/null 2> /dev/null ; then
      umount `mount | grep iso9660 | cut -f 1 -d ' '`
    fi
    eject -s `cat $TMP/SeTCDdev`
    # Tell the user to remove the disc, if one had previously been mounted
    # (it should now be ejected):
    dialog \
     --clear \
     --title "@CDISTRO@ Linux Setup is complete" "$@" \
     --msgbox "\nPlease remove the installation disc.\n" 7 40
  fi
  # Offer to reboot or drop to shell:
  dialog \
     --title "@CDISTRO@ Linux Setup is complete" "$@" \
     --yesno \
     "\nWould you like to reboot your system?\n\n\n\
If you choose \"No\", you will be dropped to a shell.\n" 11 50
    retval=$?
    if [ $retval = 1 ]; then
      clear
      echo
      echo "You may now reboot your system once you are ready."
      echo "You can issue the 'reboot' command; or if your system has"
      echo "a keyboard attached, you can use the key combination: control+alt+delete"
      echo
    else
      touch /reboot
    fi
fi

# Fix the date:
fixdate

# final cleanup
rm -f $TMP/tagfile $TMP/SeT* $TMP/tar-error $TMP/unsquash_output $TMP/unsquash_error $TMP/PKGTOOL_REMOVED
rm -f /var/log/mount/treecache
rmdir /var/log/mntiso 2>/dev/null
rm -rf $TMP/treecache
rm -rf $TMP/pkgcache
rmdir ${T_PX}/tmp/orbit-root 2> /dev/null

# If the OS had been installed and the user elected to reboot:
if [ -f /reboot ]; then
   clear
   echo "** Starting reboot **"
   sleep 1
   reboot
fi

# end slackware setup script
