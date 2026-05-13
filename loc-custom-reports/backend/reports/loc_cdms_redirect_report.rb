class LocCdmsRedirectReport < AbstractReport

  register_report

  def query
    file_uris = build_file_uri_set
    results = ArchivalObject
                .left_join(:instance, :archival_object_id => :archival_object__id)
                .left_join(:instance_do_link_rlshp, :instance_id => :instance__id)
                .left_join(:digital_object, :id => :instance_do_link_rlshp__digital_object_id)
                .left_join(:file_version, :digital_object_id => :digital_object__id)
                .exclude(digital_object__id: nil)
                .where(file_version__file_uri: file_uris)
                .select(Sequel.as(:archival_object__repo_id, :repo_id),
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

  private

  def build_file_uri_set
    file_uris = []
    ["mss_bak_handles_updated.csv", "gmdkislak_bak_handles.csv", "musapschmidt_bak_handles.csv"].each do |file_uri_csv|
      rows = CSV.parse(File.open(File.join(File.dirname(__FILE__), "lib", file_uri_csv), 'r'))
      rows.each do |row|
        file_uris << row[0].sub(/_bak$/, "").sub("http://", "https://") if row[0] =~ /\Ahttps?:/
      end
    end
    file_uris
  end

end
