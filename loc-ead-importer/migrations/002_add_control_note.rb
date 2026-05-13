Sequel.migration do
  up do
    # Find the enumeration record for note_multipart_type
    enum_record = self[:enumeration].filter(:name => 'note_multipart_type').first

    if enum_record
      # Check if "Control Note" already exists to avoid duplicates
      existing = self[:enumeration_value].filter(
        :enumeration_id => enum_record[:id],
        :value => 'Control Note'
      ).first

      unless existing
        pos = self[:enumeration_value].filter(enumeration_id: enum_record[:id]).max(:position) + 1
        self[:enumeration_value].insert(
          :enumeration_id => enum_record[:id],
          :value => 'Control Note',
          :readonly => 0,
          :position => pos,
          :create_time => DateTime.now,
          :system_mtime => DateTime.now,
          :user_mtime => DateTime.now
        )
        puts "Added 'Control Note' to note_multipart_type enumeration."
      end
    else
      puts "Enumeration 'note_multipart_type' not found."
    end
  end

  down do
    enum_record = self[:enumeration].filter(:name => 'note_multipart_type').first
    if enum_record
      self[:enumeration_value].filter(
        :enumeration_id => enum_record[:id],
        :value => 'Control Note'
      ).delete
      puts "Removed 'Control Note' from note_multipart_type enumeration."
    end
  end
end
