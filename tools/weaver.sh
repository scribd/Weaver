#! /bin/sh

INSTALL_DIR="$(cd "$(dirname "$0")"; pwd)/.."

WEAVER_TEMPLATE_PATH="$INSTALL_DIR/share/weaver/Resources/dependency_resolver.stencil" WEAVER_PROJECT_PATH=`pwd` $INSTALL_DIR/bin/weaver_command $@