Pod::Spec.new do |s|
  s.name         = "BeaverDI"
  s.version      = "0.1.0"
  s.summary      = "A typesafe dependency injection framework working at compile time."
  s.homepage     = "https://github.com/Beaver/BeaverDI"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.authors      = { "Theophane Rupin" => "theo@scribd.com" }
  s.source       = { :git => "https://github.com/Beaver/BeaverDI.git", :tag => "#{s.version}" }

  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.10"

  s.source_files = "BeaverDI/**/*.swift"
end