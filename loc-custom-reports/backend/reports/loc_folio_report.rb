class LocFolioReport < AbstractReport

  register_report

  def query
    results = db.fetch(query_string)
    info[:total_count] = results.count
    results
  end

  def query_string
    "select
      ead_id,
      lccn,
      restrictions,
      spatial_restrictions,
      repo_code

    from resource inner join repository on repo_id = repository.id"
  end

  def fix_row(row)
    ReportUtils.fix_boolean_fields(row, [:restrictions, :spatial_restrictions])
  end

  def identifier_field
    :identifier
  end

end
