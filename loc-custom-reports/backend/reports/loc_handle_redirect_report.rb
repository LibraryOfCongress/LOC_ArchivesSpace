class LocHandleRedirectReport < AbstractReport
  register_report

  def query
    results = db.fetch(query_string)
    info[:total_count] = results.count
    results
  end

  def query_string
    "SELECT 
      ead_location, 
      repo_id, 
      id AS resource_id 
    FROM resource 
    WHERE ead_location IS NOT NULL AND publish = 1"
  end

  def fix_row(row)
    base_url = AppConfig[:public_proxy_url].to_s.chomp('/')
    
    row[:pui_url] = "#{base_url}/repositories/#{row[:repo_id]}/resources/#{row[:resource_id]}"

    row.delete(:repo_id)
    row.delete(:resource_id)
  end

  def identifier_field
    :ead_location
  end
end