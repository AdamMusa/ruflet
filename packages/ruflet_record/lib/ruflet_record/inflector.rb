# frozen_string_literal: true

module RufletRecord
  module Inflector
    class << self

    def underscore(value)
      word = value.to_s.gsub("::", "/")
      word = word.gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
      word = word.gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
      word.tr("-", "_").downcase
    end

    def pluralize(value)
      word = value.to_s
      return "#{word[0...-1]}ies" if word.end_with?("y") && word.length > 1
      return "#{word}es" if word.end_with?("s", "x", "z", "ch", "sh")

      "#{word}s"
    end

    def singularize(value)
      word = value.to_s
      return "#{word[0...-3]}y" if word.end_with?("ies")
      return word[0...-2] if word.end_with?("ches", "shes", "xes", "zes")
      return word[0...-1] if word.end_with?("s") && !word.end_with?("ss")

      word
    end

    def classify(value)
      singularize(value.to_s).split("_").map { |part| "#{part[0, 1].upcase}#{part[1..-1]}" }.join
    end

    def constantize(value)
      names = value.to_s.split("::")
      names.shift if names.first == ""
      names.inject(Object) { |scope, name| scope.const_get(name) }
    end
    end
  end
end
