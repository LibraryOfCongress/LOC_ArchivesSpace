ArchivesSpacePublic::Application.config.after_initialize do

  class Record
    alias_method :parse_sub_container_display_string_orig, :parse_sub_container_display_string

    def parse_sub_container_display_string(sub_container, inst, opts = {})
      if inst['instance_type'].nil?
        inst['instance_type'] = "NO_INSTANCE_TYPE"
      end
      container_display_string = parse_sub_container_display_string_orig(sub_container, inst, opts)
      container_display_string.sub("(NO_INSTANCE_TYPE)", "")
    end

    alias_method :parse_full_title_orig, :parse_full_title

    def parse_full_title(infinite_item = false)
      unless infinite_item || json['title_inherited'].blank? || (json['display_string'] || '') == json['title']
        return "#{json['title']}, #{json['display_string']}"
      end
      title = json['display_string'] || json['title']
      if @resolved_resource && @resolved_resource.has_key?('uri')
        title.gsub!(/<ref .*?target="(.+?)".*?>(.+?)<\/ref>/m, "<a href='#{@resolved_resource['uri']}/resolve/\\1'>\\2</a>")
      end

      return process_mixed_content_title(title)
    end

  end


  class ERBNoteRenderer
    @note_types << "note_unorderedlist"
  end


  class ArchivalObject

    def additional_identifiers
      json['additional_identifiers']
    end

  end

  module ResultInfo
    def process_repo_info(repo)
      info = {}
      info['top'] = {}
      unless repo.nil?
        %w(name uri url parent_institution_name image_url repo_code description).each do |item|
          info['top'][item] = repo[item] unless repo[item].blank?
        end
        unless repo['agent_representation'].blank? || repo['agent_representation']['_resolved'].blank? || repo['agent_representation']['_resolved']['agent_contacts'].blank? || repo['agent_representation']['_resolved']['jsonmodel_type'] != 'agent_corporate_entity'
          in_h = repo['agent_representation']['_resolved']['agent_contacts'][0]
          %w{city region post_code country email contact_form}.each do |k|
            info[k] = in_h[k] if in_h[k].present?
          end
          if in_h['address_1'].present?
            info['address'] = []
            [1, 2, 3].each do |i|
              info['address'].push(in_h["address_#{i}"]) if in_h["address_#{i}"].present?
            end
          end
          info['telephones'] = in_h['telephones'] if !in_h['telephones'].blank?
        end
      end
      info
    end
  end
end