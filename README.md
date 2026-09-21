# organikum_qr_scanner

A Redmine 6+ plugin: one page, reachable at `/qr_scanner`, that turns on
the device's camera right in the browser and decodes QR codes using
[html5-qrcode](https://github.com/mebjas/html5-qrcode). A successful scan
that resolves to one of this Redmine's own issues decrements a
decrementable custom field (chosen once in Settings) on that issue. The
scanner stays paused - showing a clear success/error message right there
on the page - until the operator taps to continue, rather than navigating
away to the issue on every single scan.

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
- **The camera frame fills the content width** rather than a small fixed
  500px box, for a large, easy-to-aim-at target - Redmine's own layout
  already gives this page the full width since it has no sidebar, and
  `#content`'s own padding is zeroed out on this one page. Only width is
  forced, deliberately not height: an earlier version also forced a fixed
  viewport-relative height (plus `object-fit: cover` on the library's own
  `<video>`) to make the frame taller still, and that stopped the camera
  from starting at all on phones while continuing to work on desktop -
  the unnaturally tall aspect ratio this forced onto the container most
  likely made the library request a camera resolution/aspect ratio mobile
  hardware couldn't satisfy, something a wide desktop webcam tolerates
  far more easily. The frame's height is left to follow the video's own
  natural aspect ratio at 100% width instead. The result banner and "Scan
  next" button are an absolutely-positioned overlay covering that frame,
  not separate page elements below it - and deliberately a sibling of
  `#qr-reader`, not a child placed inside it: the library clears and
  rebuilds that element's own contents at points in its lifecycle
  (start/pause/resume), so anything of ours living inside it would risk
  being wiped out along with it.
- **A scan result is posted, not navigated to** - `show.html.erb` submits
  the decoded text to `POST /qr_scanner/scan` with `fetch`, not a real
  form navigation, so the response (JSON: `status`/`message`) can be shown
  right there on the scanner page instead of a redirect. The moment a code
  decodes, `scanner.pause(true)` freezes the camera preview and stops
  decoding - both so the same code sitting in view can't fire a second
  scan, and as a visible "this is paused" signal in its own right. Nothing
  resumes it but the operator tapping "Scan next", which calls
  `scanner.resume()` - fast (no camera/permission re-acquisition, unlike
  tearing down and recreating the scanner) and deliberate (no fixed
  cooldown to wait out). A successful scan also triggers
  `navigator.vibrate()` where supported, as a signal that doesn't depend
  on the operator looking at the screen at that exact moment.
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
  exhausted checks, and always answers with JSON (`status`/`message`),
  decremented or not. Also reads and memoizes the vendored library's
  source.
- `app/views/qr_scanner/show.html.erb` - the page itself: a `<div>` for
  `Html5QrcodeScanner` to render into, a hidden form pointed at
  `POST /qr_scanner/scan`, a result banner (hidden until a scan comes
  back), the inlined library, and the JS wiring a scan to a `fetch` call,
  `scanner.pause(true)`, and the "Scan next" button to `scanner.resume()`.
- `app/views/settings/_organikum_qr_scanner_settings.html.erb` - the one
  Settings field: which decrementable custom field to act on.
- `assets/javascripts/html5-qrcode.min.js` +
  `html5-qrcode.LICENSE` - the vendored third-party library and its
  license (Apache-2.0), unmodified from the npm package.
