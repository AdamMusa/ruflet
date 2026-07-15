# frozen_string_literal: true

# Minimal FileUtils built on the VM's File/Dir primitives.
module FileUtils
  class << self
    def mkdir_p(list, **_opts)
      Array(list).each do |path|
        parts = path.to_s.split("/")
        current = path.to_s.start_with?("/") ? "/" : ""
        parts.each do |part|
          next if part.empty?

          current = current.empty? ? part : "#{current.chomp('/')}/#{part}"
          Dir.mkdir(current) unless File.directory?(current)
        end
      end
      list
    end
    alias makedirs mkdir_p
    alias mkpath mkdir_p

    def mkdir(list, **_opts)
      Array(list).each { |path| Dir.mkdir(path.to_s) }
      list
    end

    def touch(list, **_opts)
      Array(list).each do |path|
        File.open(path.to_s, "a") { |io| io }
      end
      list
    end

    def rm_f(list, **_opts)
      Array(list).each do |path|
        begin
          File.delete(path.to_s)
        rescue StandardError
          nil
        end
      end
      list
    end
    alias safe_unlink rm_f

    def rm(list, **_opts)
      Array(list).each { |path| File.delete(path.to_s) }
      list
    end

    def cp(src, dest, **_opts)
      content = File.open(src.to_s, "rb") { |io| io.read }
      target = File.directory?(dest.to_s) ? "#{dest.to_s.chomp('/')}/#{File.basename(src.to_s)}" : dest.to_s
      File.open(target, "wb") { |io| io.write(content) }
      target
    end
    alias copy cp

    def mv(src, dest, **_opts)
      File.rename(src.to_s, dest.to_s)
    end
    alias move mv
  end
end
