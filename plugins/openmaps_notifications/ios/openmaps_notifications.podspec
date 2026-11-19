#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint openmaps_notifications.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'openmaps_notifications'
  s.version          = '0.1.0'
  s.summary          = "OpenMaps' local-notification channel, usable from background isolates."
  s.description      = <<-DESC
OpenMaps' own local-notification channel, registered on the main and the FCM
background Flutter engine.
                       DESC
  s.homepage         = 'https://github.com/camelus-hq/maps'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'OpenMaps' => 'noreply@camelus.app' }
  s.source           = { :path => '.' }
  s.source_files = 'openmaps_notifications/Sources/openmaps_notifications/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'openmaps_notifications_privacy' => ['openmaps_notifications/Sources/openmaps_notifications/PrivacyInfo.xcprivacy']}
end
