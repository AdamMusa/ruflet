# Docs example: content/docs/rails_api_reference.md, line 104 (AdamMusa/ruflet_site 05dde18).
# Copied verbatim below this header; do not edit.
Ruflet.run do |page|
  Ruflet::Rails.erb_to_native(
    page,
    start_url: "#{Ruflet::Rails.backend_url}/mobile",
    title: "My app"
  )
end
