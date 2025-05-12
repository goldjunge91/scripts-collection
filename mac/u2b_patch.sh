#!/bin/bash
function u2b_patch() {
xxd -p -c 0 "$1/Contents/MacOS/App Cleaner 8" - | \
  sed "s/42000f0b662e0f1f840000000000554889e5415550/42000f0b662e0f1f840000000000c34889e5415550/; \
  s/4889d84c89f24883c4205b415e5dc30f1f440000554889e54883ec20/4889d84c89f24883c4205b415e5dc30f1f44000048c7c001000000c3/; \
  s/e00313aae10314aafd7b43a9f44f42a9ff030191c0035fd6ffc300d1fd7b02a9/e00313aae10314aafd7b43a9f44f42a9ff030191c0035fd6200080d2c0035fd6/; \
  s/0a14200020d4f44fbea9/0a14200020d4c0035fd6/; " | \
xxd -r -p -c 0 - "$1/Contents/MacOS/App Cleaner 8"
xattr -c "$1"
codesign -fs - --deep "$1"
echo -e "\e[92mAll done, enjoy\!\e[0m"
}
u2b_patch "/Applications/App Cleaner 8.app"
