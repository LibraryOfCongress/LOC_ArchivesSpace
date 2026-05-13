require 'db/migrations/utils'
require 'json'

Sequel.migration do
  up do
    self[:note].where(Sequel.like(:notes, '%accessrestrict%')).each do |note_row|
      note_json = note_row[:notes].to_s.force_encoding('UTF-8')

      begin
        parsed_note = JSON.parse(note_json)

        # Check if it's the right type and needs a label update
        bad_labels = ['Conditions Governing Access', 'Access Conditions']
        
        if parsed_note['type'] == 'accessrestrict' && bad_labels.include?(parsed_note['label'])
          
          parsed_note['label'] = 'Access and Restrictions'

          current_time = Time.now.utc

          self[:note].where(id: note_row[:id]).update(
            notes: parsed_note.to_json,
            system_mtime: current_time,
            user_mtime: current_time
          )

          # ensures the change shows up in the PUI
          # we check which parent the note belongs to and update its timestamp
          if note_row[:digital_object_id]
            self[:digital_object].where(id: note_row[:digital_object_id]).update(
              system_mtime: current_time,
              user_mtime: current_time,
              lock_version: Sequel.expr(:lock_version) + 1
            )
          elsif note_row[:archival_object_id]
            self[:archival_object].where(id: note_row[:archival_object_id]).update(
              system_mtime: current_time,
              user_mtime: current_time,
              lock_version: Sequel.expr(:lock_version) + 1
            )
          elsif note_row[:resource_id]
            self[:resource].where(id: note_row[:resource_id]).update(
              system_mtime: current_time,
              user_mtime: current_time,
              lock_version: Sequel.expr(:lock_version) + 1
            )
          end
        end
      rescue JSON::ParserError
        next
      end
    end
  end
end