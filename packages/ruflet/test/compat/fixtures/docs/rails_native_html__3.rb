# Docs example: content/docs/rails_native_html.md, line 37 (AdamMusa/ruflet_site 05dde18).
# Copied verbatim below this header; do not edit.
# app/views/ruflet/main.rb
Ruflet.run do |page|
  Ruflet::Rails.native_shell(
    page,
    start_url: "#{Ruflet::Rails.backend_url}/dashboard",
    title: "Dashboard"
  )
end
