Pod::Spec.new do |s|
  s.name         = "MYEntry+Sync"
  s.version      = "1.0"
  s.summary      = "Remote and Local Sync extend of MYEntry."
  s.homepage     = "https://github.com/Whirlwind/MYEntry-Sync"
  s.license      = 'MIT'
  s.author       = { "Whirlwind" => "Whirlwindjames@foxmail.com" }
  s.source       = { :git => "https://github.com/Whirlwind/MYEntry-Sync.git", :tag=>'v1.0'}
  s.platform     = :ios, '5.0'
  s.source_files = 'MYEntry+Sync/MYEntry+Sync/Shared/**/*.{h,m}'
  s.resources = "MYEntry+Sync/MYEntry+Sync/Shared/*.{broadcast,route}"
  s.frameworks = 'UIKit', 'Foundation'
  s.prefix_header_contents = %(
// =========== MYEntry+Sqlite ==========
#ifdef __OBJC__
#   import "MYFramework.h"
#   import "MYEntry.h"
#endif)
  s.requires_arc = true

  s.dependency 'MYEntry+JSON'
  s.dependency 'MYEntry+Sqlite'
end
