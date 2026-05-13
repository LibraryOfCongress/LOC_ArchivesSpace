require 'db/migrations/utils'
require 'json'

Sequel.migration do
  up do
    self[:note].where(Sequel.~(:archival_object_id => nil)).where(Sequel.like(:notes, '%otherfindaid%')).each do |note_record|
      
      note_json = note_record[:notes].to_s

      begin
        parsed_note = JSON.parse(note_json)

        if parsed_note['jsonmodel_type'] == 'note_multipart' && parsed_note['type'] == 'otherfindaid' && note_record[:publish] == 1
          
          modified = []

          if parsed_note.has_key?('subnotes') && parsed_note['subnotes'].is_a?(Array)
            parsed_note['subnotes'].each do |subnote|
              if subnote.is_a?(Hash) && (subnote['publish'] == false || subnote['publish'].nil?)
                subnote['publish'] = true
                modified << subnote['subnote_guid']
              end
            end
          end

          if modified.size > 0
            self[:note].where(:id => note_record[:id]).update(:notes => JSON.generate(parsed_note))

            modified.each do |guid|
              self[:subnote_metadata].where(:guid => guid).update(:publish => true)
            end

            current_time = Time.now.utc

            self[:archival_object].where(:id => note_record[:archival_object_id]).update(
              :system_mtime => current_time
            )
          end
        end

      rescue JSON::ParserError
        next
      end
    end
  end
end