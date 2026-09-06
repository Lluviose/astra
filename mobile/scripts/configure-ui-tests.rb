require 'xcodeproj'

project = Xcodeproj::Project.open('ios/Astra.xcodeproj')
app = project.targets.find { |target| target.name == 'Astra' }
raise 'Generated Astra target missing' unless app

tests = project.new_target(:ui_test_bundle, 'AstraUITests', :ios, '18.0')
tests.add_dependency(app)
group = project.main_group.new_group('AstraUITests', '../native-tests')
tests.source_build_phase.add_file_reference(group.new_file('ModernUITests.swift'))
tests.build_configurations.each do |configuration|
  configuration.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.lluviose.astra.modern.uitests',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'SWIFT_VERSION' => '5.0',
    'TEST_TARGET_NAME' => 'Astra',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'CODE_SIGNING_ALLOWED' => 'NO'
  })
end
project.root_object.attributes['TargetAttributes'] ||= {}
project.root_object.attributes['TargetAttributes'][tests.uuid] = { 'TestTargetID' => app.uuid }
project.save

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(app, tests, launch_target: true)
scheme.test_action.build_configuration = 'Release'
scheme.save_as('ios/Astra.xcodeproj', 'Astra-UIReview', true)
