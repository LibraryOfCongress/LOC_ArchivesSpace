require 'spec_helper'

describe 'SpreadsheetBuilder' do

  it "can take new note fields 'didnote' and 'otherfindaid'" do
    resource = create(:json_resource)
    top = create(:json_top_container)

    opts = {notes: [
              build(:json_note_singlepart, type: "didnote", content: ['didnote content']),
              build(:json_note_multipart, type: "otherfindaid", subnotes: [build(:json_note_text, content: 'otherfindaid content')]),
            ],
            resource: { ref: resource.uri }}

    ao = create(:json_archival_object, opts)

    builder = SpreadsheetBuilder.new(resource.uri,
                                     [ao.uri],
                                     1,
                                     0,
                                     1,
                                     [
                                       'note_didnote', 'note_otherfindaid'
                                     ])

    builder.dataset_iterator do |current_row, locked_column_indexes|
      notes = current_row.select {|r| r.column.property_name == "note" }
      expect([notes[0].value, notes[2].value].sort).to eq ["didnote content", "otherfindaid content"].sort
    end
  end
end
