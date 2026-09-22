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
# Each entry's :if reuses an existing core permission rather than
# introducing a plugin-specific one, the same way the plugin's own write
# path reuses add_issue_notes instead of a new permission (see
# QrScannerController and the README) - :global => true checks it across
# any project the user belongs to, matching core's own usage for these
# same menu entries.
Redmine::MenuManager.map :application_menu do |menu|
  menu.push :organikum_qr_scanner_decrement,
            { controller: 'qr_scanner', action: 'show' },
            caption: :label_qr_scanner_decrement,
            if: Proc.new { User.current.allowed_to?(:add_issue_notes, nil, global: true) }

  # :view_issues, not :add_issue_notes - inspecting a field's value is a
  # read, so this is offered more broadly than the decrement-only
  # scanner above. The "Decrement" button inside inspect.html.erb hides
  # itself per-issue when the viewer can't actually use it
  # (QrScannerController#inspect_scan's can_decrement) - that's the
  # right place for that specific check, not this menu-wide one.
  menu.push :organikum_qr_scanner_inspect,
            { controller: 'qr_scanner', action: 'inspect' },
            caption: :label_qr_scanner_inspect,
            if: Proc.new { User.current.allowed_to?(:view_issues, nil, global: true) }
end
