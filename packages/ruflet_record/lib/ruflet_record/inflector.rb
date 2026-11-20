# frozen_string_literal: true

module RufletRecord
  module Inflector
    # Plurals of words that end in "sse" (crevasse, mousse); singularize
    # drops only their "s", so they keep the result they had before -sses
    # plurals lost "es". Where the -ss word is the usual one (pass, mass,
    # cross, princess), it wins.
    SSE_PLURALS = %w[
      abscisses anabasses bagasses bouillabaisses bretesses causses chasses
      cosses coulisses crevasses cuisses damasses delicatesses demitasses
      filasses finesses fougasses gentilesses graisses hausses heathenesses
      impasses lacrosses largesses molosses mousses nisses noblesses
      paillasses palliasses pelisses politesses posses retrousses richesses
      rubasses varisses vinasses wrasses
    ].freeze
    # The same for whole words: as suffixes these would also catch the
    # plurals of -ss words (carcasses, bosses, grasses, potasses, swisses).
    SSE_WORDS = %w[casses fosses osses rasses tasses tendresses wisses].freeze

    class << self

    def underscore(value)
      word = value.to_s.gsub("::", "/")
      word = word.gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
      word = word.gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
      word.tr("-", "_").downcase
    end

    def pluralize(value)
      word = value.to_s
      # category -> categories and soliloquy -> soliloquies, but a y after
      # another vowel stays: survey -> surveys.
      if word.end_with?("y") && word.length > 1 && (!"aeiou".include?(word[-2, 1]) || word.end_with?("quy"))
        return "#{word[0...-1]}ies"
      end
      return "#{word}es" if word.end_with?("s", "x", "z", "ch", "sh")

      "#{word}s"
    end

    # The inverse of pluralize for the words it pluralizes with "es": a
    # trailing "es" goes after ss, ch, sh, x and z, and after status, bus and
    # alias, so addresses -> address, not addresse. The -sse words above
    # and other "-uses" words (abuse, minibus) are left as before.
    def singularize(value)
      word = value.to_s
      return "#{word[0...-3]}y" if word.end_with?("ies")
      return word[0...-1] if word.end_with?(*Inflector::SSE_PLURALS) || Inflector::SSE_WORDS.include?(word.split("_").last)
      return word[0...-2] if word.end_with?("sses", "ches", "shes", "xes", "zes", "statuses", "aliases")
      return word[0...-2] if word == "buses" || word.end_with?("_buses")
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
