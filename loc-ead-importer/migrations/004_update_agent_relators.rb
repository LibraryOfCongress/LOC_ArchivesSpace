require 'sequel'

Sequel.migration do
  def up
    # find the enumeration record 
    enum_record = self[:enumeration].filter(:name => 'agent_relator').first
    
    # Check if the enumeration exists before proceeding
    if enum_record.nil?
      puts "WARN: Enumeration 'agent_relator' not found. Skipping migration."
      return 
    end

    enum_id = enum_record[:id]

    # Define the outdated values to remove
    values_to_remove = [
      'Architect:', 'Creators', 'Creator(s)', 'Creator:',
      'Creators:', 'Related Name:', 'Related Names:'
    ]

    # Delete the old values
    puts "Removing #{values_to_remove.length} old agent relator values..."
    self[:enumeration_value].filter(enumeration_id: enum_id, value: values_to_remove).delete

    # Add the new 'Announcer' value, if it doesn't already exist
    existing_announcer = self[:enumeration_value].filter(enumeration_id: enum_id, value: 'Announcer').first
    unless existing_announcer
      last_position = self[:enumeration_value].filter(enumeration_id: enum_id).max(:position) || 0
      
      puts "Adding 'Announcer' as a new agent relator value."
      self[:enumeration_value].insert(
        :enumeration_id => enum_id,
        :value => 'Announcer',
        :position => last_position + 1,
        :readonly => 0,
        :create_time => Time.now,
        :system_mtime => Time.now,
        :user_mtime => Time.now
      )
    else
      puts "'Announcer' already exists. No action taken."
    end
  end

  def down
    # Find the enumeration record 
    enum_record = self[:enumeration].filter(:name => 'agent_relator').first
    
    if enum_record.nil?
      puts "WARN: Enumeration 'agent_relator' not found. Skipping migration."
      return
    end

    enum_id = enum_record[:id]

    # Remove the 'Announcer' value
    puts "Removing 'Announcer' agent relator value..."
    self[:enumeration_value].filter(enumeration_id: enum_id, value: 'Announcer').delete

    # Re-create the old values 
    values_to_recreate = [
      'Architect:', 'Creators', 'Creator(s)', 'Creator:',
      'Creators:', 'Related Name:', 'Related Names:'
    ]

    last_position = self[:enumeration_value].filter(enumeration_id: enum_id).max(:position) || 0
    
    puts "Re-creating #{values_to_recreate.length} old agent relator values..."
    values_to_recreate.each_with_index do |value, index|
      self[:enumeration_value].insert(
        :enumeration_id => enum_id,
        :value => value,
        :position => last_position + 1 + index,
        :readonly => 0,
        :create_time => Time.now,
        :system_mtime => Time.now,
        :user_mtime => Time.now
      )
    end
  end
end