#!/bin/bash

TRASH="$HOME/.Trash"
COMMAND=rm

GUID=0
TIME=
date_time(){
    TIME=$(date +%Y-%m-%d-%H-%M-%S)-$GUID
    (( GUID += 1 ))
}


# flags
debug=

# tools
debug(){
    if [ -n "$debug" ]; then
        echo "$@" >&2
    fi
}


# parse argv -----------------------------

invalid_option(){
    # if there's an invalid option, `rm` only takes the second char of the option string
    # case:
    # rm -c
    # -> rm: illegal option -- c
    echo "rm: illegal option -- ${1:1:1}"
    usage
}

usage(){
    echo "usage: rm [-f | -i] [-dPRrvW] file ..."
    echo "       unlink file"

    # if has an invalid option, exit with 64
    exit 64
}


if [[ "$#" = 0 ]]; then
    echo "safe-rm"
    usage
fi


ARG_END=
FILE_NAME=
ARG=

file_i=0
arg_i=0

split_push_arg(){
    # remove leading '-' and split combined short options
    # -vif -> vif -> v, i, f
    split=`echo ${1:1} | fold -w1`

    local arg
    for arg in ${split[@]}
    do
        ARG[arg_i]="-$arg"
        ((arg_i += 1))
    done
}

push_arg(){
    ARG[arg_i]=$1
    ((arg_i += 1))
}

push_file(){
    FILE_NAME[file_i]=$1
    ((file_i += 1))
}

# pre-parse argument vector
while [ -n "$1" ]
do
    # case:
    # rm -v abc -r --force
    # -> -r will be ignored
    # -> args: ['-v'], files: ['abc', '-r', 'force']
    if [[ -n "$ARG_END" ]]; then
        push_file $1

    else
        case $1 in

            # case:
            # rm -v -f -i a b

            # case:
            # rm -vf -ir a b

            # ATTENSION: 
            # Regex in bash is not perl regex,
            # in which `'*'` means at least one and has no `'+'`
            -[a-zA-Z]*)
                split_push_arg $1; debug "short option $1"
                ;;

            # rm --force a
            --[a-zA-Z]*)
                push_arg $1; debug "option $1"
                ;;

            # rm -- -a
            --)
                ARG_END=1; debug "divider"
                ;;

            # case:
            # rm -
            # -> args: [], files: ['-']
            *)
                push_file $1; debug "file $1"
                ARG_END=1
                ;;
        esac
    fi

    shift
done

# flags
OPT_FORCE=
OPT_INTERACTIVE=
OPT_RECURSIVE=
OPT_VERBOSE=

# global exit code, default to 0
EXIT_CODE=0

# parse options
for arg in ${ARG[@]}
do
    case $arg in

        # There's no --help|-h option for rm on Mac OS 
        # [hH]|--[hH]elp)
        # help
        # shift
        # ;;

        -f|--force)
            OPT_FORCE=1;        debug "force        : $arg"
            ;;

        -i|--interactive)
            OPT_INTERACTIVE=1;  debug "interactive  : $arg"
            ;;

        # both r and R is allowed
        -[rR]|--[rR]ecursive)
            OPT_RECURSIVE=1;    debug "recursive    : $arg"
            ;;

        # only lowercase v is allowed
        -v|--verbose)
            OPT_VERBOSE=1;      debug "verbose      : $arg"
            ;;

        *)
            invalid_option $arg
            ;;
    esac
done
# /parse argv -----------------------------


# make sure recycled bin exists
if [[ ! -e "$TRASH" ]]; then
    echo "Directory \"$TRASH\" does not exist, do you want create it?"
    echo -n "(yes/no): "
    
    read answer
    if [[ "$answer" = "yes" || ! -n $anwser ]]; then
        mkdir -p "$TRASH"
    else
        echo "Canceled!"
        exit 1
    fi
fi

# try to remove a file or directory
remove(){
    local file=$1

    if [[ ! -e "$file" ]]; then
        echo "$COMMAND: $file: No such file or directory"
        exit 1
    fi

    if [[ -d "$file" ]]; then

        # if a directory, and without '-r' option
        if [[ ! -n "$OPT_RECURSIVE" ]]; then
            echo "$COMMAND: $file: is a directory"
            exit 1
        fi

        if [[ "$OPT_INTERACTIVE" = 1 ]]; then
            echo -n "examine files in directory $file? "
            read answer

            # actually, as long as the answer start with 'y', the file will be removed
            # default to no remove
            if [[ ${answer:0:1} =~ [yY] ]]; then

                # if choose to examine the dir, recursively check files first
                recursive_remove $file

                # interact with the dir at last
                echo -n "remove $file? "
                read answer
                if [[ ${answer:0:1} =~ [yY] ]]; then
                    [[ $(ls -A $file) ]] && {
                        echo "$COMMAND: $file: Directory not empty"

                        # set global exit code
                        EXIT_CODE=1

                    } || trash $file
                fi
            fi
        else
            trash $file
        fi

    else
        if [[ "$OPT_INTERACTIVE" = 1 ]]; then
            echo -n "remove $file? "
            read answer
            if [[ ${answer:0:1} =~ [yY] ]]; then
                :
            else
                exit 0
            fi
        fi

        trash $file
    fi
}


recursive_remove(){
    local path

    for path in $1/*
    do
        remove $path
    done
}


# determine to trash
trash(){
    local file=$1
    trash_name=$TRASH/$(basename $file)

    # if already in the trash
    if [[ -e "$trash_name" ]]; then
        # renew $TIME
        date_time
        trash_name="$trash_name $TIME"
    fi

    [[ "$OPT_VERBOSE" = 1 ]] && echo $file

    mv "$file" "$trash_name"
}


for file in ${FILE_NAME[@]}
do
    # remove the ending '/'
    # abc/abc/ -> abc/abc
    remove ${file%/}
done

exit $EXIT_CODE
