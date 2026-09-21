# Top-level rather than nested under a project or issue, since scanning
# isn't about any one project.
get 'qr_scanner', to: 'qr_scanner#show', as: 'qr_scanner'

# The browser posts the decoded text here (a real form submission, not an
# AJAX call - see the view) once a QR code has been read; this action does
# the actual lookup/permission/decrement work and redirects on to the
# issue (or back to the scanner page with an error).
post 'qr_scanner/scan', to: 'qr_scanner#scan', as: 'scan_qr_scanner'
