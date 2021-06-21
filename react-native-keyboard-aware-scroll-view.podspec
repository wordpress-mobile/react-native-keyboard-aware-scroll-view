require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name            = package['name']
  s.version         = package['version']
  s.homepage        = package['homepage']
  s.summary         = package['description']
  s.license         = package['license']
  s.authors         = package['author']
  s.platform        = :ios, "8.0"
  s.source          = { :git => "https://github.com/wordpress-mobile/react-native-keyboard-aware-scroll-view.git", :tag => "v#{s.version}" }
  s.source_files    = "ios/RNTKeyboardAwareScrollView/*.{h,m}"
  s.preserve_paths  = "**/*.js"

  s.dependency 'React'
end
