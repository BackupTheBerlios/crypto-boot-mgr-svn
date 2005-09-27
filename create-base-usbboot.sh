#!/bin/sh
#
# create-base-usbboot.sh:
# -----------------------
#
# Copyright (C) 2005 by Marc Chatel, chatelm@yahoo.com
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#
#
# USB boot stick creation script:
#
# Creates from a scratch a basic USB boot disk.
#
# Makes many assumptions about the system where it runs:
#
# 1) assumes the system was installed with Fedora Core 3 or later,
#    that the "cryptsetup" utility is installed, and that the kernel
#    has support enabled for Device Mapper and the Device Mapper
#    crypto support (dm-crypt.ko).
#
# 2) assumes the RPM memtest86+ is installed
#
# 3) assumes a USB boot disk is detected as one of /dev/sda,
#    /dev/sdb, ...
#
# 4) does not support creating more than 4 primary partitions
#    on a USB boot disk, extended partitions are not supported.
#    The only partition types that this script knows how to
#    create are 0x06 (FAT16, created with filesystem type vfat),
#    and 0x83 (Linux, created with filesystem types ext2 or ext3).
#
# 5) The only boot loader that this script knows how to install
#    is GRUB. The script checks for its presence.
#
# 6) calculates megabytes and cylinders using integer arithmetic
#    only. Remainders from truncations tend to be allocated to the
#    last partition on the USB disk.
#    
# 7) assumes process "hald" (controlled by startup script
#    "haldaemon") is the only thing that may attempt to automount
#    freshly created USB disk partitions. This can interfere with
#    the script operation, so if process "hald" is running,
#    script "haldaemon" will be used to stop and start hald
#    during the script's operation.

CONFIG_DIR="./config"
BIN_DIR="."
TMP_DIR="/tmp"

TMPFILE1=$TMP_DIR/usbboot.tmp1.$$
TMPFILE2=$TMP_DIR/usbboot.tmp2.$$
TMPFILE3=$TMP_DIR/usbboot.tmp3.$$

if [ ! -f $BIN_DIR/shellfunctions.sh ]
then
   echo "*** Cannot find file shellfunctions.sh in dir $BIN_DIR"
   exit 1
fi

if [ ! -f $CONFIG_DIR/usbboot-main.conf ]
then
   echo "*** Cannot find file usbboot-main.conf in dir $CONFIG_DIR"
   exit 1
fi

. $BIN_DIR/shellfunctions.sh
. $CONFIG_DIR/usbboot-main.conf

DEV_DONE=0

echo "*** USB boot stick creation script ***"
echo "--------------------------------------"

# **** TODO ****: Put in check to detect if an RPM matching the
#                 pattern "memtest86*" is installed. If not,
#                 warn the user that we rely on this package
#                 to install the default boot entry.
#                 Also check for RPMs "cryptsetup", "device-mapper",
#                 "e2fsprogs", and "grub".
#                 Also check that $BIN_DIR/create-base-spacecalc
#                 exists. Also check that the system is running
#                 Fedora Core 3 or later.

if [ $BOOT_PARTITION -lt 1 -o $BOOT_PARTITION -gt $NUM_PARTITIONS ]
then
   echo "*** BOOT_PARTITIONS must be in the range 1-NUM_PARTITIONS"
   exit 1
fi

# **** TODO ****: Check that BOOT_PARTITION refers to a partition
#                 whose type is ext2 or ext3. If not, fatal error.

select_usb_dev $DEFAULT_WORK_DEV

NUM_LINES=`ps -ef | grep hald | grep -v grep | wc -l`
HAL_STOPPED=0

if [ $NUM_LINES -gt 0 ]
then
   echo -n "HAL daemon detected (causes auto mounts), stopping it "
   echo    "temporarily..."

   /etc/rc.d/init.d/haldaemon stop
   HAL_STOPPED=1
fi

echo ""
echo "Completed basic USB device checks, starting space calculations..."

# Now we can put in some simplified code that assumes the C program
# will do the checks...
#
PARM_LIST="$DEVICE_SIZE_MB $DEVICE_SIZE_CYLS"

if [ "X$TOTAL_PREFERRED_PERCENT_ALLOC" = "X" ]
then
   PARM_LIST="$PARM_LIST x"
else
   PARM_LIST="$PARM_LIST $TOTAL_PREFERRED_PERCENT_ALLOC"
fi

PARM_LIST="$PARM_LIST $NUM_PARTITIONS"

IDX=1
while [ $IDX -le $NUM_PARTITIONS ]
do
   PART_PERCENT_VAR=PARTITION_${IDX}_PREFERRED_SIZE_PERCENT
   PART_MINSIZE_VAR=PARTITION_${IDX}_MINSIZE_MB
   eval PART_PERCENT_VAL=\$$PART_PERCENT_VAR
   eval PART_MINSIZE_VAL=\$$PART_MINSIZE_VAR

   if [ "X$PART_PERCENT_VAL" = "X" ]
   then
      PARM_LIST="$PARM_LIST x"
   else
      PARM_LIST="$PARM_LIST $PART_PERCENT_VAL"
   fi

   if [ "X$PART_MINSIZE_VAL" = "X" ]
   then
      PARM_LIST="$PARM_LIST x"
   else
      PARM_LIST="$PARM_LIST $PART_MINSIZE_VAL"
   fi

   IDX=`expr $IDX + 1`
done

$BIN_DIR/create-base-spacecalc $PARM_LIST > $TMPFILE1

NUM_LINES=`grep "^ERROR " < $TMPFILE1 | wc -l`

if [ $NUM_LINES -gt 0 ]
then
   echo "*** Error occurred during space calculations. Exiting!"
   exit 1
fi

NUM_LINES=`grep "^OK$" < $TMPFILE1 | wc -l `

if [ $NUM_LINES -eq 0 ]
then
   echo "*** No OK status from space calculation program. Exiting!"
   exit 1
fi

# Output all informational lines from the calculation program.

grep -v "^ERROR " < $TMPFILE1 | grep -v "^OK " | grep -v "^OUTPUT "

# Read partition sizes in cylinders from the calculation program.

PART_IDX=1

while [ $PART_IDX -le $NUM_PARTITIONS ]
do
   grep "^OUTPUT $PART_IDX " < $TMPFILE1 > $TMPFILE2
   read T1 T2 T3 T4 < $TMPFILE2

   PART_CYLS_VAR=PARTITION_${PART_IDX}_NUM_CYLS

   eval $PART_CYLS_VAR=$T4
   eval PART_CYLS_VAL=\$$PART_CYLS_VAR

   PART_IDX=`expr $PART_IDX + 1`
done

rm -f $TMPFILE1 $TMPFILE2

echo "Configuration defines $NUM_PARTITIONS partitions..."
echo "-------------------------------------"

PART_IDX=1

while [ $PART_IDX -le $NUM_PARTITIONS ]
do
   PART_TYPE_VAR=PARTITION_${PART_IDX}_TYPE
   PART_CYLS_VAR=PARTITION_${PART_IDX}_NUM_CYLS
   eval PART_TYPE_VAL=\$$PART_TYPE_VAR
   eval PART_CYLS_VAL=\$$PART_CYLS_VAR

   if [ "X$PART_TYPE_VAL" = "" ]
   then
      echo "*** Variable $PART_TYPE_VAR is not defined. Exiting!"
      exit 1
   fi

   case $PART_TYPE_VAL in
      fat16) echo -n "Partition $PART_IDX will be FAT16 (Id=0x06), "
             echo    "fstype=vfat, size=$PART_CYLS_VAL cyls"
             ;;
      ext2)  echo -n "Partition $PART_IDX will be Linux (Id=0x83), "
             echo    "fstype=ext2, size=$PART_CYLS_VAL cyls"
             ;;
      ext3)  echo -n "Partition $PART_IDX will be Linux (Id=0x83), "
             echo    "fstype=ext3, size=$PART_CYLS_VAL cyls"
             ;;
      *)     echo "*** Partition $PART_IDX has an unknown type "
             echo "specified: $PART_TYPE_VAL"
             echo "*** Exiting!"
             exit 1
             ;;
   esac

   PART_IDX=`expr $PART_IDX + 1`
done

PROCEED=0

while [ $PROCEED -eq 0 ]
do
   echo -n "****** Now ready to rebuild partition table for "
   echo    "USB device ******"
   echo -n "****** Any previous data on the USB device will "
   echo    "be lost!   ******"
   echo -n "If you are ready to proceed, type 'yes' and hit ENTER: "
   read ANSWER

   if [ "X$ANSWER" = "X" ]
   then
      echo "Invalid answer, try again."
      continue
   fi

   ANSWER_UP=`echo $ANSWER | tr "[:lower:]" "[:upper:]"`

   if [ "$ANSWER_UP" = "YES" ]
   then
      break
   else
      echo "Invalid answer, try again."
   fi
done

echo "Erasing partition table for device..."
dd if=/dev/zero of=$ACTUAL_WORK_DEV bs=512 count=3 2> /dev/null
sync

echo "Creating new Master Boot Record for device..."
fdisk $ACTUAL_WORK_DEV << EOF1 > /dev/null 2>&1
w
EOF1

PART_IDX=1

while [ $PART_IDX -le $NUM_PARTITIONS ]
do
   # Get the partition type and size in cylinders
   PART_TYPE_VAR=PARTITION_${PART_IDX}_TYPE
   eval PART_TYPE=\$$PART_TYPE_VAR
   PART_SIZE_CYLS_VAR=PARTITION_${PART_IDX}_NUM_CYLS
   eval PART_SIZE_CYLS=\$$PART_SIZE_CYLS_VAR
   PART_SIZE_CYLS_MINUS=`expr $PART_SIZE_CYLS - 1`

   echo -n "Creating partition $PART_IDX, type=$PART_TYPE, "
   echo    "cyls=$PART_SIZE_CYLS"

   echo "n"                      >  $TMPFILE1
   echo "p"                      >> $TMPFILE1
   echo $PART_IDX                >> $TMPFILE1
   echo ""                       >> $TMPFILE1
   echo "+$PART_SIZE_CYLS_MINUS" >> $TMPFILE1

   if [ $PART_IDX -eq 1 ]
   then
      echo "t 1"                      >> $TMPFILE1
   else
      echo "t"       >> $TMPFILE1
      echo $PART_IDX >> $TMPFILE1
   fi

   case $PART_TYPE in
      fat16) echo "6"  >> $TMPFILE1
             ;;
      ext2)  echo "83" >> $TMPFILE1
             ;;
      ext3)  echo "83" >> $TMPFILE1
             ;;
   esac

   echo "w" >> $TMPFILE1

   fdisk $ACTUAL_WORK_DEV < $TMPFILE1 > /dev/null
   rm -f $TMPFILE1

   case $PART_TYPE in
      fat16) mkfs -t vfat $ACTUAL_WORK_DEV$PART_IDX
             ;;
      ext2)  mkfs -t ext2 $ACTUAL_WORK_DEV$PART_IDX > /dev/null 2>&1
             tune2fs -m 0 -i 0 $ACTUAL_WORK_DEV$PART_IDX
             ;;
      ext3)  mkfs -t ext3 $ACTUAL_WORK_DEV$PART_IDX > /dev/null 2>&1
             tune2fs -m 0 -i 0 $ACTUAL_WORK_DEV$PART_IDX
             ;;
      esac

   PART_IDX=`expr $PART_IDX + 1`
done

echo "Setting partition $BOOT_PARTITION to be bootable"
echo "a"             >  $TMPFILE1
echo $BOOT_PARTITION >> $TMPFILE1
echo "w"             >> $TMPFILE1

fdisk $ACTUAL_WORK_DEV < $TMPFILE1 > /dev/null
rm -f $TMPFILE1

TMP_MNT=$TMP_DIR/mnttmp-$$
mkdir $TMP_MNT

echo "Mounting boot partition $ACTUAL_WORK_DEV$BOOT_PARTITION..."
mount $ACTUAL_WORK_DEV$BOOT_PARTITION $TMP_MNT
echo "Installing GRUB on partition..."
grub-install --no-floppy --root-directory=$TMP_MNT $ACTUAL_WORK_DEV
echo "Copying some basic files to GRUB boot directory..."
DEVICE_OFFSET=`expr $BOOT_PARTITION - 1`
PREV_DIR=`pwd`
cd $TMP_MNT/boot/grub

CURR_DIR=`pwd`
if [ $CURR_DIR != "$TMP_MNT/boot/grub" ]
then
   echo "*** Fatal error, failed to change directory..."
   exit 1
fi

cp /boot/grub/splash.xpm.gz .
mv device.map device.map.original
cp $PREV_DIR/config/device.map .
touch grub.conf
echo -n "# This grub.conf file was generated by "   > grub.conf
echo    "create-base-usbboot.sh..."                >> grub.conf
echo "#"                                           >> grub.conf
echo "default=0"                                   >> grub.conf

if [ "X$DEFAULT_TIMEOUT" = "X" ]
then
   echo "timeout=50000"                            >> grub.conf
else
   echo "timeout=$DEFAULT_TIMEOUT"                 >> grub.conf
fi

echo -n "splashimage=(hd0,$DEVICE_OFFSET)/"        >> grub.conf
echo    "boot/grub/splash.xpm.gz"                  >> grub.conf
echo "#"                                           >> grub.conf
ln -s grub.conf menu.lst

ls /boot/memtest86* > $TMPFILE1 2> /dev/null
NUM_LINES=`wc -l < $TMPFILE1`
if [ $NUM_LINES -gt 0 ]
then
   echo "Found installation of memtest86 in /boot directory..."
   echo "Copying to USB drive as initial boot choice..."
   tail -1 < $TMPFILE1 > $TMPFILE2
   read MEMTEST86_LINE < $TMPFILE2
   rm -f $TMPFILE1 $TMPFILE2
   cp $MEMTEST86_LINE ..
   echo "title Memtest86"                  >> grub.conf
   echo "      root (hd0,$DEVICE_OFFSET)"  >> grub.conf
   echo "      kernel $MEMTEST86_LINE"     >> grub.conf
fi

cd $PREV_DIR

echo "Unmounting boot partition..."
umount $TMP_MNT
rmdir $TMP_MNT

if [ $HAL_STOPPED -ne 0 ]
then
   echo "Restarting HAL daemon..."
   /etc/rc.d/init.d/haldaemon start
fi

