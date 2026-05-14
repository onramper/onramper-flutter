Pod::Spec.new do |s|
  s.name             = 'onramper_sdk'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin wrapping OnramperSDK (iOS).'
  s.description      = 'iOS-only Flutter plugin for the Onramper crypto on-ramp.'
  s.homepage         = 'https://github.com/onramper/onramper-flutter'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Onramper' => 'engineering@onramper.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'

  s.source_files     = 'Classes/**/*.{swift,h,m}'
  s.dependency 'Flutter'

  s.vendored_frameworks = 'Frameworks/OnramperSDK.xcframework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE'                       => 'YES',
    'ENABLE_BITCODE'                       => 'NO',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
