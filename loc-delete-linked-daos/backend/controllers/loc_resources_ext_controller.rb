class ArchivesSpaceService < Sinatra::Base

  Endpoint.delete('/repositories/:repo_id/resources_and_digital_objects/:id')
  .description("Delete a Resource and all associated Digital Objects")
  .params(["id", :id],
          ["repo_id", :repo_id])
  .use_transaction(false)
  .permissions([:delete_archival_record])
  .no_data(true)
  .returns([200, :deleted],
           [400, :error]) \
  do
    last_error = nil
    success = false
    begin
      DB.open(true, retries: 1) do
        begin
          resource = Resource.get_or_die(params[:id])
          resource.delete_with_digital_objects
          success = true
        rescue LocDigitalObjectDeleter::OtherDigitalObjectReferencesError => e
          last_error = e
          raise Sequel::Rollback, last_error
        end
      end
    rescue
      last_error = $!
    end

    if success
      deleted_response(params[:id])
    elsif last_error.is_a? LocDigitalObjectDeleter::OtherDigitalObjectReferencesError
      json_response({error: "This action cannot be completed because one or more digital objects are also referenced from another Resource tree."}, 400)
    else
      json_response({error: last_error.inspect}, 400)
    end
  end
end
