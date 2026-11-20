# frozen_string_literal: true

module RufletCompat
  # Minimal, deterministic ustar reader/writer for the frozen fixture template.
  #
  # Entries are written in the order given with fixed owner, group and mtime,
  # so the same inputs always produce the same bytes. Only regular files are
  # supported: the vendored template has no symlinks or special files.
  module Tar
    BLOCK = 512
    Entry = Struct.new(:path, :mode, :data, keyword_init: true)

    module_function

    def write(io, entries)
      entries.each do |entry|
        data = entry.data.b
        io.write(header(entry.path, entry.mode, data.bytesize))
        io.write(data)
        io.write("\0" * ((BLOCK - (data.bytesize % BLOCK)) % BLOCK))
      end
      io.write("\0" * (BLOCK * 2))
    end

    def read(io)
      entries = []
      loop do
        block = io.read(BLOCK)
        break if block.nil? || block.bytesize < BLOCK || block.bytes.all?(&:zero?)

        name = field(block, 0, 100)
        mode = field(block, 100, 8).to_i(8)
        size = field(block, 124, 12).to_i(8)
        type = block.byteslice(156, 1)
        prefix = field(block, 345, 155)
        path = prefix.empty? ? name : "#{prefix}/#{name}"
        data = size.zero? ? +"" : io.read(size)
        io.read((BLOCK - (size % BLOCK)) % BLOCK)
        next unless ["0", "\0"].include?(type)

        entries << Entry.new(path: path, mode: mode, data: data.b)
      end
      entries
    end

    def header(path, mode, size)
      name, prefix = split_path(path)
      block = ("\0" * BLOCK).b
      put(block, 0, name, 100)
      put(block, 100, format("%07o\0", mode), 8)
      put(block, 108, "0000000\0", 8)
      put(block, 116, "0000000\0", 8)
      put(block, 124, format("%011o\0", size), 12)
      put(block, 136, "00000000000\0", 12)
      put(block, 148, " " * 8, 8)
      put(block, 156, "0", 1)
      put(block, 257, "ustar\0", 6)
      put(block, 263, "00", 2)
      put(block, 345, prefix, 155)
      checksum = block.bytes.sum
      put(block, 148, format("%06o\0 ", checksum), 8)
      block
    end

    def split_path(path)
      return [path, ""] if path.bytesize <= 100

      parts = path.split("/")
      (1...parts.length).reverse_each do |index|
        prefix = parts[0...index].join("/")
        name = parts[index..].join("/")
        return [name, prefix] if name.bytesize <= 100 && prefix.bytesize <= 155
      end
      raise ArgumentError, "path too long for ustar: #{path}"
    end

    def put(block, offset, value, width)
      bytes = value.b
      raise ArgumentError, "tar field overflow: #{value.inspect}" if bytes.bytesize > width

      block[offset, bytes.bytesize] = bytes
    end

    def field(block, offset, width)
      block.byteslice(offset, width).split("\0", 2).first.to_s.strip
    end
  end
end
