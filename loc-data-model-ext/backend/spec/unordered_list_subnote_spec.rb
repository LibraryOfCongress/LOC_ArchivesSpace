require 'spec_helper'

describe 'Chronology Note Modifications' do

  it "replaces event_date with date_from, date_to, and singular_date" do
    note = JSONModel(:note_unorderedlist).from_hash({
                                                   "items" => ["apple", "orange", "banana"]
                                                 })
    ao = ArchivalObject.create_from_json(build(
                                           :json_archival_object,
                                           'notes' => [
                                             build(:json_note_multipart, subnotes: [note])
                                           ]))
    ao_json = ArchivalObject.to_jsonmodel(ao)
    subnote = ao_json["notes"][0]["subnotes"][0]
    expect(subnote["items"][0]).to eq "apple"
    expect(subnote["items"][1]).to eq "orange"
    expect(subnote["items"][2]).to eq "banana"
  end

end
