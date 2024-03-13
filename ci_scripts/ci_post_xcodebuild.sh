#!/bin/zsh


echo 1:$CI_DERIVED_DATA_PATH
echo 2:$CI_TEST_PLAN
echo 3:$CI_AD_HOC_SIGNED_APP_PATH
echo 4:$CI_APP_STORE_SIGNED_APP_PATH
echo 5:$CI_ARCHIVE_PATH
echo 6:$CI_DEVELOPMENT_SIGNED_APP_PATH
echo 7:$CI_DEVELOPER_ID_SIGNED_APP_PATH

if [[ -d $CI_APP_STORE_SIGNED_APP_PATH ]];
then
  python3 -m venv .venv

  # shellcheck source=/dev/null
  . .venv/bin/activate

  pip3 install codecov-cli

  for profdata in ~/Library/Developer/Xcode/DerivedData/**/*.profdata
  do
    echo $CI_DERIVED_DATA_PATH
    echo $CI_APP_STORE_SIGNED_APP_PATH
    echo $CI_TEST_PLAN
    cd $CI_APP_STORE_SIGNED_APP_PATH
    pwd
    ls
    # xcrun llvm-cov export \
    #   -format=lcov \
    #   -instr-profile "$profdata" \
    #   -ignore-filename-regex=".*/Recoreon/UI/.*" \
    #   "$CI_APP_STORE_SIGNED_APP_PATH/Recoreon" \
    #   >RecoreonTests.coverage.txt
    # xcrun llvm-cov show \
    #   -instr-profile "/Users/umireon/Library/Developer/Xcode/DerivedData/Recoreon-crbylpwbinigacciqvtroddmcpnj/Build/ProfileData/764BF637-1698-4CA2-A5CC-7B1C89DFC342/Coverage.profdata" \
    #   -ignore-filename-regex=".*/Recoreon/UI/.*" \
    #   "/Users/umireon/Library/Developer/Xcode/DerivedData/Recoreon-crbylpwbinigacciqvtroddmcpnj/Build/Products/Debug-iphonesimulator/Recoreon.app/Recoreon" \
    #   >RecoreonTests.coverage.txt
    # codecov -f $profdata.txt
  done
fi