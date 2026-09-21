require 'redmine'

# No to_prepare block, no monkey-patching of core classes: this plugin adds
# exactly one route/controller/view of its own and touches nothing else in
# Redmine. Its only contract with the rest of the world is "a decoded QR
# code is a URL to open" - it has no knowledge of issues, custom fields,
# or the redmine-custom-decrement-field plugin, on purpose (see README).
Redmine::Plugin.register :redmine_qr_scanner do
  name 'QR Scanner'
  author 'Your Company'
  description 'Scans a QR code with the device camera, directly in the browser, ' \
              'and opens the URL it encodes. Knows nothing about issues, custom ' \
              'fields, or any other plugin - a decoded QR code is just a URL.'
  version '0.1.0'
  url 'https://github.com/ndtimofeev/organikum_qr_scanner'
  requires_redmine version_or_higher: '6.0.0'
end
