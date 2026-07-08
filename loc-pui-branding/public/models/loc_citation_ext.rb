# AS-464: Inject EAD Location (handle URL) into citation modal boxes.
#
# "Cite Item" (upper box):         base citation text + handle appended
# "Cite Item Description" (lower): base citation text + handle, replacing ASpace URL

Resource.class_eval do
  private

  def parse_cite_string(cite_type)
    cite = note('prefercite')
    unless cite.blank?
      cite = strip_mixed_content(cite['note_text'])
    else
      cite = strip_mixed_content(display_string)
      cite += identifier.blank? ? '' : ", #{identifier}"
      cite += if container_display.blank? || container_display.length > 5
                '.'
              else
                @citation_container_display ||= parse_container_display(:citation => true).join('; ')
                ", #{@citation_container_display}."
              end

      unless repository_information['top']['name'].blank?
        repo_name = repository_information['top']['name'].strip
        repo_name = repo_name.chomp('.')
        cite += " #{repo_name}"

        if !cite.include?("Library of Congress")
          cite += ", Library of Congress, Washington, D.C."
        end

        cite += "." unless cite.end_with?('.')
      end
    end

    cite   = CGI::escapeHTML(cite)
    handle = json['ead_location'].presence

    if cite_type == "description"
      suffix = handle || "#{cite_url_and_timestamp}."
      HTMLEntities.new.decode("#{cite} #{suffix}")
    else
      HTMLEntities.new.decode(handle ? "#{cite} #{handle}" : cite)
    end
  end
end

ArchivalObject.class_eval do
  def cite_item
    cite   = build_ao_cite_base
    handle = loc_resource_handle_from_resolved
    HTMLEntities.new.decode(handle ? "#{cite} #{handle}" : cite)
  end

  def cite_item_description
    cite   = build_ao_cite_base
    handle = loc_resource_handle_from_resolved
    suffix = handle || "#{cite_url_and_timestamp}."
    HTMLEntities.new.decode("#{cite} #{suffix}")
  end

  private

  def build_ao_cite_base
    cite = note('prefercite')
    if !cite.blank?
      strip_mixed_content(cite['note_text'])
    else
      cite = strip_mixed_content(display_string)
      cite += identifier.blank? ? '' : ", #{identifier}"
      cite += if container_display.blank? || container_display.length > 5
                '.'
              else
                @citation_container_display ||= parse_container_display(:citation => true).join('; ')
                ", #{@citation_container_display}."
              end
      if resolved_resource
        ttl = resolved_resource.dig('title')
        cite += " #{strip_mixed_content(ttl)}, #{resource_identifier}."
      end

      unless repository_information['top']['name'].blank?
        repo_name = repository_information['top']['name'].strip
        repo_name = repo_name.chomp('.')
        cite += " #{repo_name}"

        if !cite.include?("Library of Congress")
          cite += ", Library of Congress, Washington, D.C."
        end

        cite += "." unless cite.end_with?('.')
      end
      cite
    end
  end

  def loc_resource_handle_from_resolved
    if resolved_resource
      return resolved_resource['ead_location']
    end

    nil
  end
end

DigitalObject.class_eval do
  private

  def parse_cite_string(cite_type)
    cite = note('prefercite')
    unless cite.blank?
      cite = strip_mixed_content(cite['note_text'])
    else
      cite = strip_mixed_content(display_string)
      cite += identifier.blank? ? '' : ", #{identifier}"
      cite += if container_display.blank? || container_display.length > 5
                '.'
              else
                @citation_container_display ||= parse_container_display(:citation => true).join('; ')
                ", #{@citation_container_display}."
              end

      unless repository_information['top']['name'].blank?
        repo_name = repository_information['top']['name'].strip
        repo_name = repo_name.chomp('.')
        cite += " #{repo_name}"

        if !cite.include?("Library of Congress")
          cite += ", Library of Congress, Washington, D.C."
        end

        cite += "." unless cite.end_with?('.')
      end
    end

    handle = loc_do_resource_handle

    if cite_type == "description"
      suffix = handle || "#{cite_url_and_timestamp}."
      HTMLEntities.new.decode("#{cite} #{suffix}")
    else
      HTMLEntities.new.decode(handle ? "#{cite} #{handle}" : cite)
    end
  end

  def loc_do_resource_handle
    return nil unless raw['_resolved_linked_instance_uris'].is_a?(Hash)

    first_uri = raw['_resolved_linked_instance_uris'].keys.first
    return nil if first_uri.nil?

    ao_solr_docs = raw['_resolved_linked_instance_uris'][first_uri]
    return nil unless ao_solr_docs.is_a?(Array) && !ao_solr_docs.empty?

    ao_raw = ao_solr_docs.first
    return nil unless ao_raw.is_a?(Hash)

    ao_json = ao_raw['json']
    if ao_json.is_a?(String)
      begin
        ao_json = ASUtils.json_parse(ao_json)
      rescue
        return nil
      end
    end

    if ao_json.is_a?(Hash) && ao_json['_resolved_resource'].is_a?(Hash)
      res_resolved = ao_json['_resolved_resource']
      res_json = res_resolved.is_a?(Hash) ? res_resolved['json'] : nil

      if res_json.is_a?(String)
        begin
          res_json = ASUtils.json_parse(res_json)
        rescue
          return nil
        end
      end

      return res_json['ead_location'].presence if res_json.is_a?(Hash)
    end
    nil
  rescue
    nil
  end
end
