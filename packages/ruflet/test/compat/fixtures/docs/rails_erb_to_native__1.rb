# Docs example: content/docs/rails_erb_to_native.md, line 13 (AdamMusa/ruflet_site 05dde18).
# Copied verbatim below this header; do not edit.
# app/views/ruflet/main.rb
Ruflet.run do |page|
  Ruflet::Rails.erb_to_native(
    page,
    start_url: "#{Ruflet::Rails.backend_url}/mobile",
    title: "My app"
  )
end
