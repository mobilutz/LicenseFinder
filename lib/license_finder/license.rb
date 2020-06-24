# frozen_string_literal: true

require 'license_finder/license/text'
require 'license_finder/license/template'

require 'license_finder/license/matcher'
require 'license_finder/license/header_matcher'
require 'license_finder/license/any_matcher'
require 'license_finder/license/none_matcher'

require 'license_finder/license/definitions'

module LicenseFinder
  class License
    class << self
      def all
        @all ||= Definitions.all
      end

      def find_by_name(name)
        name ||= 'unknown'
        if name.include?OrLicense.operator
          return OrLicense.new(name)
        end
        if name.include?AndLicense.operator
          return AndLicense.new(name)
        end
        all.detect { |l| l.matches_name? l.stripped_name(name) } || Definitions.build_unrecognized(name)
      end

      def find_by_text(text)
        all.detect { |l| l.matches_text? text }
      end
    end

    def initialize(settings)
      @short_name  = settings.fetch(:short_name)
      @pretty_name = settings.fetch(:pretty_name, short_name)
      @other_names = settings.fetch(:other_names, [])
      @url         = settings.fetch(:url)
      @matcher     = settings.fetch(:matcher) { Matcher.from_template(Template.named(short_name)) }
    end

    attr_reader :url

    def name
      pretty_name
    end

    def stripped_name(name)
      name.sub(/^The /i, '')
    end

    def matches_name?(name)
      names.map(&:downcase).include? name.to_s.downcase
    end

    def matches_text?(text)
      matcher.matches_text?(text)
    end

    def eql?(other)
      name == other.name
    end

    def hash
      name.hash
    end

    private

    attr_reader :short_name, :pretty_name, :other_names
    attr_reader :matcher

    def names
      ([short_name, pretty_name] + other_names).uniq
    end
  end
  class AndLicense < License
    def self.operator
      " AND "
    end 
    def initialize(name,operator = AndLicense.operator)
      @short_name = name
      @pretty_name = name
      @url = nil
      @matcher = NoneMatcher.new
      # removes heading and trailing parentesis and splits
      names = name[1..-2].split(operator)
      @sub_licenses = names.map do |name|
        License.find_by_name(name)
      end
    end
    def sub_licenses
      @sub_licenses
    end
  end
  
  class OrLicense < AndLicense
    def self.operator
      " OR "
    end 
    def initialize(name,operator = AndLicense.operator)
      super(name, OrLicense.operator)
    end
  end
end
