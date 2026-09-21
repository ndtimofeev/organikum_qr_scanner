# organikum_qr_scanner

A Redmine 6+ plugin: one page, reachable at `/qr_scanner`, that turns on
the device's camera right in the browser and decodes QR codes using
[html5-qrcode](https://github.com/mebjas/html5-qrcode). When a code
decodes to something, the browser navigates to it.

**Status: sketch.** Deliberately minimal - see "Scope" below.

## Design

- **The entire contract is "a QR code is a URL".** This plugin has no idea
  what's on the other end - it doesn't know about issues, custom fields,
  or `redmine-custom-decrement-field`. Anything that can produce a QR code
  containing a Redmine URL (or any other URL) can be scanned here; nothing
  about this plugin needs to change for that. This is deliberate: keeping
  "read a code" and "act on what it says" as two unrelated plugins means
  either one can be replaced or reused independently.
- **Scanning happens entirely in the browser**, via camera access
  (`getUserMedia`) and client-side decoding - no image is ever uploaded to
  the server. `Html5QrcodeScanner` (the library's own high-level widget)
  draws its own start button, camera picker, and viewfinder; this plugin
  only provides the page and the div it renders into.
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

This is intentionally cut down to "a route and a page that launches the
scanner", nothing more:

- No menu entry / link to `/qr_scanner` anywhere in Redmine's UI yet -
  reach it by typing the URL directly for now.
- No validation of what a decoded code contains - `decodedText` is handed
  straight to `window.location.href`. In practice this is fine as long as
  only trusted, self-printed QR codes (e.g. from
  `redmine-custom-decrement-field`'s own future "print a QR code for this
  issue" feature) ever get scanned by it, but a malicious or scanned-by-
  mistake code could navigate somewhere unexpected - worth a second look
  before this is used in the field.
- No generation/printing of QR codes - this plugin only reads them. Where
  the codes it scans come from is a separate concern.
- No automated tests.

## Installation

1. Clone into Redmine's `plugins/` directory as `redmine_qr_scanner`:

   ```bash
   cd /path/to/redmine/plugins
   git clone https://github.com/ndtimofeev/organikum_qr_scanner redmine_qr_scanner
   ```

2. Restart Redmine (no migrations, no `bundle install` needed - this
   plugin has no dependencies of its own beyond Redmine itself).

3. Log in and visit `/qr_scanner` over HTTPS. Grant the camera permission
   prompt; point it at any QR code containing a URL.

## Structure

- `config/routes.rb` - the one route, `GET /qr_scanner`.
- `app/controllers/qr_scanner_controller.rb` - renders the page; also
  reads and memoizes the vendored library's source.
- `app/views/qr_scanner/show.html.erb` - the page itself: a `<div>` for
  `Html5QrcodeScanner` to render into, the inlined library, and the
  handful of lines wiring a successful scan to `window.location.href`.
- `assets/javascripts/html5-qrcode.min.js` +
  `html5-qrcode.LICENSE` - the vendored third-party library and its
  license (Apache-2.0), unmodified from the npm package.
