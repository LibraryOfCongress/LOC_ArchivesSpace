Sequel.migration do
  up do
    old_perm_id = self[:permission].filter(:permission_code => 'delete_archival_record').get(:id)

    if old_perm_id
      $stderr.puts("AS-526: Migrating legacy delete_archival_record permissions...")

      # Ensure delete_resource_record exists in DB before group mapping
      res_perm_id = self[:permission].filter(:permission_code => 'delete_resource_record').get(:id)
      if res_perm_id.nil?
        res_perm_id = self[:permission].insert(
          :permission_code => 'delete_resource_record',
          :description => 'The ability to delete Resource records',
          :level => 'repository',
          :created_by => 'admin',
          :last_modified_by => 'admin',
          :create_time => Time.now,
          :system_mtime => Time.now,
          :user_mtime => Time.now
        )
      end

      # Ensure delete_accession_record exists in DB before group mapping
      acc_perm_id = self[:permission].filter(:permission_code => 'delete_accession_record').get(:id)
      if acc_perm_id.nil?
        acc_perm_id = self[:permission].insert(
          :permission_code => 'delete_accession_record',
          :description => 'The ability to delete Accession records',
          :level => 'repository',
          :created_by => 'admin',
          :last_modified_by => 'admin',
          :create_time => Time.now,
          :system_mtime => Time.now,
          :user_mtime => Time.now
        )
      end

      # Find groups with the old permission and grant the two new ones
      group_ids = self[:group_permission].filter(:permission_id => old_perm_id).select(:group_id).map {|row| row[:group_id]}.uniq
      
      group_ids.each do |group_id|
        if self[:group_permission].filter(:permission_id => res_perm_id, :group_id => group_id).empty?
          self[:group_permission].insert(:permission_id => res_perm_id, :group_id => group_id)
        end
        if self[:group_permission].filter(:permission_id => acc_perm_id, :group_id => group_id).empty?
          self[:group_permission].insert(:permission_id => acc_perm_id, :group_id => group_id)
        end
      end
    end
  end

  down do
  end
end