#!/bin/zsh

if [[ -d $CI_RESULT_BUNDLE_PATH ]];
then
  python3 -m venv .venv

  # shellcheck source=/dev/null
  . .venv/bin/activate

  pip3 install codecov-cli

  dest=($CI_DERIVED_DATA_PATH/**/Recoreon.app/Recoreon)
  profdata=($CI_DERIVED_DATA_PATH/**/*.profdata)

  case $CI_TEST_PLAN in
    RecoreonTests)
      xcrun llvm-cov show \
        -instr-profile "${profdata[1]}" \
        -ignore-filename-regex=".*/Recoreon/UI/.*" \
        "${dest[1]}" \
        >RecoreonTests.coverage.txt

      codecovcli upload-process --plugin "" --file RecoreonTests.coverage.txt
      ;;
    
    RecoreonUITests)
      xcrun llvm-cov show \
        -instr-profile "${profdata[1]}" \
        -ignore-filename-regex=".*/Recoreon/(Models|Services|Stores)/.*" \
        "${dest[1]}" \
        >RecoreonUITests.coverage.txt

      codecovcli upload-process --plugin "" --file RecoreonUITests.coverage.txt
  esac

fi
