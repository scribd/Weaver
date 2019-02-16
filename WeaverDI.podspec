Pod::Spec.new do |s|
  s.name           = 'WeaverDI'
  s.version        = `cat .version`
  s.summary        = 'Declarative, easy-to-use and safe Dependency Injection framework for Swift (iOS/macOS/Linux).'
  s.homepage       = 'https://github.com/scribd/Weaver'
  s.license        = { :type => 'MIT', :file => 'LICENSE' }
  s.author         = { 'Theophane Rupin' => 'theophane.rupin@gmail.com' }
  s.source         = { :http => "#{s.homepage}/releases/download/#{s.version}/weaver-#{s.version}.zip" }
  s.preserve_paths = '*'
  s.exclude_files  = '**/file.zip'
end