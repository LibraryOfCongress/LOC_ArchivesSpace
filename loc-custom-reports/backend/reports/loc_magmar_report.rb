class LocMagmarReport < AbstractReport

  register_report

  def query
    results = ArchivalObject
                .left_join(:instance, :archival_object_id => :archival_object__id)
                .left_join(:instance_do_link_rlshp, :instance_id => :instance__id)
                .left_join(:digital_object, :id => :instance_do_link_rlshp__digital_object_id)
                .left_join(:file_version, :digital_object_id => :digital_object__id)
                .exclude(archival_object__loc_magmar_id: nil)
                .exclude(digital_object__id: nil)
                .select(Sequel.as(:archival_object__loc_magmar_id, :loc_magmar_id),
                        Sequel.as(:archival_object__repo_id, :repo_id),
                        Sequel.as(:archival_object__id, :archival_object_id),
                        Sequel.as(:file_version__file_uri, :file_uri))

    info[:total_count] = results.count
    results
  end

  def fix_row(row)
    archival_object_uri = "/repositories/#{row[:repo_id]}/archival_objects/#{row[:archival_object_id]}"
    row[:public_url] = AppConfig[:public_proxy_url] + archival_object_uri
    row.delete(:repo_id)
    row.delete(:archival_object_id)
  end

  def identifier_field
    :identifier
  end

end
