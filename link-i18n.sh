#!/bin/bash

# this is to gracefully stop execution if there's non-zero error that
# wasn't checked by an conditional statement. doesn't catch subshells
# errors though.
#set -e

usage() {
  echo "This script can link and unlink files in source directory to target directory";
  echo "that has the same structure."
  echo "The script also renames existing files and directories to filename~bak before linking.";
  echo "	Usage: $0 -s SOURCE -t TARGET | -u -t TARGET" 1>&2
}

exit_abnormal() {
  usage
  exit 1
}

exit_with_error() {
  echo "$1"
  exit 1
}

validate_dir() {
  [ -d $1 ] ||
    exit_with_error "The path: $1 doesn't exist or isn't a directory."
  [ -r $1 ] ||
    exit_with_error "The path: $1 is not readable."
  [ -w $1 ] ||
    exit_with_error "The path: $1 is not writable."
  [ -x $1 ] ||
    exit_with_error "The path: $1 is not exeutable."
  $(test $(ls -1 $1 | wc -l) -eq 0) &&
    exit_with_error "$1 is empty!"
}

get_path_part() {
  str=$1
  delimiter=$2
  s=$str$delimiter
  array=();
  while [[ $s ]]; do
    array+=( "${s%%"$delimiter"*}" );
    s=${s#*"$delimiter"};
  done;
  echo ${array[1]}
}

link() {
  local source=$(readlink -f "$1")
  local destination=$(readlink -f "$2")
  for fPath in $(find "$source" -type f,l);
  do
    pathPart=$(get_path_part $fPath $source)
    linkPath="$destination$pathPart"
    linkPathDir=$(dirname $linkPath)
    filename=$(basename $pathPart)
    [ -e $linkPath -a ! -L $linkPath ] && mv "$linkPath" "$linkPath~bak";
    [ ! -e $linkPathDir ] && mkdir -p $linkPathDir
    $(cd "$linkPathDir" && ln -sf "$linkPath" $filename)
    echo "linked $linkPath"
  done
}

unlink() {
  local destination=$(readlink -f $1)

  # TODO: unlink only the links created by this script.
  # not other links that was already there in destination
  # before running this script.
  find "$destination" -type l -exec unlink {} \;

  for fPath in $(find $destination -type f);
  do 
    echo $fPath | grep -qP "~bak$" &&
	    mv "$fPath" "$(echo ${fPath:0:${#fPath}-4})"
  done
}

while getopts :s:t:u option
do
  case "${option}"
    in
      s) source=${OPTARG}
	 ;;
      t) destination=${OPTARG}
	 ;;
      u) unLnk=1
         ;;
      :) echo "Error: -${OPTARG} requires an argument."
	 exit_abnormal
	 ;;
      *) exit_abnormal
	 ;;
  esac
done


if [ -z "$source" -a ! -z "$destination" -a ! -z "$unLnk" ]; then
  validate_dir $destination
  unlink $destination && echo "restored backup and unlinked files and directories."
fi
if [ ! -z "$source" -a ! -z "$destination" -a -z "$unLnk" ]; then
  validate_dir $source
  validate_dir $destination
  link $source $destination && echo "made backup and linked source files and directories to target"
fi
