# frozen_string_literal: true

module Ruflet
  module Rails
    module Protocol
      class MobileLoader
        def initialize(file_path)
          @file_path = file_path
        end

        def load!
          absolute = File.expand_path(@file_path)
          raise ArgumentError, "Mobile file not found: #{absolute}" unless File.file?(absolute)

          captured_entrypoint = nil
          interceptor = lambda do |entrypoint:, **_kwargs|
            captured_entrypoint = entrypoint
            :captured
          end

          Ruflet.with_run_interceptor(interceptor) do
            Kernel.load(absolute)
          end

          raise ArgumentError, "No Ruflet app boot found in #{absolute}. Expected MyApp.new.run" unless captured_entrypoint

          { entrypoint: captured_entrypoint }
        end
      end
    end
  end
end
