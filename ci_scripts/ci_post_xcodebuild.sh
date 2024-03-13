#!/bin/sh

python3 -m venv .venv

# shellcheck source=/dev/null
. .venv/bin/activate

pip3 install codecov-cli
