current_version=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" WeaverDI.xcodeproj/WeaverCodeGen_Info.plist`

next_version=$1
if [ -z $next_version ]; then
	next_version=${current_version%.*}.$((${current_version##*.}+1))
fi

echo $next_version

sed -i '' "s/${current_version//./\\.}/$next_version/g" \
WeaverDI.xcodeproj/WeaverDI_Info.plist \
WeaverDI.xcodeproj/WeaverCodeGen_Info.plist \
WeaverDI.podspec \
Resources/dependency_resolver.stencil \
Tests/WeaverCodeGenTests/GeneratorTests.swift \
Sources/WeaverCommand/main.swift

previous_version=${current_version%.*}.$((${current_version##*.}-1))
sed -i '' "s/${previous_version//./\\.}/$current_version/g" README.md

git commit -am "Bump version to $next_version"