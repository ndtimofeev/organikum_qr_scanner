# organikum_qr_scanner

A Redmine 6+ plugin: two independent scanner pages, both turning on the
device's camera right in the browser and decoding QR codes using
[html5-qrcode](https://github.com/mebjas/html5-qrcode).

- `/qr_scanner` - always decrements a decrementable custom field (chosen
  once in Settings) the moment a scan resolves to one of this Redmine's
  own issues. No confirmation step - built for working through many
  items quickly.
- `/qr_scanner/inspect` - a scan shows that issue's subject, status, and
  the same field's current value, as key/value pairs, with nothing
  changed yet. Only an explicit tap on "Decrement" performs the write;
  "Skip" moves on without touching anything.

These are two different tools for two different situations, not two
"modes" of one screen to flip between - see "Design" for why an earlier
version that tried the mode-switch approach was dropped, and both stay
paused after a scan, showing the result right there on the page, until
the operator dismisses it - see "Design" for how dismissal differs
between the two.

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
  natural aspect ratio at 100% width instead. The result overlay covers
  that same frame rather than sitting below it as separate page elements,
  and is deliberately a sibling of `#qr-reader`, not a child placed inside
  it: the library clears and rebuilds that element's own contents at
  points in its lifecycle (start/pause/resume), so anything of ours living
  inside it would risk being wiped out along with it.
- **A scan result is posted, not navigated to** - both pages submit the
  decoded text with `fetch`, not a real form navigation, so the response
  can be shown right there on the scanner page instead of a redirect. The
  moment a code decodes, `scanner.pause(true)` freezes the camera preview
  and stops decoding - both so the same code sitting in view can't fire a
  second scan, and as a visible "this is paused" signal in its own right.
  A successful decrement also triggers `navigator.vibrate()` where
  supported, as a signal that doesn't depend on the operator looking at
  the screen at that exact moment.
- **Dismissing the result differs between the two pages, on purpose.**
  `/qr_scanner` never has a real decision to make - it always just
  decrements and reports what happened - so the *entire overlay* is the
  "continue" control: tapping anywhere on it calls `scanner.resume()`.
  `/qr_scanner/inspect` does have a decision (decrement or not), so it
  never uses an ambiguous tap-anywhere gesture there: "Decrement" and
  "Skip" are their own explicit, separately labeled buttons, precisely so
  glancing at the screen or an imprecise tap can't be mistaken for (or
  substitute for) a deliberate choice to write something. Once a decrement
  actually happens (or fails), inspect's overlay switches to a single
  outcome message with just one button, `resume()`-bound the same way
  `/qr_scanner`'s tap is - there's nothing left to decide at that point.
- **A scan resolves to a specific, permission-checked local Issue before
  anything else happens.** `QrScannerController#issue_from_scanned_url`
  only ever recognizes a URL whose path matches this Redmine's own
  `/issues/:id` shape, and loads it through `Issue.visible` - so scanning
  can't be used to probe for issues the current user isn't allowed to see,
  and a QR code that isn't a recognized local issue URL (a stray URL, a
  non-URL QR code, garbage) is simply rejected rather than acted on in any
  way.
- **Checks, in order: the issue actually has the configured field, then
  write permission, then whether it's already at zero** - `add_issue_notes`
  is the permission checked (via `Issue#notes_addable?`), matching exactly
  what the field's own decrement button checks, since the mutation really
  is "add a specially formatted comment", nothing more, on both sides.
  Being at or below zero already is read from the field's current
  persisted value rather than re-derived from journal history - the other
  plugin already keeps that value fresh on every save, so there's nothing
  to recompute here.
- **`inspect_scan` (what a scan on the inspect page hits) contains no
  code path that writes anything, full stop** - not "the same action with
  a flag that skips the write", a genuinely separate one that can't. The
  page's "Decrement" button posts to a second, different endpoint -
  `POST /qr_scanner/scan`, the *exact same* one `/qr_scanner`'s own
  scanner uses - with the same decoded URL, so the only path to a write
  anywhere on the inspect page is one explicit, labeled button triggering
  the one action that was always allowed to write.
  - An earlier version tried to unify both pages into one, with a loud
    mode-switch banner and a real page navigation between "decrement
    mode" and "inspect mode" (navigation, rather than a client-side
    toggle, specifically so the page could never end up believing it was
    in one mode while posting to the other's endpoint). It was dropped
    for two reasons: switching required the browser to re-acquire the
    camera stream from scratch every time (no permission re-prompt in
    practice, but a real, noticeable delay), and the banner itself ate
    into the limited screen space around a camera frame that's already
    competing with Redmine's own header for room on a phone screen.
    Splitting into two purpose-built tools instead of one with a mode
    removes the need to switch often at all - you pick the one suited to
    what you're about to do - and removes the banner along with it.
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

- No menu entry / link to either page anywhere in Redmine's UI yet -
  reach them by typing the URL directly for now. The two pages don't
  link to each other either (see "Design" on why the mode-switch banner
  that used to do that was dropped).
- Only one field, globally, can be configured - not one per tracker or
  per project. Scanning an issue whose tracker doesn't carry that field
  is reported as an error (`error_qr_scanner_field_missing`) on
  `/qr_scanner`, or simply not shown as a line on `/qr_scanner/inspect`.
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

4. Log in and visit `/qr_scanner` (always decrements) or
   `/qr_scanner/inspect` (look first, decrement optionally) over HTTPS.
   Grant the camera permission prompt, then point it at a QR code
   encoding one of this Redmine's issue URLs.

## Structure

- `config/routes.rb` - `GET /qr_scanner` + `POST /qr_scanner/scan`,
  `GET /qr_scanner/inspect` + `POST /qr_scanner/inspect_scan`.
- `app/controllers/qr_scanner_controller.rb` - `show`/`inspect` render
  their respective pages; `scan` resolves the decoded URL to an issue,
  runs the field/permission/exhausted checks, and always answers with
  JSON, decremented or not - used directly by `/qr_scanner`'s scanner,
  and by `/qr_scanner/inspect`'s "Decrement" button; `inspect_scan`
  resolves the same way but only ever reads (subject/status/field
  value/whether decrementing is currently offered), never writes. Also
  reads and memoizes the vendored library's source.
- `app/views/qr_scanner/show.html.erb` - the always-decrements page: a
  `<div>` for `Html5QrcodeScanner`, a hidden form posting to
  `POST /qr_scanner/scan`, a tap-anywhere result overlay, the inlined
  library, and the JS wiring a scan to `fetch` + `scanner.pause(true)`.
- `app/views/qr_scanner/inspect.html.erb` - the look-first page: the same
  camera setup, two hidden forms (one for the read-only lookup every scan
  does, one for the actual decrement - only ever submitted by the
  "Decrement" button's own handler), a key/value result overlay
  (`<dl>`-based) with "Decrement"/"Skip" buttons that switches to a
  single outcome message + one button once a decrement has actually been
  attempted.
- `app/views/settings/_organikum_qr_scanner_settings.html.erb` - the one
  Settings field: which decrementable custom field to act on (read by
  both pages).
- `assets/javascripts/html5-qrcode.min.js` +
  `html5-qrcode.LICENSE` - the vendored third-party library and its
  license (Apache-2.0), unmodified from the npm package.
