Pod::Spec.new do |s|
  s.name = "Weaver"
  s.version = "0.9.5"
  s.swift_version = "4.0"
  s.summary = "A typesafe dependency injection framework working at compile time."
  s.homepage = "https://github.com/scribd/Weaver"
  s.license = { :type => "MIT", :file => "LICENSE" }
  s.authors = { "Theophane Rupin" => "theo@scribd.com" }
  s.source = { :git => "https://github.com/scribd/Weaver.git", :tag => "#{s.version}" }

  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.10"

  s.source_files = "Sources/Weaver/**/*.swift"
end
