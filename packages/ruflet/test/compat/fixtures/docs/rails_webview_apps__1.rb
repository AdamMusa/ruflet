# Docs example: content/docs/rails_webview_apps.md, line 12 (AdamMusa/ruflet_site 05dde18).
# Copied verbatim below this header; do not edit.
# app/views/ruflet/main.rb
Ruflet.run do |page|
  Ruflet::Rails.native_shell(
    page,
    start_url: "#{Ruflet::Rails.backend_url}/dashboard",
    title: "Dashboard",
    loading: :shimmer
  )
end
