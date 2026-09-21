require 'redmine'

# No to_prepare block, no monkey-patching of core classes: this plugin adds
# exactly one route/controller/view of its own and touches nothing else in
# Redmine. It does read one specific custom field chosen in Settings, and
# recognizes Issue URLs among decoded QR codes, but never requires or
# references redmine-custom-decrement-field's own Ruby code - see
# QrScannerController#decrement_target_field and README for how the two
# stay decoupled despite that.
Redmine::Plugin.register :organikum_qr_scanner do
  name 'QR Scanner'
  author 'Your Company'
  description 'Scans a QR code with the device camera, directly in the browser, ' \
              'expecting it to encode one of this Redmine\'s own issue URLs. ' \
              'Decrements the decrementable custom field chosen in Settings on ' \
              'that issue (permission and field-availability allowing) and ' \
              'opens it.'
  version '0.2.0'
  url 'https://github.com/ndtimofeev/organikum_qr_scanner'
  requires_redmine version_or_higher: '6.0.0'

  settings default: { 'custom_field_id' => nil },
           partial: 'settings/organikum_qr_scanner_settings'
end
