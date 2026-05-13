module JobsHelper

  alias_method :file_label_og, :file_label

  def file_label(job_type)
    if job_type == "loc_ead_migrator_job"
      return "Download CSV Migration Report"
    elsif job_type == "loc_duplicate_file_report_job"
      return "Download CSV Duplicate EAD Report"
    elsif job_type == "loc_import_folio_restrictions_job"
      return "Download CSV Import Folio Restrictions Report"
    else
      return file_label_og(job_type)
    end
  end

end
