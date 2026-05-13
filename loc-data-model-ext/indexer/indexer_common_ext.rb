class IndexerCommon

  alias_method :add_agents_orig, :add_agents

  def add_agents(doc, record)

    add_agents_orig(doc, record)

    # This is a stopgap to prevent many unneccessary
    # dynamic schema fields being added. It can be
    # removed when this PR is merged and released:
    # https://github.com/archivesspace/archivesspace/pull/3487
    doc.reject! { |k,_| k =~ /_relator_sort$/ }
  end

# AS-500: Shared logic to force alphabetic titles to the top of A-Z sorts
  def self.generate_alpha_title_sort(doc, record)
    return unless doc['primary_type'] == 'digital_object'

    title = doc['title'] || record['record']['title'] || record['record']['display_string'] || ""
    # Strip leading punctuation/brackets so titles like "[Untitled]" are evaluated by their first letter
    clean_title = title.strip.sub(/^["'\[]+/, '')
    
    # Prefix non-alphabetic titles with 'zzzz' to push them to the end of ascending sort
    if clean_title.match?(/^[a-zA-Z]/)
      doc['title_sort'] = clean_title.downcase
    else
      doc['title_sort'] = "zzzz #{clean_title.downcase}"
    end
  end
end
