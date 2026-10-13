#!/bin/sh
# Alire has no configuration for Swift, so gprbuild runs this as the
# compiler of "C" files, with the switches of one: it passes them on to
# swiftc, but those that swiftc does not know (-x, -specs=, and the dependency
# ones), and names the object after the source, as a C compiler does.
keep=""
file=""
skip=0
for arg in "$@"; do
   if [ "$skip" = 1 ]; then
      skip=0
      continue
   fi
   case "$arg" in
      -x | -MF) skip=1 ;;
      -MMD | -specs=*) ;;
      *.swift) file="$arg" ;;
      *) keep="$keep $arg" ;;
   esac
done
name=$(basename "$file" .swift)
# shellcheck disable=SC2086
exec /usr/bin/swiftc $keep -emit-dependencies "$file" -o "$name.o"
