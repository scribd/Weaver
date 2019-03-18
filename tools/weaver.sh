#! /bin/sh

INSTALL_DIR="$(cd "$(dirname "$0")"; pwd)/.."

WEAVER_MAIN_TEMPLATE_PATH="$INSTALL_DIR/share/weaver/Resources/dependency_resolver.stencil" WEAVER_DETAILED_RESOLVERS_TEMPLATE_PATH="$INSTALL_DIR/share/weaver/Resources/detailed_resolvers.stencil" WEAVER_PROJECT_PATH=`pwd` $INSTALL_DIR/bin/weaver_command $@
