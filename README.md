# organikum_qr_scanner

A Redmine 6+ plugin: one page, reachable at `/qr_scanner`, that turns on
the device's camera right in the browser and decodes QR codes using
[html5-qrcode](https://github.com/mebjas/html5-qrcode). A successful scan
that resolves to one of this Redmine's own issues decrements a
decrementable custom field (chosen once in Settings) on that issue, then
opens it.

**Status: sketch.** Deliberately minimal - see "Scope" below.

## Design

- **Loosely coupled to `redmine-custom-decrement-field`, on purpose - no
  hard dependency.** This plugin never `require`s or references that
  plugin's Ruby code. It only reads `custom_field.format_store` - a plain
  column/Rails `store` that Redmine core itself declares on every
  `CustomField` (`app/models/custom_field.rb`), regardless of which
  formats happen to be registered - and only ever offers fields whose
  `field_format` is the string `'decrementable_int'` (see the Settings
  partial and `QrScannerController#decrement_target_field`). If that
  plugin isn't installed, no field can have that format, Settings simply
  offers nothing to pick, and this plugin never finds a field to act on -
  it degrades to "does nothing", not a crash. The actual decrement is done
  the same way that plugin's own button does it: add an issue comment
  containing `"#{token}:-1"` and let its own `after_save` hooks derive the
  new value from history, exactly as if a human had typed that comment.
- **Scanning happens entirely in the browser**, via camera access
  (`getUserMedia`) and client-side decoding - no image is ever uploaded to
  the server. `Html5QrcodeScanner` (the library's own high-level widget)
  draws its own start button, camera picker, and viewfinder; this plugin
  only provides the page and the div it renders into. The server never
  sees anything but the decoded *text* of a successful scan.
- **A scan resolves to a specific, permission-checked local Issue before
  anything else happens.** `QrScannerController#issue_from_scanned_url`
  only ever recognizes a URL whose path matches this Redmine's own
  `/issues/:id` shape, and loads it through `Issue.visible` - so scanning
  can't be used to probe for issues the current user isn't allowed to see,
  and a QR code that isn't a recognized local issue URL (a stray URL, a
  non-URL QR code, garbage) is simply rejected rather than acted on in any
  way. An earlier version of this plugin instead handed whatever text was
  decoded straight to `window.location.href` - harmless when the only
  consequence was "the browser navigates somewhere", but not once scanning
  could also trigger a write.
- **Checks, in order: the issue actually has the configured field, then
  write permission, then whether it's already at zero** - `add_issue_notes`
  is the permission checked (via `Issue#notes_addable?`), matching exactly
  what the field's own decrement button checks, since the mutation really
  is "add a specially formatted comment", nothing more, on both sides.
  Being at or below zero already is read from the field's current
  persisted value rather than re-derived from journal history - the other
  plugin already keeps that value fresh on every save, so there's nothing
  to recompute here.
- **The library is vendored, not pulled from a CDN or Redmine's plugin
  asset pipeline.** `assets/javascripts/html5-qrcode.min.js` is the
  project's own official minified UMD build (from the `html5-qrcode` npm
  package), read from disk and inlined into the page with a plain
  `File.read`, the same way `redmine-custom-decrement-field` ended up
  inlining its own JS - that plugin's history is the reason: Redmine's
  Propshaft-based plugin asset pipeline depends on `bin/rails
  assets:precompile` having actually been run, which isn't reliable on
  every deployment. Vendoring also means this page keeps working on a
  network with no outbound internet access (e.g. an internal warehouse
  LAN with no route to a CDN).
- **Requires HTTPS** (or `localhost`) - browsers refuse camera access
  (`getUserMedia`) on a plain-HTTP origin, full stop, regardless of
  anything this plugin does. If your Redmine is only reachable over HTTP,
  this page will load but the camera will never start.

## Scope - what this deliberately does NOT do yet

- No menu entry / link to `/qr_scanner` anywhere in Redmine's UI yet -
  reach it by typing the URL directly for now.
- Only one field, globally, can be configured - not one per tracker or
  per project. Scanning an issue whose tracker doesn't carry that field
  is reported as an error (`error_qr_scanner_field_missing`), not ignored
  silently.
- No generation/printing of QR codes - this plugin only reads them. Where
  the codes it scans come from is a separate concern.
- No automated tests.

## Installation

1. Clone into Redmine's `plugins/` directory as `organikum_qr_scanner`
   (matching the plugin's own registered id, `Redmine::Plugin.register
   :organikum_qr_scanner` in `init.rb`):

   ```bash
   cd /path/to/redmine/plugins
   git clone https://github.com/ndtimofeev/organikum_qr_scanner organikum_qr_scanner
   ```

2. Restart Redmine (no migrations, no `bundle install` needed - this
   plugin has no dependencies of its own beyond Redmine itself).

3. **Administration &rarr; Plugins &rarr; QR Scanner &rarr; Configure**:
   pick the decrementable field to act on. Only fields using
   `redmine-custom-decrement-field`'s "Decrementable integer" format are
   offered; if none exist yet, create one there first.

4. Log in and visit `/qr_scanner` over HTTPS. Grant the camera permission
   prompt, then point it at a QR code encoding one of this Redmine's
   issue URLs.

## Structure

- `config/routes.rb` - `GET /qr_scanner` (the camera page) and
  `POST /qr_scanner/scan` (what a successful scan submits to).
- `app/controllers/qr_scanner_controller.rb` - `show` renders the page;
  `scan` resolves the decoded URL to an issue, runs the field/permission/
  exhausted checks, and either redirects to the issue (decremented or
  not) or back to the scanner page with an error. Also reads and
  memoizes the vendored library's source.
- `app/views/qr_scanner/show.html.erb` - the page itself: a `<div>` for
  `Html5QrcodeScanner` to render into, a hidden form pointed at
  `POST /qr_scanner/scan`, the inlined library, and the handful of lines
  that fill in and submit that form on a successful scan.
- `app/views/settings/_organikum_qr_scanner_settings.html.erb` - the one
  Settings field: which decrementable custom field to act on.
- `assets/javascripts/html5-qrcode.min.js` +
  `html5-qrcode.LICENSE` - the vendored third-party library and its
  license (Apache-2.0), unmodified from the npm package.
