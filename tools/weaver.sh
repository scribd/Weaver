#! /bin/sh

INSTALL_DIR="$(cd "$(dirname "$0")"; pwd)/.."

WEAVER_PROJECT_PATH=`pwd` $INSTALL_DIR/bin/weaver_command $@
