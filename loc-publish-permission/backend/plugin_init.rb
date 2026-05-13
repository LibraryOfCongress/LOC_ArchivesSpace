require_relative 'mixins/resource_publish_permission.rb'

module RESTHelpers
  class Endpoint
    def self.find_by_uri(uri, methods=[:get])
      @@endpoints.find { |e|
        e.instance_eval do
          @methods == methods && @uri == uri
        end
      }
    end
  end
end

[
  "/repositories/:repo_id/resources/:id/publish",
  "/repositories/:repo_id/resources/:id/unpublish",
  "/repositories/:repo_id/archival_objects/:id/publish",
  "/repositories/:repo_id/archival_objects/:id/unpublish",
].each do |uri|
  ep = RESTHelpers::Endpoint.find_by_uri(uri, [:post])
  ep.permissions([:publish_resource_record])
end


class Resource
  include ResourcePublishPermission
end

class ArchivalObject
  include ResourcePublishPermission
end


class ArchivesSpaceService

  # In order to get the frontend to surface errors on the form, we have to
  # send back a 4xx response with a body that can be parsed into a hash with
  # key :error and a value that is another hash of keys and lists of error messages.
  # If it isn't formatted this way, the form will just display an internal
  # server error message. See JSONModel::Client.save, where this response is handled.
  error ResourcePublishPermission::PermissionException do
    json_response({ error: { publish: ["publish_resource_permission"] } }, 400)
  end
end

# Admin users automatically get everything
admins = Group.any_repo[ group_code: Group.ADMIN_GROUP_CODE ]
admins.grant("publish_resource_record")
