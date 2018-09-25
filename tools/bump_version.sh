current_version=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Weaver.xcodeproj/WeaverCodeGen_Info.plist`

next_version=$1
if [ -z $next_version ]; then
	next_version=${current_version%.*}.$((${current_version##*.}+1))
fi

echo $next_version

sed -i '' "s/${current_version//./\\.}/$next_version/g" \
Weaver.xcodeproj/WeaverCodeGen_Info.plist \
Resources/dependency_resolver.stencil \
Tests/WeaverCodeGenTests/Generator/Output/*.swift \
Sources/WeaverCommand/main.swift

release_tar="https://github.com/scribd/Weaver/archive/$current_version.tar.gz"
sha=$(curl -L -s $release_tar | shasum -a 256 | sed 's/ .*//')
sed -i '' "s|\(sha256 \"\)\(.*\)\(\"\)|\1$sha\3|" $(brew --repo homebrew/core)/Formula/weaver.rb

previous_version=${current_version%.*}.$((${current_version##*.}-1))
sed -i '' "s/${previous_version//./\\.}/$current_version/g" \
README.md \
$(brew --repo homebrew/core)/Formula/weaver.rb

git commit -am "Bump version to $next_version"