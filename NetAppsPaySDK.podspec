Pod::Spec.new do |s|
  s.name         = "NetAppsPaySDK"
  s.version      = "1.1.1"
  s.summary      = "NetAppsPay iOS Payment SDK"
  s.description  = "Accept payments via Card, Bank Transfer, USSD, PayAttitude, and MoniFlow in your iOS app."
  s.homepage     = "https://github.com/talktothelaw/netapps-pay-ios"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = "NetAppsPay"

  s.platform     = :ios, "15.0"
  s.swift_version = "5.9"
  s.source       = { :git => "https://github.com/talktothelaw/netapps-pay-ios.git", :tag => s.version.to_s }

  s.source_files = "Sources/NetAppsPaySDK/**/*.swift"
  s.resources    = "Sources/NetAppsPaySDK/Resources/**/*"
  s.frameworks   = "UIKit", "Foundation"
end
