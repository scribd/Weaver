Pod::Spec.new do |s|
  s.name = "WeaverDI"
  s.version = "0.9.8"
  s.swift_version = "4.1"
  s.summary = "Declarative, easy-to-use and safe Dependency Injection framework for Swift (iOS/macOS/Linux)"
  s.homepage = "https://github.com/scribd/Weaver"
  s.license = { :type => "MIT", :file => "LICENSE" }
  s.authors = { "Theophane Rupin" => "theo@scribd.com" }
  s.source = { :git => "https://github.com/scribd/Weaver.git", :tag => "#{s.version}" }

  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.10"

  s.source_files = "Sources/WeaverDI/**/*.swift"
end
