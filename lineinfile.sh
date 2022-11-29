#!/bin/bash

# Author: Matthias Ries
# License: GNU Lesser General Public License v2.1
# Github: https://github.com/matthiasries/lineinfile-sh

MODE="REPLACE"
BACKUP=0
FILENAME=""
CREATE="false"
STATE="present"
REGEXP=""
PATTERN=""
TRACE=0
INSERTHOOK="$"
INSERTAFTER=0
INSERTBEFORE=0
LINE=""
VERBOSE=1
DRYRUN=0
DRYRUNFILE=""
DEBUG=0
RUN=0
NECESARY1=0
NECESARY2=0
NECESARY3=0
FIRSTMATCH=0
GREPCMD=grep
GREPARG=" -n  -C2 -E "
SEDCMD=sed
SEDARG="-r"
SEDLIVE="-i"
AWKCMD=awk
TOUCHCMD=touch
DATECMD=date
CPCMD=cp
PS4="\$( $DATECMD '+%Y-%m-%d %H-%M-%S')   "

# wenn busybox dann keine Farben
if [ ! -L /bin/grep ];
then
    [[ -t 1 ]] && GREPARG+="--color=always -a -T "
    [[ ! -t 1 ]] && GREPARG+="--color=never -a -T "
fi

export GREP_COLOR="01;32"
set -o errexit
set -o pipefail
set -o noglob

function error(){
        debug "$*"
        echo -e "$*" >&2
        exit 1
}


function debug(){
    if [[ $DEBUG -eq 1 ]];
    then
        echo -e "$( $DATECMD "+%Y-%m-%d %H-%M-%S") $BASH_LINENO $*" >&2
    fi
    return 0 
}

function usage(){
/bin/cat <<'EOF'
       Disclaimer 
           Don't use this in production! Don't use this with unvalidated input! This is not secure code. This is shell scripting! 
           
       Necesary parameters
        --regexp="pattern"                                            # a regex matching a pattern in the line we are looking for
        --line="TEXT"                                                 # the text the line is replaced with
        --path="./filename.txt" || ./filename || /var/www/index.html  # the file lineinfile is supposed to edit. Without "--path" everything that is not a parameter is assumed to be a file.

       dependend
        --line="TEXT"             # the text the line is replaced with, except when state=absent
        --state="absent|present"  # should the line matching regexp be removed, should the line be present

       Optionl parameters
        --insertafter="EOF"       # EOF|BOF|regex - Insert After regex pattern, after EndOfFile (EOF) or after BeginOfFile (BOF)
        --insertbefore="EOF"      # EOF|BOF|regex - Insert Before regex pattern, before EndOfFile (EOF) or  before BeginOfFile (BOF)
        --create                  # if the file does not exist, should it be created
        --backup                  # make a backup first
        --quiet                   # no output only return codes
        --debug                   # very noisy output
        --trace                   # even then debug more noisy

       return codes  0 for success 1 for failure

       example1:
        lineinfile --regexp="^LAST=.*" --state=absent  /etc/defaults/automysqlbackup
        lineinfile --backup --regexp="PasswordAuthentication" --line="LAST=TRUE" --path=/etc/defaults/automysqlbackup
        lineinfile --dryrun --firstmatch --regexp="PasswordAuthentication" --line="PasswordAuthentication without-password" --insertbefore=EOF  --state=present  /etc/ssh/sshd_config

       lineinfile                         \
          regexp="^LAST.*"                \
          line="LAST=TRUE"                \
          path=/etc/defaults/automysqlbackup
EOF
}

function backupFile(){
        if [[ -e "$FILENAME" && "$BACKUP" -eq 1 ]];
        then
                 debug "backup file: $CPCMD $FILENAME $FILENAME.$($DATECMD -Is)"
         echo "Backup file -$FILENAME- to -$FILENAME.$($DATECMD -Is)-"
                 $CPCMD "$FILENAME" "$FILENAME.$($DATECMD -Is)"
        else
                 debug "no backup"
        fi

}

function replaceLine(){
    debug "replace line "
        [[ $DEBUG -eq 1 ]] && set -x
        [[ "$FIRSTMATCH" -eq 0  ]] && $SEDCMD $SEDARG $SEDLIVE   "/$REGEXP/{s#.*$PATTERN.*#${LINE//\#/\\\#}#}" "${FILENAME}"
        [[ "$FIRSTMATCH" -eq 1  ]] && $SEDCMD $SEDARG $SEDLIVE "0,/$REGEXP/{s#.*$PATTERN.*#${LINE//\#/\\\#}#}" "${FILENAME}"
        set +x

}
function insertLineAfter(){
    local TYPE=$1
        debug "insert after $TYPE at $INSERTHOOK "
        [[ $DEBUG -eq 1 ]] && set -x
        [[ "$TYPE" == "POINT" ]]  && $SEDCMD  $SEDLIVE $SEDARG -z   "s#${INSERTHOOK}#${LINE//\#/\\\#}\n#"       "$FILENAME"
    [[ "$TYPE" == "MATCH" ]]  && $SEDCMD  $SEDLIVE $SEDARG      "s#^(.*${INSERTHOOK}.*)#\1\n${LINE//\#/\\\#}#" "${FILENAME}"
    set +x
}

function insertLineBefore(){
        local TYPE=$1
        debug "insert before $TYPE at $INSERTHOOK "
        [[ $DEBUG -eq 1 ]] && set -x
        [[ "$TYPE" == "POINT" ]]  && $SEDCMD  $SEDLIVE $SEDARG -z   "s#${INSERTHOOK}#${LINE//\#/\\\#}\n#"          "$FILENAME"
        [[ "$TYPE" == "MATCH" ]]  && $SEDCMD  $SEDLIVE $SEDARG      "s#^(.*${INSERTHOOK}.*)#${LINE//\#/\\\#}\n\1#" "${FILENAME}"
        set +x
}


function removeLine(){
    debug "remove line $PATTERN"
        [[ $DEBUG -eq 1 ]] && set -x
        [[ $FIRSTMATCH -eq 0  ]] && $SEDCMD $SEDARG $SEDLIVE   "/$REGEXP/{//d;}" "${FILENAME}"
    [[ $FIRSTMATCH -eq 1  ]] && $SEDCMD $SEDARG $SEDLIVE "0,/$REGEXP/{//d;}" "${FILENAME}"
        set +x
}

function displayChange(){
        COMMENT="$1"
        MATCH="$2"
                if [[ $VERBOSE -eq 1 ]];
                then
                    echo "Filename: '$FILENAME'"
                    echo "$COMMENT"
                    [[ $TRACE -eq 1 ]] && set -x
                    $GREPCMD $GREPARG  "${MATCH}" "${FILENAME}" # from before change
                    set +x
                fi
}

function matchPattern(){
    MATCH=$1
    $GREPCMD -q -E "${MATCH}" "${FILENAME}"
}

function doesFileExist(){
  debug "create or not?"
  if [[ ! -e "$FILENAME" && "$CREATE" == "true" ]];
  then
         debug "create file '$FILENAME'"
         $TOUCHCMD "$FILENAME" || error "Can't create file "
  else
          debug "don't create file"
  fi

  debug "does the file exist"

  if [[ ! -e "$FILENAME" ]];
  then
     error "File -$FILENAME- does not exist"
  else
       if [[ ! -w "$FILENAME" ]];
       then
        debug "File is not writeable"
        if [[ $DRYRUN -ne 1 ]];
        then
            error "File -$FILENAME- is not writeable"
        else
            echo -e "\nDRYRUN! File -$FILENAME- is not written\n"
        fi
           else
              debug "file exists and is writeable"
       fi
  fi

  if [[ $DRYRUN -eq 1 ]];
  then
    # TODO Better dryrun version
    DRYRUNFILE=/tmp/.lineinfiledryrun
    $CPCMD "$FILENAME" $DRYRUNFILE
    FILENAME=$DRYRUNFILE
  fi
}

function lineinfile(){
    doesFileExist
    debug "Does regex match the file?"
    if matchPattern "$REGEXP"
    then
        debug "The regex matches the file"
        debug "should the match be removed?"
        if [[  "$STATE" != "absent" ]];
        then
            debug "no"
            if matchPattern "^${LINE//./\.}$"
            then
                debug "everything is as expected"
                export GREP_COLOR="0;32"
                displayChange "Line found" "$REGEXP"
                exit 0
            else
                debug "replace matching line with LINE"
                backupFile
                export GREP_COLOR="1;31"
                displayChange "before" "$REGEXP"
                replaceLine
                export GREP_COLOR="0;93"
                displayChange "after" "^$LINE$"
                exit 0
            fi
        elif [[ "$STATE" == "absent" ]];
        then
            debug "yes the match should be removed"
            export GREP_COLOR="1;31"
            displayChange "Remove the Line" "$REGEXP"
            removeLine
            exit 0
        else
            error  "Error unknown state"
        fi
    else
        debug "The regex does not match in the file"
        debug "should the pattern exist?"
        if [[ $INSERTAFTER -eq 1 || $INSERTBEFORE -eq 1 ]];
        then
            [[ "$LINE" == "" ]] && error "No 'line' parameter given"
            MATCHTYPE="MATCH"
            [[ "$INSERTHOOK" == "BOF" ]] && MATCHTYPE="POINT"
            [[ "$INSERTHOOK" == "BOF" ]] && INSERTHOOK="^"
            [[ "$INSERTHOOK" == "EOF" ]] && MATCHTYPE="POINT"
            [[ "$INSERTHOOK" == "EOF" ]] && INSERTHOOK="$"
            [[ $INSERTBEFORE -eq 1  ]] && MESSAGE="before"
            [[ $INSERTAFTER  -eq 1  ]] && MESSAGE="after"
            if matchPattern "$INSERTHOOK"
            then
                debug "The regex matches the file"


                debug "MATCHTYPE=$MATCHTYPE INSERTHOOK=$INSERTHOOK MESSAGE=$MESSAGE"
                export GREP_COLOR="0;93"
                backupFile
                [[ $INSERTAFTER  -eq 1 ]] && insertLineAfter  "$MATCHTYPE"
                [[ $INSERTBEFORE -eq 1 ]] && insertLineBefore "$MATCHTYPE"
                displayChange "Insert $MESSAGE at $INSERTHOOK" "$LINE"
                exit 0
            else
                error "'insert $MESSAGE' pattern \"$INSERTHOOK\" not found"
            fi
        fi
        if [[  "$STATE" == "present" ]];
        then
            error "Line not found. Line is missing."
        elif [[  "$STATE" == "absent" ]];
        then
            echo "Nothing to do. Line does not exist"
            exit 0
        else
            error  "Error unknown state"
        fi
    fi
}

COUNT=0
while [ "$1" != "" ];
do
    PARAMETER=$( echo "$1" | $AWKCMD -F= '{ print $1 }' | $SEDCMD  's#^--##g' )
    ARGUMENT=$( echo "$1" | $SEDCMD  's#^--##g' )
    debug  "while LOOP COUNT=$COUNT INPUT='$1' - PARAMETER='$PARAMETER'"
    if [[ "$PARAMETER" ]];
    then
        case "$PARAMETER" in
            help)
                usage
                exit 0
                ;;
            dryrun)
                DRYRUN=1
                ;;
            debug)
                DEBUG=1
                debug "DEBUG=1"
                ;;
            trace)
                TRACE=1
                debug "TRACE=1"
                ;;
            regexp)
                REGEXP="${ARGUMENT:7}"
                REGEXP="${REGEXP//\//\\/}"
                REGEXP="${REGEXP//\#/\#}"
                PATTERN="$( echo "$REGEXP" | $SEDCMD -r 's#(\^|\$)##g' )"
                debug "PATTERN=$PATTERN"
                debug "REGEXP=$REGEXP"
                NECESARY1=1
                ;;
            line)
                LINE="${ARGUMENT:5}"
                LINE=${LINE//\//\\/}
                debug "LINE=${LINE}"
                NECESARY2=10
                ;;
            path)
                FILENAME=${ARGUMENT:5}
                debug "FILENAME=$FILENAME"
                NECESARY3=100
                ;;
            create)
                CREATE=true
                debug "CREATE=true"
                ;;
            insertafter)
                [[ $INSERTBEFORE -eq 1 ]] && error "Contradicting arguments"
                INSERTAFTER=1
                INSERTHOOK="${ARGUMENT:12}"
                INSERTHOOK="${INSERTHOOK//\//\\/}"
                INSERTHOOK="${INSERTHOOK//\\/\\\\}"
                debug "INSERTHOOK=$INSERTHOOK"
                ;;
            insertbefore)
                [[ $INSERTAFTER -eq 1 ]] && error "Contradicting arguments"
                INSERTBEFORE=1
                INSERTHOOK="${ARGUMENT:13}"
                INSERTHOOK="${INSERTHOOK//\//\\/}"
                INSERTHOOK="${INSERTHOOK//\\/\\\\}"
                debug "INSERTHOOK=$INSERTHOOK"
                ;;
            state)
                STATE="${ARGUMENT:6}"
                NECESARY2=10
                debug "STATE=$STATE"
                ;;
            backup)
                BACKUP=1
                debug "BACKUP=$BACKUP"
                ;;
            quiet)
                VERBOSE=0
                debug "QUIETE=VERBOSE=$VERBOSE"
                ;;
            firstmatch)
                FIRSTMATCH=1
                GREPARG+=" -m 1  "
                debug "FIRSTMATCH=$FIRSTMATCH GREPARG=$GREPARG"
                ;;
            *)
                if [[ -e "$1" ]];
                then
                    debug "interpret this argument as the --path=$1 "
                    FILENAME=${1}
                    NECESARY3=100
                else
                    echo "Unknown argument \"$PARAMETER\""
                    usage
                    exit 1
                fi
                ;;
        esac
    else
        debug "no param left"
        usage $*
        exit 0
    fi
    COUNT=$(($COUNT + 1 ))
    shift
done

RUN=$((RUN+NECESARY1+NECESARY2+NECESARY3))

if [[ $RUN -eq 111 ]];
then
    debug "lineinfile executed RUN=$RUN"
    lineinfile
else
    debug "lineinfile not executed RUN=$RUN"
fi

[[ $RUN -gt 0 && $RUN -lt 111  ]] && error "Not enough parameter"


