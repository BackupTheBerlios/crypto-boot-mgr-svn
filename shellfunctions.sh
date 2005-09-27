#!/bin/sh
#
# shellfunctions.sh
# -----------------
# utility functions for crypto-boot-mgr
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

select_usb_dev()
{
   SEL_TMPFILE1=/tmp/sel_usbboot.tmp1.$$
   SEL_TMPFILE2=/tmp/sel_usbboot.tmp2.$$
   SEL_TMPFILE3=/tmp/sel_usbboot.tmp3.$$
   DEV_DONE=0
   SEL_DEFAULT_WORK_DEV=$1

   if [ "$2" = "quiet" ]
   then
      RUN_QUIET=1
   else
      RUN_QUIET=0
   fi

   while [ $DEV_DONE -eq 0 ]
   do
      ACTUAL_WORK_DEV=""
      AT_LEAST_ONE_CHECK_FAILED=0

      echo -n "Enter name of pseudo-device for "
      echo -n "USB boot stick [$SEL_DEFAULT_WORK_DEV]: "
      read REPLY

      if [ "X$REPLY" = "X" ]
      then
         ACTUAL_WORK_DEV=$SEL_DEFAULT_WORK_DEV
      else
         REPLY_LEN=`expr length $REPLY`

         if [ $REPLY_LEN -lt 8 ]
         then
            echo "*** Device name \"$REPLY\" is too short"
            AT_LEAST_ONE_CHECK_FAILED=1
         else
            REPLY_START=`expr substr $REPLY 1 7`

            if [ "$REPLY_START" = "/dev/sd" ]
            then
               ACTUAL_WORK_DEV=$REPLY
            else
               echo "*** Device name should start with /dev/sd"
               AT_LEAST_ONE_CHECK_FAILED=1
            fi

            REPLY_END=`expr substr $REPLY $REPLY_LEN 1 | \
                       sed -e 's/[0-9]/0/'`

            if [ "$REPLY_END" = "0" ]
            then
               echo "*** Device name should not end with a digit"
               AT_LEAST_ONE_CHECK_FAILED=1
            fi
         fi
      fi

      if [ $AT_LEAST_ONE_CHECK_FAILED -ne 0 ]
      then
         echo "Invalid device name, try again."
         continue
      fi

      # Now that we have an ACTUAL_WORK_DEV to try, check if the
      # device looks OK.

      if [ $RUN_QUIET -eq 0 ]
      then
         echo "Verifying device $ACTUAL_WORK_DEV..."
      fi
      fdisk -l $ACTUAL_WORK_DEV > $SEL_TMPFILE1 2>&1

      NUM_LINES=`wc -l < $SEL_TMPFILE1`

      if [ $NUM_LINES -eq 0 ]
      then
         echo "*** This device appears not to exist, try again."
         rm -f $SEL_TMPFILE1
         continue
      else
         DEVICE_SIZE_MB=`grep "^Disk $ACTUAL_WORK_DEV: " < $SEL_TMPFILE1 | \
                               sed -e 's,^Disk /dev/[a-z]*: ,,' \
                                   -e 's/ MB.*//'`
         DEVICE_SIZE_CYLS=`grep '[0-9]* heads, [0-9]* sectors/track, [0-9]* cylinders' \
            < $SEL_TMPFILE1 | sed -e 's/.*track, //' -e 's/ cylinders//'`

         if [ $DEVICE_SIZE_MB -gt 0 -a $DEVICE_SIZE_CYLS -gt 0 ]
         then
            if [ $RUN_QUIET -eq 0 ]
            then
               echo -n "Device exists, size is $DEVICE_SIZE_MB MB,"
               echo    " $DEVICE_SIZE_CYLS cyls"
            fi
         else
            echo -n "*** Cannot calculate the size of this device, "
            echo    "try again."
            continue
         fi
      fi
      rm -f $SEL_TMPFILE1

      df -k | grep $ACTUAL_WORK_DEV > $SEL_TMPFILE2 2>&1
      NUM_LINES1=`wc -l < $SEL_TMPFILE2`
      cat /proc/mounts | grep $ACTUAL_WORK_DEV > $SEL_TMPFILE3 2>&1
      NUM_LINES2=`wc -l < $SEL_TMPFILE3`

      if [ $NUM_LINES1 -gt 0 -o $NUM_LINES2 -gt 0 ]
      then
         echo -n "*** Device appears to be mounted. Either you are"
         echo    " not specifying the right"
         echo -n "*** device (and will destroy this one!), or you"
         echo    " should please unmount the"
         echo -n "*** device \"${ACTUAL_WORK_DEV}\" before running"
         echo    " this script."
         echo -n "*** Here is some output from the \"df -k\" "
         echo    "command:"
         echo -n "-------------------------------------------------"
         echo    "---------"
         cat $SEL_TMPFILE2
         echo -n "-------------------------------------------------"
         echo    "--------------"
         echo    "*** Here is relevant output from /proc/mounts:"
         echo -n "-------------------------------------------------"
         echo    "--------------"
         cat $SEL_TMPFILE3
         echo -n "-------------------------------------------------"
         echo    "--------------"

         rm -f $SEL_TMPFILE2 $SEL_TMPFILE3
         AT_LEAST_ONE_CHECK_FAILED=1
      else
         rm -f $SEL_TMPFILE2 $SEL_TMPFILE3

         if [ $RUN_QUIET -eq 0 ]
         then
            echo "Device appears not to be mounted: OK."
         fi
      fi

      if [ $AT_LEAST_ONE_CHECK_FAILED -eq 0 ]
      then
         DEV_DONE=1
      else
         echo "Invalid device name, try again."
      fi
   done
}  # select_usb_dev()

# ACTUAL_WORK_DEV=/dev/sda
#
# select_usb_dev $ACTUAL_WORK_DEV
# echo "DEVICE_SIZE_MB=$DEVICE_SIZE_MB"
# echo "DEVICE_SIZE_CYLS=$DEVICE_SIZE_CYLS"

list_configured_boot_configs()
{
   LIST_PREV_DIR=`pwd`

   cd $CONFIG_DIR

   HOST_LIST=`echo host-*`

   echo "Listing boot configurations in the config directory:"
   echo "----------------------------------------------------"

   if [ "$HOST_LIST" = 'host-*' ]
   then
      # echo "No host configurations"
      echo -n ""
   else
      CONFIG_NUM=1

      for H in $HOST_LIST
      do
         # echo "Host configuration: \"$H\""
         cd $H
         BOOT_LIST=`echo boot-conf-*`

         if [ "$BOOT_LIST" = 'boot-conf-*' ]
         then
            # echo "   No boot configurations"
            echo -n ""
         else
            for B in $BOOT_LIST
            do
               # echo "   Boot configuration \"$B\""

               BOOT_TYPE=""
               BOOT_LOADER=""
               BOOT_TITLE=""
               NUM_BOOT_LINES=0
               KERNEL_OPTIONS=""
               KERNEL_SMP=""
               KERNEL_INITRD_DIR=""
               KEY_DIR=""
               INITSCRIPT=""

               . $B

               printf "Boot config %2d: " $CONFIG_NUM
               FULL_TITLE="$H $BOOT_TITLE"
               echo "\"$FULL_TITLE\""
               CONFIG_BOOT_VAR=CONFIGURED_BOOT_CONF_$CONFIG_NUM
               CONFIG_BOOTFILE_VAR=CONFIGURED_BOOTFILE_$CONFIG_NUM
               eval $CONFIG_BOOT_VAR=\"$FULL_TITLE\"
               eval $CONFIG_BOOTFILE_VAR=\"$H/$B\"

               CONFIG_NUM=`expr $CONFIG_NUM + 1`
            done
         fi
         cd ..
      done
   fi

   echo "----------------------------------------------------"

   cd $LIST_PREV_DIR
}

list_actual_usb_configs()
{
   LIST_GRUB_CONF=$1

   echo "List of actual boot configurations on the USB boot disk:"
   echo "--------------------------------------------------------"

   TMPGRUBFILE1=$TMP_DIR/usbgrubconf.tmp1.$$
   CONFIG_NUM=1

   grep -i "^title" < $LIST_GRUB_CONF > $TMPGRUBFILE1

   while read F1 F2
   do
      printf "Boot config %2d: " $CONFIG_NUM
      echo "\"$F2\""

      ACTUAL_BOOT_VAR=ACTUAL_BOOT_CONF_$CONFIG_NUM
      # echo "ACTUAL_BOOT_VAR is $ACTUAL_BOOT_VAR"
      eval $ACTUAL_BOOT_VAR=\"$F2\"
      eval ACTUAL_BOOT_VAL=\$$ACTUAL_BOOT_VAR
      # echo "Value of variable $ACTUAL_BOOT_VAR is \"$ACTUAL_BOOT_VAL\""

      CONFIG_NUM=`expr $CONFIG_NUM + 1`
   done < $TMPGRUBFILE1

   rm -f $TMPGRUBFILE1
   echo "--------------------------------------------------------"
}

### Build a directory tree (root of tree will be $1)
### based on the shell variables NUM_DIR_BUILD_LINES and DIR_BUILD_nnn.
### Empty DIR_BUILD_nnn are ignored.

build_dir_tree()
{
   BUILD_DIR_ROOT=$1
   BUILD_DIR_RC=0

   if [ "X$BUILD_DIR_ROOT" = "X" ]
   then
      echo "*** build_dir_tree: directory parameter is empty ***"
      return
   fi

   if [ -e $BUILD_DIR_ROOT ]
   then
      echo -n "*** build_dir_tree: filename \"$BUILD_DIR_ROOT\""
      echo    "already exists ***"
      return
   fi

   if [ $NUM_DIR_BUILD_LINES -le 0 ]
   then
      echo "*** build_dir_tree: NUM_DIR_BUILD_LINES <= 0 ***"
      return
   fi

   mkdir $BUILD_DIR_ROOT

   BUILD_DIR_TMPFILE1=$TMP_DIR/build.dir.tmp1.$$
   BUILD_IDX=1

   while [ $BUILD_IDX -le $NUM_DIR_BUILD_LINES ]
   do
      DIR_BUILD_VAR=DIR_BUILD_$BUILD_IDX
      eval DIR_BUILD_VAL=\$$DIR_BUILD_VAR

      if [ "X$DIR_BUILD_VAL" = "X" ]
      then
         BUILD_IDX=`expr $BUILD_IDX + 1`
         continue
      fi

      echo $DIR_BUILD_VAL > $BUILD_DIR_TMPFILE1
      read B1 B2 B3 B4 B5 B6 B7 B8 < $BUILD_DIR_TMPFILE1
      rm -f $BUILD_DIR_TMPFILE1

      case $B1 in

      ##
      ## MKDIR  dest_dir_name dest_perm dest_user dest_grp
      ## sample: MKDIR lib 0755 root root
      ##
      MKDIR)          BLD_DEST_DIR_NAME=$B2
                      BLD_DEST_PERM=$B3
                      BLD_DEST_USER=$B4
                      BLD_DEST_GROUP=$B5

                      if [ "X$BLD_DEST_GROUP" = "X" ]
                      then
                         echo -n "*** MKDIR build spec $DIR_BUILD_VAR "
                         echo    "does not have four parameters"
                         return
                      fi

                      if [ -e $BUILD_DIR_ROOT/$BLD_DEST_DIR_NAME ]
                      then
                         echo -n "*** MKDIR target $BLD_DEST_DIR_NAME "
                         echo    "already exists"
                         return
                      fi

                      echo -n "  Creating dir \"$BLD_DEST_DIR_NAME\", "
                      echo -n "owner $BLD_DEST_USER:$BLD_DEST_GROUP, "
                      echo    "perms $BLD_DEST_PERM..."

                      mkdir $BUILD_DIR_ROOT/$BLD_DEST_DIR_NAME
                      chmod $BLD_DEST_PERM  \
                            $BUILD_DIR_ROOT/$BLD_DEST_DIR_NAME
                      chown $BLD_DEST_USER:$BLD_DEST_GROUP \
                              $BUILD_DIR_ROOT/$BLD_DEST_DIR_NAME
                      ;;

      ##
      ## MKLINK target_dir new_link -> link_value dest_user dest_grp
      ## sample: MKLINK usr bin -> ../bin root root
      ##
      MKLINK)         BLD_DIR_WHERE_CREATED=$B2
                      BLD_NEW_LINK_NAME=$B3
                      BLD_ARROW=$B4
                      BLD_LINK_VALUE=$B5
                      BLD_DEST_USER=$B6
                      BLD_DEST_GROUP=$B7

                      if [ "X$BLD_DEST_GROUP" = "X" ]
                      then
                         echo -n "*** MKLINK build spec $DIR_BUILD_VAR "
                         echo    "does not have six parameters"
                         return
                      fi

                      if [ "$BLD_ARROW" != "->" ]
                      then
                         echo -n "*** MKLINK build spec $DIR_BUILD_VAR "
                         echo    "must have \"->\" as 3rd parameter"
                         return
                      fi

                      echo -n "  Creating link "
                      echo -n "\"$BLD_DIR_WHERE_CREATED/"
                      echo -n "$BLD_NEW_LINK_NAME\","
                      echo -n "owner $BLD_DEST_USER:$BLD_DEST_GROUP, "
                      echo    "perms $BLD_DEST_PERM..."

                      PREV_DIR_MKLINK=`pwd`
                      cd $BUILD_DIR_ROOT/$BLD_DIR_WHERE_CREATED
                      ln -s $BLD_LINK_VALUE $BLD_NEW_LINK_NAME
                      chown -h $BLD_DEST_USER:$BLD_DEST_GROUP \
                               $BLD_NEW_LINK_NAME
                      cd $PREV_DIR_MKLINK
                      ;;

      ##
      ## REPLICATEFILE src_dir filename dest_dir
      ##                                dest_perm dest_user dest_grp
      ## sample: REPLICATEFILE /bin bash bin 0755 root root
      ##
      REPLICATEFILE)  BLD_SRC_DIR=$B2
                      BLD_SRC_FILENAME=$B3
                      BLD_DEST_DIR=$B4
                      BLD_DEST_PERM=$B5
                      BLD_DEST_USER=$B6
                      BLD_DEST_GROUP=$B7

                      if [ "X$BLD_DEST_GROUP" = "X" ]
                      then
                         echo -n "*** REPLICATEFILE build spec "
                         echo -n "$DIR_BUILD_VAR "
                         echo    "does not have six parameters"
                         return
                      fi

                      if [ ! -d $BLD_SRC_DIR ]
                      then
                         echo -n "*** REPLICATEFILE 1st param: "
                         echo -n "SRC_DIR=\"$BLD_SRC_DIR\" "
                         echo -n "should be a directory"
                         return
                      fi

                      echo -n "  Copying "
                      echo -n "$BLD_SRC_DIR/$BLD_SRC_FILENAME to "
                      echo -n "$BLD_DEST_DIR, perms $BLD_DEST_PERM, "
                      echo    "owner $BLD_DEST_USER:$BLD_DEST_GROUP"

                      cp $BLD_SRC_DIR/$BLD_SRC_FILENAME \
                            $BUILD_DIR_ROOT/$BLD_DEST_DIR
                      chown $BLD_DEST_USER:$BLD_DEST_GROUP \
                        $BUILD_DIR_ROOT/$BLD_DEST_DIR/$BLD_SRC_FILENAME
                      chmod $BLD_DEST_PERM \
                        $BUILD_DIR_ROOT/$BLD_DEST_DIR/$BLD_SRC_FILENAME
                      ;;

      ##
      ## REPLICATEFILES src_dir filespec dest_dir
      ##                                 dest_perm dest_user dest_grp
      ## sample: REPLICATEFILES /usr/lib libz.so.* lib 0755 root root
      ##
      REPLICATEFILES) BLD_SRC_DIR=$B2
                      BLD_SRC_FILESPEC=$B3
                      BLD_DEST_DIR=$B4
                      BLD_DEST_PERM=$B5
                      BLD_DEST_USER=$B6
                      BLD_DEST_GROUP=$B7

                      if [ "X$BLD_DEST_GROUP" = "X" ]
                      then
                         echo -n "*** REPLICATEFILES build spec "
                         echo -n "$DIR_BUILD_VAR "
                         echo    "does not have six parameters"
                         return
                      fi

                      if [ ! -d $BLD_SRC_DIR ]
                      then
                         echo -n "*** REPLICATEFILES 1st param: "
                         echo -n "SRC_DIR=\"$BLD_SRC_DIR\" "
                         echo -n "should be a directory"
                         return
                      fi

                      PREV_DIR_REPLFILES=`pwd`
                      cd $BLD_SRC_DIR
                      PRELIM_EXP_RC=`echo $BLD_SRC_FILESPEC`

                      if [ "$PRELIM_EXP_RC" = "$BLD_SRC_FILESPEC" ]
                      then
                         echo -n "*** REPLICATEFILES 2nd parm: "
                         echo -n "SRC_FILESPEC=\"$BLD_SRC_FILESPEC\" "
                         echo -n "not found in "
                         echo -n "dir \"$BLD_SRC_DIR\""
                         return
                      fi

                      ACTUAL_EXP_RC=""

                      for F in $PRELIM_EXP_RC
                      do
                         if [ ! -h $F -a ! -d $F -a -f $F ]
                         then
                            ACTUAL_EXP_RC="$ACTUAL_EXP_RC $F"
                         fi
                      done

                      for F in $ACTUAL_EXP_RC
                      do
                         echo -n "  Copying "
                         echo -n "$BLD_SRC_DIR/$F to "
                         echo -n "$BLD_DEST_DIR, perms $BLD_DEST_PERM, "
                         echo    "owner $BLD_DEST_USER:$BLD_DEST_GROUP"

                         cp $F $BUILD_DIR_ROOT/$BLD_DEST_DIR
                         chown $BLD_DEST_USER:$BLD_DEST_GROUP \
                               $BUILD_DIR_ROOT/$BLD_DEST_DIR/$F
                         chmod $BLD_DEST_PERM \
                               $BUILD_DIR_ROOT/$BLD_DEST_DIR/$F
                      done

                      cd $PREV_DIR_REPLFILES
                      ;;

      ##
      ## REPLICATELINK src_dir filename dest_dir dest_user dest_grp
      ## sample: REPLICATELINK /lib libc.so lib root root
      ##
      REPLICATELINK)  BLD_SRC_DIR=$B2
                      BLD_SRC_LINKNAME=$B3
                      BLD_DEST_DIR=$B4
                      BLD_DEST_USER=$B5
                      BLD_DEST_GROUP=$B6

                      if [ "X$BLD_DEST_GROUP" = "X" ]
                      then
                         echo -n "*** REPLICATELINK build spec "
                         echo -n "$DIR_BUILD_VAR "
                         echo    "does not have five parameters"
                         return
                      fi

                      if [ ! -d $BLD_SRC_DIR ]
                      then
                         echo -n "*** REPLICATELINK 1st param: "
                         echo -n "SRC_DIR=\"$BLD_SRC_DIR\" "
                         echo    "should be a directory"
                         return
                      fi

                      if [ ! -h $BLD_SRC_DIR/$BLD_SRC_LINKNAME ]
                      then
                         echo -n "*** REPLICATELINK 2nd param: "
                         echo -n "\"$BLD_SRC_LINKNAME\" should "
                         echo    "be a logical link"
                         return
                      fi

                      PREV_DIR_REPLLINK=`pwd`

                      cd $BLD_SRC_DIR
                      LINK_TARGET=`readlink $BLD_SRC_LINKNAME`

                      cd $BUILD_DIR_ROOT/$BLD_DEST_DIR

                      echo -n "  Creating link "
                      echo -n "$BLD_SRC_LINKNAME in dir "
                      echo -n "$BLD_DEST_DIR, owner "
                      echo    "$BLD_DEST_USER:$BLD_DEST_GROUP"

                      ln -s $LINK_TARGET $BLD_SRC_LINKNAME
                      chown -h $BLD_DEST_USER:$BLD_DEST_GROUP \
                                  $BLD_SRC_LINKNAME

                      cd $PREV_DIR_REPLLINK
                      ;;

      ##
      ## REPLICATELINKS src_dir filespec dest_dir dest_user dest_grp
      ## sample: REPLICATELINKS /lib libc.so.* lib root root
      ##
      REPLICATELINKS) BLD_SRC_DIR=$B2
                      BLD_SRC_LINKSPEC=$B3
                      BLD_DEST_DIR=$B4
                      BLD_DEST_USER=$B5
                      BLD_DEST_GROUP=$B6

                      if [ "X$BLD_DEST_GROUP" = "X" ]
                      then
                         echo -n "*** REPLICATELINKS build spec "
                         echo -n "$DIR_BUILD_VAR "
                         echo    "does not have five parameters"
                         return
                      fi

                      if [ ! -d $BLD_SRC_DIR ]
                      then
                         echo -n "*** REPLICATELINKS 1st param: "
                         echo -n "SRC_DIR=\"$BLD_SRC_DIR\" "
                         echo    "should be a directory"
                         return
                      fi

                      PREV_DIR_REPLLINKS=`pwd`

                      cd $BLD_SRC_DIR
                      PRELIM_EXP_RC=`echo $BLD_SRC_LINKSPEC`

                      if [ "$PRELIM_EXP_RC" = "$BLD_SRC_LINKSPEC" ]
                      then
                         echo -n "*** REPLICATELINKS 2nd parm: "
                         echo -n "SRC_FILESPEC=\"$BLD_SRC_LINKSPEC\" "
                         echo -n "not found in "
                         echo -n "dir \"$BLD_SRC_DIR\""
                         return
                      fi

                      ACTUAL_EXP_RC=""

                      for L in $PRELIM_EXP_RC
                      do
                         if [ -h $L ]
                         then
                            ACTUAL_EXP_RC="$ACTUAL_EXP_RC $L"
                         fi
                      done

                      for L in $ACTUAL_EXP_RC
                      do
                         cd $BLD_SRC_DIR
                         L_TARGET=`readlink $L`
                         cd $BUILD_DIR_ROOT/$BLD_DEST_DIR

                         echo -n "  Creating link "
                         echo -n "$L in dir $BLD_DEST_DIR, owner "
                         echo    "$BLD_DEST_USER:$BLD_DEST_GROUP"

                         ln -s $L_TARGET $L
                         chown -h $BLD_DEST_USER:$BLD_DEST_GROUP $L
                      done

                      cd $PREV_DIR_REPLLINKS
                      ;;

      ##
      ## REPLICATEDEV  src_dir filename dest_dir
      ##                                dest_perm dest_user dest_grp
      ## sample: REPLICATEDEV /dev console dev 0600 root root
      ##
      REPLICATEDEV)   BLD_SRC_DIR=$B2
                      BLD_SRC_DEVNAME=$B3
                      BLD_DEST_DIR=$B4
                      BLD_DEST_PERM=$B5
                      BLD_DEST_USER=$B6
                      BLD_DEST_GROUP=$B7

                      if [ "X$BLD_DEST_GROUP" = "X" ]
                      then
                         echo -n "*** REPLICATEDEV build spec "
                         echo -n "$DIR_BUILD_VAR "
                         echo    "does not have six parameters"
                         return
                      fi

                      if [ ! -d $BLD_SRC_DIR ]
                      then
                         echo -n "*** REPLICATEDEV 1st param: "
                         echo -n "SRC_DIR=\"$BLD_SRC_DIR\" "
                         echo -n "should be a directory"
                         return
                      fi

                      if [ -h $BLD_SRC_DIR/$BLD_SRC_DEVNAME ]
                      then
                         echo -n "*** REPLICATEDEV 2nd param: "
                         echo -n "\"$BLD_SRC_DEVNAME\" is a logical "
                         echo    "link instead of a device"
                         return
                      fi

                      if [ ! -b $BLD_SRC_DIR/$BLD_SRC_DEVNAME -a \
                           ! -c $BLD_SRC_DIR/$BLD_SRC_DEVNAME ]
                      then
                         echo -n "*** REPLICATEDEV 2nd param: "
                         echo -n "\"$BLD_SRC_DEVNAME\" is not a "
                         echo    "device"
                         return
                      fi

                      echo -n "  Copying "
                      echo -n "$BLD_SRC_DIR/$BLD_SRC_DEVNAME to "
                      echo -n "$BLD_DEST_DIR, perms $BLD_DEST_PERM, "
                      echo    "owner $BLD_DEST_USER:$BLD_DEST_GROUP"

                      PREV_DIR_REPLDEV=`pwd`

                      cd $BLD_SRC_DIR
                      tar cpf - $BLD_SRC_DEVNAME | (cd $BUILD_DIR_ROOT/$BLD_DEST_DIR; tar xpf - )
                      cd $PREV_DIR_REPLDEV

                      chown $BLD_DEST_USER:$BLD_DEST_GROUP \
                        $BUILD_DIR_ROOT/$BLD_DEST_DIR/$BLD_SRC_DEVNAME
                      chmod $BLD_DEST_PERM \
                        $BUILD_DIR_ROOT/$BLD_DEST_DIR/$BLD_SRC_DEVNAME
                      ;;

      ##
      ## MKEMPTYFILE new_relative_path_name dest_perm dest_user dest_grp
      ## sample: MKEMPTYFILE etc/fstab 0644 root root
      ##
      MKEMPTYFILE)    ## Build directive MKEMPTYFILE

                      BLD_NEW_PATH_NAME=$B2
                      BLD_DEST_PERM=$B3
                      BLD_DEST_USER=$B4
                      BLD_DEST_GROUP=$B5

                      if [ "X$BLD_DEST_GROUP" = "X" ]
                      then
                         echo -n "*** MKEMPTYFILE build spec "
                         echo -n "$DIR_BUILD_VAR "
                         echo    "does not have four parameters"
                         return
                      fi

                      touch $BUILD_DIR_ROOT/$BLD_NEW_PATH_NAME
                      chmod $BLD_DEST_PERM \
                            $BUILD_DIR_ROOT/$BLD_NEW_PATH_NAME
                      chown $BLD_DEST_USER:$BLD_DEST_GROUP \
                            $BUILD_DIR_ROOT/$BLD_NEW_PATH_NAME
                      ;;

      *)              ## Unexpected build directive

                      echo -n "*** Build spec $DIR_BUILD_VAR "
                      echo "uses unknown directive \"$B1\""
                      return
                      ;;
      esac

      BUILD_IDX=`expr $BUILD_IDX + 1`
   done

   BUILD_DIR_RC=1
}

