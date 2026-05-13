require 'spec_helper'

describe 'Digital Object Extensions' do

  it "adds digital_object.ead_dao_type" do
    json = build(:json_digital_object, ead_dao_type: "derived")

    digital_object = DigitalObject.create_from_json(json, :repo_id => $repo_id)

    expect(DigitalObject[digital_object[:id]].ead_dao_type).to eq "derived"
  end

  it "throws an error if 'ead_dao_type' is 'otherdaotype' and 'other_ead_dao_type' isn't provided" do
    json = build(:json_digital_object, ead_dao_type: "otherdaotype", other_ead_dao_type: nil)

    expect {
      digital_object = DigitalObject.create_from_json(json, :repo_id => $repo_id)
    }.to raise_error(JSONModel::ValidationException)
  end

end
