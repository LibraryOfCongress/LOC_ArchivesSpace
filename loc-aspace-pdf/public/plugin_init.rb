require_relative '../find_public_pdf_dir'

LOC_PDF_PUBLISHED_DIR = LocPDFDirectoryFinder.loc_pdf_published_dir

ArchivesSpacePublic::Application.config.after_initialize do

  unless AppConfig.has_key?(:pui_use_core_pdf_pipeline) && AppConfig[:pui_use_core_pdf_pipeline]
    class PdfController
      def resource
        repo_id = params[:rid]
        resource_id = if request.referrer&.include?('archival_objects')
                        ao = archivesspace.get_record("/repositories/#{params[:rid]}/archival_objects/#{params[:id]}")
                        # Get resource ID from the archival object's json
                        ao.json['resource']['ref']&.split('/')&.last
                      else
                        params[:id]
                      end

        raise RecordNotFound.new("No resource ID found") unless resource_id

        resource = archivesspace.get_record("/repositories/#{repo_id}/resources/#{resource_id}",
                                            { 'resolve[]' => ['repository:id'] })
        ead_id = resource.json['ead_id']
        sub_dir = ead_id[0..1]
        raise "Error parsing ead_id and subdirectory for #{resource_id}" unless \
          sub_dir =~ /[a-z]{2}/
        pdf_url = "#{AppConfig[:public_proxy_url]}/documents/#{sub_dir}/#{ead_id}.pdf"
        # first, see if we can find a generated pdf
        redirect_to pdf_url
      end
    end
  end
end
