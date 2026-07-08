class LocExtentTypeReport < AbstractReport
  register_report

  def query
    extents = db.fetch(query_string)
    results = {}
    extents.each do |e|
      fks = [:resource_id, :archival_object_id, :digital_object_id, :digital_object_component_id, :accession_id].map {|fk| e[fk] }
      next if fks.compact.empty?
      results.has_key?(e[:value]) ? results[e[:value]] +=1 : results[e[:value]] = 1
    end
    results = results.map { |k,v| {extent_type: k, translation: I18n.t("enumerations.extent_extent_type.#{k}", default: k), count: v} }
    info[:total_count] = results.count
    results
  end

  def query_string
    "SELECT
    extent_type_id, enumeration_value.value,
    resource.id as resource_id,
    archival_object.id as archival_object_id,
    digital_object.id as digital_object_id,
    digital_object_component.id as digital_object_component_id,
    accession.id as accession_id
    from extent
    left join enumeration_value
         on extent_type_id = enumeration_value.id
    left join resource
         on extent.resource_id = resource.id
         and resource.repo_id = #{repo_id}
    left join archival_object
         on extent.archival_object_id = archival_object.id
         and archival_object.repo_id = #{repo_id}
    left join digital_object
         on extent.digital_object_id = digital_object.id
         and digital_object.repo_id = #{repo_id}
    left join digital_object_component
         on extent.digital_object_component_id = digital_object_component.id
         and digital_object_component.repo_id = #{repo_id}
    left join accession
         on extent.accession_id = accession.id
         and accession.repo_id = #{repo_id}"
  end
end
