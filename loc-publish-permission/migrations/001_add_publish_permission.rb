require 'db/migrations/utils'

Sequel.migration do

  up do
    self.transaction do

      # add permission for publishing records
      publish_resource_record = self[:permission].filter(:permission_code => 'publish_resource_record').get(:id)

      if !publish_resource_record
        publish_resource_record = self[:permission].insert(:permission_code => 'publish_resource_record',
                                            :description => 'The ability to publish resource records',
                                            :level => 'repository',
                                            :created_by => 'admin',
                                            :last_modified_by => 'admin',
                                            :create_time => Time.now,
                                            :system_mtime => Time.now,
                                            :user_mtime => Time.now)
      end

      # grant new permission to appropriate groups
      # this won't do anything when intializing a blank db - may need to move this to
      # the plugin-init file if that is an issue.
      if publish_resource_record
        ["repository-managers", "repository-archivists", "repository-project-managers"].each do |grp|
          groups_that_can = self[:group].filter(:group_code => grp).get(:id)
          if groups_that_can
            self[:group_permission].insert(:permission_id => publish_resource_record, :group_id => groups_that_can)
          end
        end
      end

    end
  end


  down do
    # don't even think about it
  end

end
