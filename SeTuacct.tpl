#!/bin/sh
#TMP=/var/log/setup/tmp
TMP=/tmp
if [ ! -d $TMP ]; then
  mkdir -p $TMP
fi

    UFULLNAME=""
    UACCOUNT=""
    USHELL="/bin/bash"
    UFORM="Fill out your user details:"
    while [ 0 ]; do
      dialog --stdout --ok-label "Submit" --no-cancel \
        --title "@UDISTRO@ (@LIVEDE@) USER CREATION" \
        --form "$UFORM" \
        10 64 0 \
          "Full Name:"   1 1 "$UFULLNAME" 1 14 40 0 \
          "Logonname:"   2 1 "$UACCOUNT"  2 14 32 0 \
          "Login Shell:" 3 1 "$USHELL"    3 14 12 0 \
        2>&1 1> $TMP/tempresult
      iii=0
      declare -a USERATTR
      while read LINE ; do
        USERATTR[$iii]="$LINE"
        iii=$(expr $iii + 1)
      done < $TMP/tempresult
      rm -f $TMP/tempresult
      UFULLNAME="${USERATTR[0]}"
      UACCOUNT="${USERATTR[1]}"
      USHELL="${USERATTR[2]}"
      unset USERATTR
      UINPUT=0
      # Validate the input:
      UACC_INVALID1="$(echo ${UACCOUNT:0:1} |tr -d 'a-z_')"
      UACC_INVALID="$(echo ${UACCOUNT:1} |tr -d 'a-z0-9_-')"
      if [ -n "$UACC_INVALID1" -o -n "$UACC_INVALID" ]; then
        # User account contains invalid characters, let's remove them all:
        UINPUT=1
        UACCOUNT="$(echo ${UACCOUNT} |tr -cd 'a-z_')"
      fi
      if [ -z "$UACCOUNT" -o -z "$UFULLNAME" ]; then
        # User account or fullname is empty, let's try again:
        UINPUT=$(expr $UINPUT + 2)
      fi
      if ! grep -q ${USHELL} ${T_PX}/etc/shells ; then
        # Login shell is invalid, suggest the bash shell again:
        UINPUT=$(expr $UINPUT + 4)
        USHELL=/bin/bash
      fi
      if [ $UINPUT -eq 0 ]; then
        break
      elif [ $UINPUT -eq 1 ]; then
        UFORM="Please only use valid characters for logonname"
      elif [ $UINPUT -eq 2 ]; then
        UFORM="Please enter your logon and full name"
      elif [ $UINPUT -eq 3 ]; then
        UFORM="Use valid characters for logonname, and enter full name"
      elif [ $UINPUT -eq 4 ]; then
        UFORM="Please enter a valid shell"
      else
        UFORM="Fill all fields, and only use valid characters for logonname"
      fi
    done

    echo "UACCOUNT=$UACCOUNT"
    echo "UFULLNAME='$UFULLNAME'"
    echo "USHELL=$USHELL"
