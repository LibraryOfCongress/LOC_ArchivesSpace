require_relative '../model/finding_aid_pdf'

class LocGeneratePdfRunner < JobRunner
  include JSONModel

  unless AppConfig.has_key?(:staff_use_core_pdf_pipeline) && AppConfig[:staff_use_core_pdf_pipeline]
    register_for_job_type('print_to_pdf_job', allow_reregister: true)
  end

  def run
    ticker = Ticker.new(@job)
    RequestContext.open( :repo_id => @job.repo_id) do
      resource_id = if @job.job.has_key?('source')
                      parsed = JSONModel.parse_reference(@json.job["source"])
                      parsed[:id]
                    elsif @job.job.has_key?('resource_id')
                      @job.job['resource_id']
                    end
      resource = Resource.get_or_die(resource_id)
      resource_jsonmodel = Resource.to_jsonmodel(resource)
      @job.write_output("Generating PDF for #{resource_jsonmodel["title"]}  ")
      @job.write_output("**LOC PDF pipeline has replaced the core PDF pipeline**")

      pdf = FindingAidPDF.new(@job.repo_id, resource_id)
      pdf_file = pdf.generate(ticker)
      @job.add_file(pdf_file)
      begin
        if AppConfig[:debug_pdf_generation]
          ticker.log("generating source html for debugging")
          source_html = pdf.source_file(ticker)
          @job.add_file(source_html)
        end
      rescue
      end
      @job.write_output("Done generating PDF for #{resource_jsonmodel["title"]}  ")
    end
  end

end
