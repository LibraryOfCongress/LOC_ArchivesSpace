require 'db/migrations/utils'

Sequel.migration do

  up do
    enum_id = self[:enumeration].filter(:name => 'note_singlepart_type').select(:id)
    didnote = self[:enumeration_value].filter(:value => 'didnote', :enumeration_id => enum_id ).select(:id).all
    if didnote.length == 0
      position = self[:enumeration_value].filter(
        enumeration_id: enum_id
      ).max(:position) + 1
      self[:enumeration_value].insert(:enumeration_id => enum_id, :value => "didnote", :position => position)
    end
  end

end
