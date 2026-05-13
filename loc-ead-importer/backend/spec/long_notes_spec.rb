require 'spec_helper'

describe "Long Notes" do

  it "can store huge subnotes" do
    content = "0" * 65001
    note_size = content.size
    subnote = build(:json_note_text, :content => content)
    ao = ArchivalObject.create_from_json(build(:json_archival_object,
                                               'notes' => [build(:json_note_multipart,
                                                                 'type' => 'scopecontent',
                                                                 :subnotes => [subnote])]))


    expect(ArchivalObject.to_jsonmodel(ao.id)['notes'][0]['subnotes'][0]['content'].size).to eq note_size
  end

end
