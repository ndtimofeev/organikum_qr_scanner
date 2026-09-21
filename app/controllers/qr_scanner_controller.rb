# Renders the scanner page. All of the actual work (camera access, decoding)
# happens client-side in the browser via the vendored html5-qrcode library -
# this action has nothing to compute, since the page doesn't read or write
# any Redmine data.
class QrScannerController < ApplicationController
  before_action :require_login

  def show
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
      Redmine::Plugin.find(:redmine_qr_scanner).assets_directory,
      'javascripts', 'html5-qrcode.min.js'
    )
  end
end
