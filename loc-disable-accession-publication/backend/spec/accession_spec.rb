require 'spec_helper'

describe 'Accession model' do

  it "disallows accession publication" do
    expect {
      Accession.create_from_json(build(:json_accession,
                                       publish: true),
                                 repo_id: $repo_id)
    }.to raise_error(JSONModel::ValidationException)

    expect {
      Accession.create_from_json(build(:json_accession,
                                       publish: false),
                                 repo_id: $repo_id)
    }.not_to raise_error
  end
end
