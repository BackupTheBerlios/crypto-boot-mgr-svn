#!/bin/sh
#
# list-boot-configs.sh:
# ---------------------
#
# Copyright (C) 2005,2006 by Marc Chatel, chatelm@yahoo.com
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
CONFIG_DIR=./config
BIN_DIR="."
TMP_DIR=/tmp

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

list_configured_boot_configs

DONE=0
CONFIG_NUM=1

while [ $DONE -eq 0 ]
do
   BOOT_CONF_VAR=CONFIGURED_BOOT_CONF_$CONFIG_NUM
   eval BOOT_CONF_VAL=\$$BOOT_CONF_VAR

   if [ "X$BOOT_CONF_VAL" = "X" ]
   then
      DONE=1
   else
      echo "Variable $BOOT_CONF_VAR is \"$BOOT_CONF_VAL\""
   fi

   CONFIG_NUM=`expr $CONFIG_NUM + 1`
done

echo ""
select_usb_dev $DEFAULT_WORK_DEV quiet

TMP_MNT=$TMP_DIR/mnttmp-$$
mkdir $TMP_MNT
GRUB_CONF=$TMP_MNT/boot/grub/grub.conf
MOUNT_DEV=$ACTUAL_WORK_DEV$BOOT_PARTITION

echo "Mounting boot partition $MOUNT_DEV..."
mount -o ro $MOUNT_DEV $TMP_MNT
echo ""

if [ ! -f $GRUB_CONF ]
then
   echo -n "*** Cannot mount partition $MOUNT_DEV, or cannot "
   echo    "find GRUB config"
else
   list_actual_boot_configs $GRUB_CONF
   DONE=0
   CONFIG_NUM=1

   while [ $DONE -eq 0 ]
   do
      BOOT_CONF_VAR=ACTUAL_BOOT_CONF_$CONFIG_NUM
      eval BOOT_CONF_VAL=\$$BOOT_CONF_VAR

      if [ "X$BOOT_CONF_VAL" = "X" ]
      then
         DONE=1
      else
         echo "Variable $BOOT_CONF_VAR is \"$BOOT_CONF_VAL\""
      fi

      CONFIG_NUM=`expr $CONFIG_NUM + 1`
   done
fi

umount $TMP_MNT
rmdir $TMP_MNT

### TODO: Find list of CONFIGURED_BOOT_CONF_n
### that have values that do not exist in
### the list of ACTUAL_BOOT_CONF_n

