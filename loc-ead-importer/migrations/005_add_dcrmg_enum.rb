Sequel.migration do
  up do
    $stderr.puts "AS-380: Adding 'dcrmg' to resource_finding_aid_description_rules enum"
    
    enum = self[:enumeration].filter(:name => 'resource_finding_aid_description_rules').first
    if enum
      enum_id = enum[:id]
      
      # Ensure we don't duplicate the value if the migration runs multiple times
      if self[:enumeration_value].filter(:enumeration_id => enum_id, :value => 'dcrmg').empty?
        max_pos = self[:enumeration_value].filter(:enumeration_id => enum_id).max(:position) || 0
        self[:enumeration_value].insert(:enumeration_id => enum_id, 
                                        :value => 'dcrmg', 
                                        :position => max_pos + 1,
                                        :readonly => 0)
      end
    end
  end

  down do
  end
end