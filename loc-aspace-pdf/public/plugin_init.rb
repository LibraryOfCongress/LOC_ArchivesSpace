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
        url = "#{resource.json['ead_location']}.3"

        redirect_to url
      end
    end
  end
end
