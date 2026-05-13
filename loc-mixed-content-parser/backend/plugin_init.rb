require_relative '../loc_mixed_content_parser'

module MixedContentParser
  def self.parse( content, base_uri, opts = {} )
    LocMixedContentParser::parse( content, base_uri, opts = {} )
  end
end

module SortNameProcessor

  module CorporateEntity
    class << self
      alias_method :process_orig, :process

      def process(json, extras = {})
        result = process_orig(json, extras)
        if result.include?("<")
          result = LocMixedContentParser::remove_tags(result)
        end
        result
      end
    end
  end

  module Person
    class << self
      alias_method :process_orig, :process

      def process(json, extras = {})
        result = process_orig(json, extras)
        if result.include?("<")
          result = LocMixedContentParser::remove_tags(result)
        end
        result
      end
    end
  end

  module Family
    class << self
      alias_method :process_orig, :process

      def process(json, extras = {})
        result = process_orig(json, extras)
        if result.include?("<")
          result = LocMixedContentParser::remove_tags(result)
        end
        result
      end
    end
  end
end
