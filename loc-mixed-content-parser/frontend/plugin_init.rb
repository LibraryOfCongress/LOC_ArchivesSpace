require_relative '../loc_mixed_content_parser'

ArchivesSpace::Application.config.after_initialize do

  module MixedContentParser

    def self.parse( content, base_uri, opts = {} )
      LocMixedContentParser::parse( content, base_uri, opts = {} )
    end
  end
end
