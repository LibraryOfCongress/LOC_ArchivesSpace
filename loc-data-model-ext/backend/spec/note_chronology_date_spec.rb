require 'spec_helper'

describe 'Chronology Note Modifications' do

  it "replaces event_date with date_from, date_to, and singular_date" do
    note = JSONModel(:note_chronology).from_hash({
                                                   "items" => [{
                                                                 "date_from" => "1900",
                                                                 "date_to" => "2000",
                                                                 "date_singular" => "2000"
                                                               }]
                                                 })
    ao = ArchivalObject.create_from_json(build(
                                           :json_archival_object,
                                           'notes' => [
                                             build(:json_note_multipart, subnotes: [note])
                                           ]))
    ao_json = ArchivalObject.to_jsonmodel(ao)
    subnote = ao_json["notes"][0]["subnotes"][0]
    expect(subnote["items"][0]["date_from"]).to eq "1900"
    expect(subnote["items"][0]["date_to"]).to eq "2000"
    expect(subnote["items"][0]["date_singular"]).to eq "2000"
  end

end
