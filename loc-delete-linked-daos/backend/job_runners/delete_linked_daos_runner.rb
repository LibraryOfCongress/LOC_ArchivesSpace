class LocDeleteLinkedDaosRunner < JobRunner

  register_for_job_type('loc_delete_linked_daos_job', :create_permissions => :delete_archival_record,
                        :cancel_permissions => :cancel_job)

  def run
    ticker = Ticker.new(@job)
    last_error = nil
    begin
      DB.open do
        RequestContext.open(repo_id: @job.repo_id, current_username: @job.owner.username) do
          begin
            resource_id = @job.job['resource_id'].to_i
            ticker.log("Deleting Resource #{resource_id} and all associated digital objects")
            resource = Resource.get_or_die(resource_id)
            resource.delete_with_digital_objects
            success = true
            ticker.log("Success")
          rescue LocDigitalObjectDeleter::OtherDigitalObjectReferencesError => e
            last_error = e
            ticker.log("Error: #{e.inspect}")
            raise Sequel::Rollback, last_error
          end
        end
      end
      self.success!
    rescue Exception => e
      if last_error.is_a? LocDigitalObjectDeleter::OtherDigitalObjectReferencesError
        ticker.log("This action cannot be completed because one or more digital objects are also referenced from another Resource tree.")
      elsif last_error
        ticker.log("Job failed: #{last_error.inspect}")
      else
        ticker.log("Job failed: #{e.inspect}")
      end
      raise e
    end
  end
end
