# Top-level rather than nested under a project or issue, since scanning
# isn't about any one project.
get 'qr_scanner', to: 'qr_scanner#show', as: 'qr_scanner'

# The browser posts the decoded text here (a real form submission, not an
# AJAX call - see the view) once a QR code has been read; this action does
# the actual lookup/permission/decrement work and redirects on to the
# issue (or back to the scanner page with an error).
post 'qr_scanner/scan', to: 'qr_scanner#scan', as: 'scan_qr_scanner'

# A second, entirely separate page and endpoint for read-only lookups
# (subject/status/field value) - never routed through the same action as
# the decrement above, on purpose: see QrScannerController#inspect_scan.
get 'qr_scanner/inspect', to: 'qr_scanner#inspect', as: 'inspect_qr_scanner'
post 'qr_scanner/inspect_scan', to: 'qr_scanner#inspect_scan', as: 'inspect_scan_qr_scanner'
