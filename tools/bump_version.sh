current_version=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Weaver.xcodeproj/WeaverCodeGen_Info.plist`

next_version=$1
if [ -z $next_version ]; then
	next_version=${current_version%.*}.$((${current_version##*.}+1))
fi

echo $next_version

sed -i '' "s/${current_version//./\\.}/$next_version/g" \
Weaver.xcodeproj/Weaver_Info.plist \
Weaver.xcodeproj/WeaverCodeGen_Info.plist \
Weaver.podspec \
Resources/dependency_resolver.stencil \
Tests/WeaverCodeGenTests/GeneratorTests.swift

previous_version=${current_version%.*}.$((${current_version##*.}-1))
sed -i '' "s/${previous_version//./\\.}/$current_version/g" README.md

git commit -am "Bump version to $next_version"