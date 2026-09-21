# Renders the scanner page (`show`) and handles what a successful scan
# does (`scan`). Camera access and QR decoding both happen client-side
# (see show.html.erb); this controller only ever sees the decoded text
# after the fact, as an ordinary form parameter.
class QrScannerController < ApplicationController
  before_action :require_login

  def show
  end

  # Deliberately does NOT depend on redmine-custom-decrement-field's Ruby
  # code (no `require`, no reference to CustomDecrementField:: anything) -
  # only on `format_store`, a plain column/Rails `store` that Redmine core
  # itself declares on every CustomField (app/models/custom_field.rb),
  # regardless of which formats are currently registered. Reading
  # `custom_field.format_store['decrement_token']` therefore works whether
  # or not that plugin happens to be installed on this Redmine - if it
  # isn't, no field can have field_format 'decrementable_int' in the first
  # place (see decrement_target_field), so this action simply never finds
  # a field to act on.
  #
  # Answers with JSON rather than redirecting: the page that posts here
  # (show.html.erb) stays on the scanner the whole time - showing the
  # result and pausing/resuming the camera are both its job, not this
  # action's. See that view for why staying put, rather than navigating
  # to the issue, is what's wanted here.
  def scan
    issue = issue_from_scanned_url(params[:url])
    return render_scan_result(:error, l(:error_qr_scanner_unrecognized_url)) unless issue

    field = decrement_target_field
    return render_scan_result(:error, l(:error_qr_scanner_not_configured), issue) unless field

    unless issue.available_custom_fields.include?(field)
      return render_scan_result(:error, l(:error_qr_scanner_field_missing), issue)
    end

    unless issue.notes_addable?(User.current)
      return render_scan_result(:error, l(:error_qr_scanner_no_permission), issue)
    end

    token = field.format_store['decrement_token']
    return render_scan_result(:error, l(:error_qr_scanner_not_configured), issue) if token.blank?

    # Mirrors StockCalculator#value_in_db on the other plugin: the current
    # custom_values row already holds the last derived total (kept fresh
    # on every save by that plugin's own recalculation), so checking it
    # directly is enough - there's no need to re-derive the value from
    # journal history here too.
    current_value = issue.custom_value_for(field)&.value.to_i
    return render_scan_result(:error, l(:error_qr_scanner_exhausted), issue) if current_value <= 0

    issue.init_journal(User.current, "#{token}:-1")
    issue.save!

    render_scan_result(:success, l(:notice_qr_scanner_decremented), issue)
  end

  # The html5-qrcode UMD build, vendored under assets/javascripts/ rather
  # than pulled from a CDN at runtime (keeps this working on a network with
  # no outbound internet access, e.g. an internal warehouse LAN), and
  # inlined directly into the page rather than served through Redmine's
  # plugin asset pipeline via javascript_include_tag(plugin: ...) - that
  # pipeline depends on `bin/rails assets:precompile` having actually been
  # run, which redmine-custom-decrement-field's own history shows can't be
  # relied on. Memoized at the class level: the file can't change without a
  # restart anyway.
  def self.vendored_javascript
    @vendored_javascript ||= File.read(vendored_javascript_path)
  end

  def self.vendored_javascript_path
    File.join(
      Redmine::Plugin.find(:organikum_qr_scanner).assets_directory,
      'javascripts', 'html5-qrcode.min.js'
    )
  end

  private

  # Deliberately narrow: only ever resolves a URL that points at THIS
  # Redmine's own /issues/:id (whatever the host - a reverse proxy or a
  # config change could make the printed URL's host differ from however
  # this request itself arrived), via a plain path regexp, and only ever
  # loads it through Issue.visible so a scanned code can't be used to
  # probe the existence of issues the current user isn't allowed to see.
  # Anything else - a non-issue URL, a QR that isn't even a URL, garbage -
  # comes back nil and is treated as "unrecognized", not navigated to.
  # This is stricter than an earlier version of this plugin, which handed
  # whatever text was decoded straight to window.location.href - seemed
  # fine when the only consequence was "the browser goes somewhere", but
  # now that scanning can also trigger a write, resolving to a concrete,
  # permission-checked local Issue first is the right default anyway.
  def issue_from_scanned_url(url)
    return nil if url.blank?

    path = begin
      URI.parse(url).path
    rescue URI::InvalidURIError
      nil
    end
    return nil if path.blank?

    match = path.match(%r{/issues/(\d+)\z})
    return nil unless match

    Issue.visible.find_by(id: match[1])
  end

  # nil if Settings hasn't been filled in yet, or if the field it names
  # was since deleted or had its format changed away from
  # 'decrementable_int' (e.g. redmine-custom-decrement-field was removed -
  # see that plugin's own README for why Redmine falls back a field's
  # format to a generic Base rather than crashing when that happens).
  def decrement_target_field
    id = Setting.plugin_organikum_qr_scanner['custom_field_id']
    return nil if id.blank?

    IssueCustomField.find_by(id: id, field_format: 'decrementable_int')
  end

  # Always a plain 200 with a `status` field, not a matching HTTP status
  # per outcome - the page only ever branches on `status`, and this keeps
  # `fetch`'s own success/failure handling (network-level, in show.erb)
  # cleanly separate from "did the scan itself succeed".
  def render_scan_result(status, message, issue = nil)
    render json: { status: status, message: message, issue_id: issue&.id, issue_subject: issue&.subject }
  end
end
