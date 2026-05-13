require_relative '../loc_mixed_content_parser'

ArchivesSpacePublic::Application.config.after_initialize do

  module MixedContentParser

    def self.parse( content, base_uri, opts = {} )
      LocMixedContentParser::parse( content, base_uri, opts = {} )
    end
  end


  module ManipulateNode
    # I can't understand why this core method exists. It transforms the input
    # to HTML before the SGML tags have been mapped, so you can end up with
    # something like this: <title><part>STRING</part></title> ->
    # <title>&lt;part&gt;STRING&lt;part&gt;</title>
    # because <title> is legal HTML but <part> is not.
    def process_mixed_content_title(text)
      return text
    end
  end


  class Record

    def parsed_display_string
      @parsed_display_string ||= process_mixed_content(json['display_string'] || json['title'])
      @parsed_display_string
    end

    def parse_sub_container_display_string(sub_container, inst, opts = {})
      summary = opts.fetch(:summary, false)
      citation = opts.fetch(:citation, false)
      parts = []

      instance_type = inst['instance_type'] || "undefined"
      instance_type = I18n.t("enumerations.instance_instance_type.#{instance_type}", :default => instance_type)

      # add the top container type and indicator
      if sub_container.has_key?('top_container')
        top_container_solr = top_container_for_uri(sub_container['top_container']['ref'])
        if top_container_solr
          # We have a top container from Solr
          top_container_display_string = ""
          top_container_json = ASUtils.json_parse(top_container_solr.fetch('json'))
          if top_container_json['type']
            top_container_type = I18n.t("enumerations.container_type.#{top_container_json.fetch('type')}", :default => top_container_json.fetch('type'))
            top_container_display_string << "#{top_container_type}: "
          else
            top_container_display_string << "#{I18n.t('enumerations.container_type.container')}: "
          end
          top_container_display_string << top_container_json.fetch('indicator')
          parts << top_container_display_string
        elsif sub_container['top_container']['_resolved'] && sub_container['top_container']['_resolved']['display_string']
          # We have a resolved top container with a display string
          parts << sub_container['top_container']['_resolved']['display_string']
        end
      end


      # add the child type and indicator
      if sub_container['type_2'] && sub_container['indicator_2']
        type = I18n.t("enumerations.container_type.#{sub_container.fetch('type_2')}", :default => sub_container.fetch('type_2'))
        parts << "#{type}: #{sub_container.fetch('indicator_2')}"
      end

      # add the grandchild type and indicator
      if sub_container['type_3'] && sub_container['indicator_3']
        type = I18n.t("enumerations.container_type.#{sub_container.fetch('type_3')}", :default => sub_container.fetch('type_3'))
        parts << "#{type}: #{sub_container.fetch('indicator_3')}"
      end

      (summary || citation) ? parts.join(", ") : "#{parts.join(", ")} (#{instance_type})"
    end
  end
end
