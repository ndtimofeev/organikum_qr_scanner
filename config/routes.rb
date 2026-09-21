# A single page: point the camera at a QR code, get redirected to whatever
# URL it encodes. Top-level rather than nested under a project or issue,
# since scanning isn't about any one project - it's a generic "read a code,
# go there" utility that happens to be most useful for issue URLs.
get 'qr_scanner', to: 'qr_scanner#show', as: 'qr_scanner'
