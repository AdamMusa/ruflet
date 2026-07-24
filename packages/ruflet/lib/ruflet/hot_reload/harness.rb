# frozen_string_literal: true

# Child-process entrypoint used by `ruflet run` when hot reload is enabled.
# The CLI spawns `ruby [-rbundler/setup] harness.rb` with:
#   RUFLET_APP_SCRIPT   absolute path to the application script (required)
#   RUFLET_WATCH_ROOT   directory to watch for *.rb changes (optional)
#   RUFLET_BOOTSNAP_DIR bootsnap cache directory (optional)

# Bootsnap caches compiled bytecode and $LOAD_PATH resolution, which cuts the
# cold-boot cost paid on every full restart ("R"). It is optional: used only
# when the app bundles it (add `gem "bootsnap"` to speed restarts up). Set up
# before requiring the framework so those requires hit the cache.
if (cache_dir = ENV["RUFLET_BOOTSNAP_DIR"].to_s) && !cache_dir.empty?
  begin
    require "bootsnap"
    Bootsnap.setup(
      cache_dir: cache_dir,
      load_path_cache: true,
      compile_cache_iseq: true,
      compile_cache_yaml: false
    )
  rescue LoadError
    # bootsnap not in the bundle; boot without it.
  end
end

require_relative "../hot_reload"

script = ENV["RUFLET_APP_SCRIPT"].to_s
abort "ruflet hot reload: RUFLET_APP_SCRIPT is not set" if script.empty?

Ruflet::HotReload.run(script: script, watch_root: ENV["RUFLET_WATCH_ROOT"])
