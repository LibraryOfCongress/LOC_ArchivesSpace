class LocResourcesExtController < ApplicationController
  include ApplicationHelper

  set_access_control "delete_archival_record" => [:delete_with_digital_objects]

  def delete_with_digital_objects
    begin
      job = Job.new("loc_delete_linked_daos_job", {
                      job_type: "loc_delete_linked_daos_job",
                      jsonmodel_type: "loc_delete_linked_daos_job",
                      resource_id: params[:id]
                    }, {})
      uploaded = job.upload

      redirect_to controller: :jobs, action: :show, id: JSONModel(:job).id_for(uploaded['uri'])

    rescue JSONModel::ValidationException => e
      @exceptions = e.invalid_object._exceptions
      @job = e.invalid_object
      @import_types = import_types
      @report_data = JSONModel::HTTP::get_json("/reports")

      params['job_type'] = @job_type

      render :new, :status => 500

    rescue Exception => e
      Rails.logger.error "An unexpected error occurred while creating a job: #{e.inspect}"
    end
  end
end
