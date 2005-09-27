#!/bin/sh

# read ./grub-test.conf, find all the title lines in it.

INPUTFILE=./grub-test.conf
FOUND_FIRST_TITLE=0
LINENUM=1

while read F1 F2
do
   if [ "X$F1" = "X" ]
   then
      # empty line

      echo "Line $LINENUM: empty"     
   else
      if [ "$F1" = "title" ]
      then
         echo "Title line $LINENUM: \"$F1 $F2\""
      else
         echo "Other line $LINENUM: \"$F1 $F2\""
      fi
   fi

   LINENUM=`expr $LINENUM + 1`
done < $INPUTFILE

