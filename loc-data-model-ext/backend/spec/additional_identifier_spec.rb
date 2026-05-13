require 'spec_helper'

describe 'Additional Identifier field' do

  it "allows archival objects to have 1 or more additional identifiers" do
    opts = {:additional_identifiers => ["123", "abc"]}

    json = build(:json_archival_object, opts)

    archival_object = ArchivalObject.create_from_json(json, repo_id: $repo_id)
    archival_object = ArchivalObject[archival_object[:id]]
    json = ArchivalObject.to_jsonmodel(archival_object)
    expect(json.additional_identifiers).to eq ["123", "abc"]
    json.additional_identifiers << "789"
    archival_object.update_from_json(json)
    archival_object = ArchivalObject[archival_object[:id]]
    expect(JSON.parse(archival_object.additional_identifiers)).to include("789")
  end

end
