#!/usr/bin/env zsh
setopt EXTENDED_GLOB
setopt PIPE_FAIL

local -a files=((Recoreon|FragmentedScreenRecordWriter)*/**/*.(swift|m|h|plist|json)(.N))
files+=(*.(xcodeproj|xcworkspace)/**/*(.N))
files=(${files:#**/xcuserdata/**})
files+=((.github|ci_scripts)/**/*(.N))
files+=(*(.N))

exit_status=0

for file in ${(o)files}
do
  if [[ -z $(tail -c1 $file) ]]
  then
    printf 'OK: %s\n' "$file"
  else
    printf 'ERROR: %s\n' "$file"
    exit_status=1
  fi
done

exit $exit_status
