# frozen_string_literal: true

module RufletRecord
  class Error < StandardError; end
  class ConnectionNotEstablished < Error; end
  class StatementInvalid < Error; end
  class RecordNotFound < Error; end
  class RecordInvalid < Error
    attr_reader :record

    def initialize(record)
      @record = record
      super("Validation failed: #{record.errors.full_messages.join(', ')}")
    end
  end
  class RecordNotSaved < Error; end
  class UnknownAttributeError < Error; end

  class Errors
    def initialize
      @messages = {}
    end

    def add(attribute, message)
      key = attribute.to_sym
      (@messages[key] ||= []) << message.to_s
    end

    def [](attribute)
      @messages[attribute.to_sym] || []
    end

    def empty?
      @messages.empty?
    end

    def any?
      !empty?
    end

    def clear
      @messages.clear
    end

    def to_hash
      @messages.dup
    end

    def full_messages
      messages = []
      @messages.each do |attribute, entries|
        entries.each do |message|
          if attribute == :base
            messages << message
          else
            name = attribute.to_s.tr("_", " ")
            messages << "#{name[0, 1].upcase}#{name[1..-1]} #{message}"
          end
        end
      end
      messages
    end
  end
end
