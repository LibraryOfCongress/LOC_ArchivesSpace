require 'sequel'

Sequel.migration do
  up do
    # Find the ID for the 'note_digital_object_type' enumeration
    enum_id = self[:enumeration].filter(:name => 'note_digital_object_type').get(:id)

    if enum_id
      # Get the maximum position value to ensure the new value is added at the end
      max_pos = self[:enumeration_value].filter(:enumeration_id => enum_id).max(:position)
      new_pos = (max_pos || 0) + 1

      new_row_id = self[:enumeration_value].insert_ignore.insert(
        :enumeration_id => enum_id,
        :value => 'descriptivenote',
        :position => new_pos,
        :readonly => 0, 
        :suppressed => 0
      )

      if new_row_id
        puts "Added 'descriptivenote' to note_digital_object_type enumeration."
      else
        puts "'descriptivenote' already exists in note_digital_object_type enumeration. No action taken."
      end
    else
      puts "Enumeration 'note_digital_object_type' not found."
    end
  end

  down do
    enum_id = self[:enumeration].filter(:name => 'note_digital_object_type').get(:id)
    if enum_id
      if self[:enumeration_value].filter(:enumeration_id => enum_id, :value => 'descriptivenote').delete > 0
        puts "Removed 'descriptivenote' from note_digital_object_type enumeration."
      end
    end
  end
end