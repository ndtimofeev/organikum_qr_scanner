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

# :application_menu is the same cross-project sidebar core itself uses for
# "Issues" / "Time tracking" / "Gantt" / "Calendar" - global functionality
# that isn't scoped to any one project, exactly what these two pages are.
# :project_menu was rejected: it only ever renders inside a specific
# project (:param => :project_id in core's own usage), and scanning
# doesn't know which project it'll land in ahead of time. :admin_menu was
# rejected too: these pages are for whoever does inventory work, not
# whoever administers the instance - the plugin's own Settings link
# already lives there automatically, which is the right place for that.
#
# Only one entry, on purpose - two read as clutter for something used
# this often. It goes to Inspector (the safer of the two: it never
# writes on its own) rather than the decrement scanner; the decrement
# scanner is one small link away from there instead (see
# inspect.html.erb), and Inspector links back the same way, so neither
# page is more than a tap from the other without a second menu entry.
# :view_issues rather than :add_issue_notes, matching Inspector's own
# (broader) requirement - :global => true checks it across any project
# the user belongs to, matching core's own usage for these same menu
# entries.
Redmine::MenuManager.map :application_menu do |menu|
  menu.push :organikum_qr_scanner,
            { controller: 'qr_scanner', action: 'inspect' },
            caption: :label_qr_scanner_menu,
            if: Proc.new { User.current.allowed_to?(:view_issues, nil, global: true) }
end
