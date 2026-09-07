# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CodeEditorControl < Ruflet::Control
          TYPE = "code_editor".freeze
          WIRE = "CodeEditor".freeze
          KEYWORDS = [].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each { |key, value| compact[key] = value unless value.nil? }
            super(type: TYPE, id: id, **compact)
          end

          %w[focus fold_comment_at_line_zero fold_imports].each do |method_name|
            define_method(method_name) do |timeout: 10, on_result: nil|
              invoke_editor(method_name, timeout: timeout, on_result: on_result)
            end
          end

          def fold_at(line_number, timeout: 10, on_result: nil)
            invoke_editor(
              "fold_at",
              args: { "line_number" => line_number },
              timeout: timeout,
              on_result: on_result
            )
          end

          private

          def invoke_editor(method_name, args: nil, timeout:, on_result:)
            runtime_page&.invoke(self, method_name, args: args, timeout: timeout, on_result: on_result)
          end
        end
      end
    end
  end
end
