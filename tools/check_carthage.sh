TEST_DIR="/tmp/weaver_carthage_check"
BRANCH=`git rev-parse HEAD`

rm -rf $TEST_DIR
mkdir -p $TEST_DIR
cd $TEST_DIR

echo "github \"scribd/Weaver\" \"$BRANCH\"" >> Cartfile
echo "" >> Cartfile

carthage bootstrap

rm -rf $TEST_DIR