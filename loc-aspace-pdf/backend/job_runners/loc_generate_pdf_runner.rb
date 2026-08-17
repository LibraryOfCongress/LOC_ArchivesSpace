require_relative '../model/finding_aid_pdf'

class LocGeneratePdfRunner < JobRunner
  include JSONModel

  unless AppConfig.has_key?(:staff_use_core_pdf_pipeline) && AppConfig[:staff_use_core_pdf_pipeline]
    register_for_job_type('print_to_pdf_job', allow_reregister: true)
  end

  def run
    ticker = Ticker.new(@job)
    begin
      RequestContext.open( :repo_id => @job.repo_id) do
        resource_id = if @job.job.has_key?('source')
                        parsed = JSONModel.parse_reference(@json.job["source"])
                        parsed[:id]
                      end
        resource = Resource.get_or_die(resource_id)
        resource_jsonmodel = Resource.to_jsonmodel(resource)
        ead_id = resource_jsonmodel['ead_id']
        sub_dir = ead_id[0..1]
        raise "Error parsing ead_id and subdirectory for #{resource_id}" unless \
          sub_dir =~ /[a-z]{2}/
        @job.write_output("Generating PDF for #{resource_jsonmodel["title"]}  ")
        @job.write_output("**LOC PDF pipeline has replaced the core PDF pipeline**")
        include_unpublished = @job.job['include_unpublished'] || false
        pdf = FindingAidPDF.new(@job.repo_id, resource_id, include_unpublished: include_unpublished)
        pdf_file = pdf.generate(ticker)
        @job.add_file(pdf_file)
        if @job.job['publish_to_pui']
          @job.job_files.each do |jf|
            target_path = "#{LOC_PDF_PUBLISHED_DIR}/#{sub_dir}/#{ead_id}.pdf"
            @job.write_output("Copying #{jf.full_file_path} to #{target_path}")
            FileUtils.mkdir_p("#{LOC_PDF_PUBLISHED_DIR}/#{sub_dir}", mode: 0775)
            FileUtils.cp(jf.full_file_path, target_path)
            FileUtils.chmod(0664, target_path)
          end
        end
        if AppConfig.has_key?(:debug_pdf_generation) && AppConfig[:debug_pdf_generation]
          ticker.log("generating source html for debugging")
          source_html = pdf.source_file(ticker)
          @job.add_file(source_html)
        end
        @job.write_output("Done generating PDF for #{resource_jsonmodel["title"]}  ")
      end
    rescue Exception => e
      ticker.log("PDF Generation failed:\n #{e.inspect}")
      raise e
    end
  end
end
