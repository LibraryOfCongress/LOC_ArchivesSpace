class LocDeleteDigitalObjectsRunner < JobRunner

  register_for_job_type('loc_delete_digital_objects_job', :create_permissions => :manage_repository,
                        :cancel_permissions => :cancel_importer_job)

  def run
    ticker = Ticker.new(@job)
    last_error = nil
    begin
      DB.open do
        RequestContext.open(repo_id: @job.repo_id, current_username: @job.owner.username) do
          DigitalObject.filter(repo_id: @job.repo_id).each do |obj|
            unless obj.object_graph.models.include?(Relationships::DigitalObjectInstanceDoLink)
              ticker.log("Deleting Digital Object #{obj.id}: #{obj.title}")
              obj.delete
            end
          end
        end
      end
      self.success!
    rescue Exception => e
      ticker.log("Job failed: #{e.inspect}")
      raise e
    end
  end
end
