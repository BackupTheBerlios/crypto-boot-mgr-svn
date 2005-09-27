#!/bin/sh
#
# add-boot-config.sh:
# -------------------
#
# Adds a boot menu entry to the USB memory stick.
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

###### Code that checks and echoes all the variables obtained
###### from list_configured_boot_configs
###
### DONE=0
### CONFIG_NUM=1
### 
### while [ $DONE -eq 0 ]
### do
###    BOOT_CONF_VAR=CONFIGURED_BOOT_CONF_$CONFIG_NUM
###    eval BOOT_CONF_VAL=\$$BOOT_CONF_VAR
### 
###    if [ "X$BOOT_CONF_VAL" = "X" ]
###    then
###       DONE=1
###    else
###       echo "Variable $BOOT_CONF_VAR is \"$BOOT_CONF_VAL\""
###    fi
### 
###    CONFIG_NUM=`expr $CONFIG_NUM + 1`
### done

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
   list_actual_usb_configs $GRUB_CONF

   ###### Code that checks and shows all the variables
   ###### obtained by list_actual_usb_configs
   ###
   ### DONE=0
   ### CONFIG_NUM=1
   ### 
   ### while [ $DONE -eq 0 ]
   ### do
   ###    BOOT_CONF_VAR=ACTUAL_BOOT_CONF_$CONFIG_NUM
   ###    eval BOOT_CONF_VAL=\$$BOOT_CONF_VAR
   ###
   ###    if [ "X$BOOT_CONF_VAL" = "X" ]
   ###    then
   ###       DONE=1
   ###    else
   ###       echo "Variable $BOOT_CONF_VAR is \"$BOOT_CONF_VAL\""
   ###    fi
   ### 
   ###    CONFIG_NUM=`expr $CONFIG_NUM + 1`
   ### done
fi

umount $TMP_MNT
rmdir $TMP_MNT

### TODO: Find list of CONFIGURED_BOOT_CONF_n
### that have values that do not exist in
### the list of ACTUAL_BOOT_CONF_n

CAN_BE_ADDED_LIST=""

DONE_OUTER=0
CONFIG_NUM_OUTER=1
 
while [ $DONE_OUTER -eq 0 ]
do
   OUTER_BOOT_CONF_VAR=CONFIGURED_BOOT_CONF_$CONFIG_NUM_OUTER
   eval OUTER_BOOT_CONF_VAL=\$$OUTER_BOOT_CONF_VAR

   if [ "X$OUTER_BOOT_CONF_VAL" = "X" ]
   then
      DONE_OUTER=1
   else
      ### echo "Variable $OUTER_BOOT_CONF_VAR is
      ###       \"$OUTER_BOOT_CONF_VAL\""

      DONE_INNER=0
      MATCHED_OUTER=0
      CONFIG_NUM_INNER=1

      while [ $DONE_INNER -eq 0 ]
      do
         INNER_BOOT_CONF_VAR=ACTUAL_BOOT_CONF_$CONFIG_NUM_INNER
         eval INNER_BOOT_CONF_VAL=\$$INNER_BOOT_CONF_VAR
     
         if [ "X$INNER_BOOT_CONF_VAL" = "X" ]
         then
            DONE_INNER=1
         else
###         echo "Variable $INNER_BOOT_CONF_VAR is
###                  \"$INNER_BOOT_CONF_VAL\""
            if [ "$INNER_BOOT_CONF_VAL" = "$OUTER_BOOT_CONF_VAL" ]
            then
               MATCHED_OUTER=1
            fi
         fi
      
         CONFIG_NUM_INNER=`expr $CONFIG_NUM_INNER + 1`
      done

      if [ $MATCHED_OUTER -eq 0 ]
      then
         CAN_BE_ADDED_LIST="$CAN_BE_ADDED_LIST $CONFIG_NUM_OUTER"
      fi
   fi

   CONFIG_NUM_OUTER=`expr $CONFIG_NUM_OUTER + 1`
done

echo ""
echo "Here is the list of boot configurations"
echo "that can currently be added:"
echo "---------------------------------------"
for CONFIG_NUM in $CAN_BE_ADDED_LIST
do
   BOOT_CONF_VAR=CONFIGURED_BOOT_CONF_$CONFIG_NUM
   eval BOOT_CONF_VAL=\$$BOOT_CONF_VAR
   printf "Boot config %2d: " $CONFIG_NUM
   echo "\"$BOOT_CONF_VAL\""
done
echo "---------------------------------------"
echo ""

GOOD_CONFIG_SELECTED=0

while [ $GOOD_CONFIG_SELECTED -eq 0 ]
do
   echo -n "Enter the number of a configuration to add: "
   read TO_ADD_NUMBER

   if [ "X$TO_ADD_NUMBER" = "X" ]
   then
      echo "*** Empty reply, try again."
   else
      for C in $CAN_BE_ADDED_LIST
      do
         if [ "$C" = "$TO_ADD_NUMBER" ]
         then
            GOOD_CONFIG_SELECTED=1
         fi
      done

      if [ $GOOD_CONFIG_SELECTED -eq 0 ]
      then
         echo "*** Invalid reply, try again."
      fi
   fi
done

BOOT_CONF_VAR=CONFIGURED_BOOT_CONF_$TO_ADD_NUMBER
eval TO_ADD_CONF_VAL=\$$BOOT_CONF_VAR
BOOTFILE_VAR=CONFIGURED_BOOTFILE_$TO_ADD_NUMBER
eval TO_ADD_BOOTFILE=\$$BOOTFILE_VAR
echo    ""
echo -n "Preparing to add config number "
echo    "$TO_ADD_NUMBER: \"$TO_ADD_CONF_VAL\""
# echo    "stored in file $TO_ADD_BOOTFILE"

BOOT_TYPE=""
BOOT_LOADER=""
BOOT_TITLE=""
NUM_BOOT_LINES=0
KERNEL_OPTIONS=""
KERNEL_SMP=""
KERNEL_INITRD_DIR=""
KEY_DIR=""
INITSCRIPT=""
INITCONF=""

. $CONFIG_DIR/$TO_ADD_BOOTFILE

case $BOOT_TYPE in

FOREIGN) echo "Processing FOREIGN boot type..."

         if [ "$BOOT_LOADER" = "GRUB" ]
         then
            echo "Installing for GRUB boot loader..."

            TMP_MNT=$TMP_DIR/mnttmp-$$
            mkdir $TMP_MNT
            GRUB_CONF=$TMP_MNT/boot/grub/grub.conf
            MOUNT_DEV=$ACTUAL_WORK_DEV$BOOT_PARTITION

            echo -n "Mounting boot partition $MOUNT_DEV "
            echo    "in READ/WRITE mode..."
            mount $MOUNT_DEV $TMP_MNT

            echo "Adding configuration data to GRUB config file..."

            echo "title $TO_ADD_CONF_VAL" >> $GRUB_CONF

            BOOT_IDX=1
            while [ $BOOT_IDX -le $NUM_BOOT_LINES ]
            do
               BOOT_LINE_VAR=BOOT_LINE_$BOOT_IDX
               eval BOOT_LINE_VAL=\$$BOOT_LINE_VAR

               echo "   $BOOT_LINE_VAL" >> $GRUB_CONF

               BOOT_IDX=`expr $BOOT_IDX + 1`
            done

            echo "Flushing buffers..."
            sync
            echo "Unmounting USB drive..."
            umount $TMP_MNT
            rmdir $TMP_MNT
            echo "*** Added boot configuration *** "
         else
            echo "*** Unsupported boot loader \"$BOOT_LOADER\""
         fi
         ;;

  LINUX) # echo "Trying to add Linux boot type..."
         echo ""
         LINUX_BOOT_PREVDIR=`pwd`
         cd /boot
         RAW_KERNEL_LIST=`echo vmlinuz-*`
         cd $LINUX_BOOT_PREVDIR

         if [ "$RAW_KERNEL_LIST" = 'vmlinuz-*' ]
         then
            echo "*** Did not find any vmlinuz- files in /boot ***"
            exit 1
         fi

         VALID_KERNELS=""

         for KFILE in $RAW_KERNEL_LIST
         do
            echo -n "Checking out kernel possibility $KFILE... "

            KERNEL_SEEMS_SMP=`echo $KFILE | grep -i smp`

            if [ $KERNEL_SMP -ne 0 -a "X$KERNEL_SEEMS_SMP" = "X" ]
            then
               echo    ""
               echo -n "   Need SMP kernel and kernel seems non-SMP, "
               echo    "skipping..."
               continue
            fi

            if [ $KERNEL_SMP -eq 0 -a "X$KERNEL_SEEMS_SMP" != "X" ]
            then
               echo    ""
               echo -n "   Need non-SMP kernel and kernel seems SMP, "
               echo    "skipping..."
               continue
            fi

            KFILE_LEN=`expr length $KFILE`
            KFILE_SUFFIX_LEN=`expr $KFILE_LEN - 8`
            KFILE_SUFFIX=`expr substr $KFILE 9 $KFILE_SUFFIX_LEN`

            if [ ! -d /lib/modules/$KFILE_SUFFIX ]
            then
               echo ""
               echo "   Did not find modules directory, skipping..."
               continue
            fi

            . $CONFIG_DIR/initrd-std-build.conf

            SOME_MODULES_FAILED=0

            for M in $MODULE_LIST
            do
               if [ ! -f /lib/modules/$KFILE_SUFFIX/kernel/$M ]
               then
                  echo    ""
                  echo -n "   Kernel module directory does "
                  echo    "not contain $M..."
                  SOME_MODULES_FAILED=1
               fi
            done

            if [ $SOME_MODULES_FAILED -ne 0 ]
            then
               echo    ""
               echo -n "   One or more kernel module checks "
               echo    "failed, skipping..."
               continue
            fi

            echo "seems OK."
            VALID_KERNELS="$VALID_KERNELS $KFILE"
         done

         echo ""

         if [ "X$VALID_KERNELS" = "X" ]
         then
            echo "*** No valid kernels found. Exiting..."
            exit 1
         fi

         echo "List of kernels to choose from for Linux $BOOT_LOADER boot"
         echo "configuration named \"$TO_ADD_CONF_VAL\":"
         echo "--------------------------------------------------"
         TMP_IDX=1
         for K in $VALID_KERNELS
         do
            printf "%2d- %s\n" $TMP_IDX $K
            TMP_IDX=`expr $TMP_IDX + 1`
         done
         echo "--------------------------------------------------"

         CHOSEN_KERNEL_BOOL=0
         CHOSEN_KERNEL=""

         while [ $CHOSEN_KERNEL_BOOL -eq 0 ]
         do
            echo -n "Enter the number of the kernel you want: "
            read CHOSEN_KERNEL_IDX

            if [ "X$CHOSEN_KERNEL_IDX" = "X" ]
            then
               echo "*** Try again ***"
               continue
            fi

            if [ $CHOSEN_KERNEL_IDX -le 0 ]
            then
               echo "*** Must be a number greater than 0 ***"
               continue
            fi

            TMP_IDX=1
            for K in $VALID_KERNELS
            do
               if [ $TMP_IDX -eq $CHOSEN_KERNEL_IDX ]
               then
                  CHOSEN_KERNEL=$K
                  CHOSEN_KERNEL_BOOL=1
                  break
               fi
               TMP_IDX=`expr $TMP_IDX + 1`
            done

            if [ $CHOSEN_KERNEL_BOOL -eq 0 ]
            then
               echo "*** Invalid entry. Try again. ***"
            fi
         done

         echo "Selected kernel is \"$CHOSEN_KERNEL\""
         KFILE_LEN=`expr length $CHOSEN_KERNEL`
         KFILE_SUFFIX_LEN=`expr $KFILE_LEN - 8`
         KERNEL_SUFFIX=`expr substr $CHOSEN_KERNEL 9 $KFILE_SUFFIX_LEN`
         echo "Kernel version is \"$KERNEL_SUFFIX\""

         echo "Creating custom initrd image for this kernel..."
         TMP_INITRD=$TMP_DIR/initrd-bld1.$$

         build_dir_tree $TMP_INITRD

         if [ $BUILD_DIR_RC -eq 0 ]
         then
            echo "*** build_dir_tree failed ***"
            rm -rf $TMP_INITRD
            exit 1
         fi         

         ### If we get here, the general initrd tree has
         ### been built successfully. Now, let's install the
         ### modules for the chosen kernel in the future
         ### initrd image.

         MODULE_TARGET_DIR=lib/modules/$KERNEL_SUFFIX
         echo "  Creating directory $MODULE_TARGET_DIR"
         mkdir $TMP_INITRD/$MODULE_TARGET_DIR

         for M in $MODULE_LIST
         do
            echo "  Copying module $M to $MODULE_TARGET_DIR"
            cp /lib/modules/$KERNEL_SUFFIX/kernel/$M $TMP_INITRD/$MODULE_TARGET_DIR
         done

         # Copy init and init.conf to initrd image

         echo "  Adding init script to initrd image..."
         cp $CONFIG_DIR/$INITSCRIPT $TMP_INITRD/init
         chown root:root $TMP_INITRD/init
         chmod 755 $TMP_INITRD/init

         echo "  Adding init.conf to initrd image..."
         cp $CONFIG_DIR/$INITCONF   $TMP_INITRD/init.conf
         chown root:root $TMP_INITRD/init.conf
         chmod 644 $TMP_INITRD/init.conf

         # Manually create /init.final

         echo "  Adding init.final to initrd image..."

         echo "#!/bin/nash"         >  $TMP_INITRD/init.final
         echo ""                    >> $TMP_INITRD/init.final
         echo "switchroot /sysroot" >> $TMP_INITRD/init.final
         chown root:root $TMP_INITRD/init.final
         chmod 755       $TMP_INITRD/init.final

         echo "  Building initrd compressed cpio image..."
         TMP_INITRD_FILE=$TMP_DIR/initrd.img.tmp1.$$
         PREV_DIR_BLD_INITRD=`pwd`
         cd $TMP_INITRD
         find . -print | cpio -o -c | gzip -9 > $TMP_INITRD_FILE
         cd $PREV_DIR_BLD_INITRD

         rm -rf $TMP_INITRD

         echo "Ready to place on USB stick the initrd image,"
         echo "the kernel image, the keys directory,"
         echo "and to add the appropriate lines to grub.conf"

         # set -x
         mkdir $TMP_MNT
         mount -o rw $MOUNT_DEV $TMP_MNT

         mkdir $TMP_MNT/boot/$KERNEL_INITRD_DIR
         cp $TMP_INITRD_FILE $TMP_MNT/boot/$KERNEL_INITRD_DIR/initrd.img
         rm -f $TMP_INITRD_FILE
         cp /boot/$CHOSEN_KERNEL $TMP_MNT/boot/$KERNEL_INITRD_DIR

         if [ ! -d $TMP_MNT/boot/$KEY_DIR ]
         then
            mkdir -p $TMP_MNT/boot/$KEY_DIR
            cp $CONFIG_DIR/$KEY_DIR/*.crypt $TMP_MNT/boot/$KEY_DIR
         fi

         echo "title $TO_ADD_CONF_VAL" >> $TMP_MNT/boot/grub/grub.conf
         BOOT_LINE_ID=1
         while [ $BOOT_LINE_ID -le $NUM_BOOT_LINES ]
         do
            BOOT_LINE_VAR=BOOT_LINE_${BOOT_LINE_ID}
            eval BOOT_LINE_VAL=\$$BOOT_LINE_VAR
            echo "$BOOT_LINE_VAL" >> $TMP_MNT/boot/grub/grub.conf

            BOOT_LINE_ID=`expr $BOOT_LINE_ID + 1`
         done

         echo "      kernel /boot/$KERNEL_INITRD_DIR/$CHOSEN_KERNEL $KERNEL_OPTIONS" >> $TMP_MNT/boot/grub/grub.conf
         echo "      initrd /boot/$KERNEL_INITRD_DIR/initrd.img" >> $TMP_MNT/boot/grub/grub.conf

         sync
         sync
         sleep 3
         umount $TMP_MNT
         rmdir $TMP_MNT
         ;;

      *) echo "*** Unsupported boot type \"$BOOT_TYPE\" ***"
         ;;
esac


