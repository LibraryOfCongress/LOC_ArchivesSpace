require 'spec_helper'
require_relative '../model/finding_aid_pdf'

describe 'PDF Record Model' do

  let(:resource) {
    create(:json_resource,
           publish: true,
           ead_location: "https://handle.net/1234")
  }

  it "exposes the handle for the a resource" do

    pdf = FindingAidPDF.new($repo_id, resource.id)
    record = pdf.instance_variable_get(:@resource)
    expect(record.ead_location).to eq resource.ead_location
  end

  it "exposes the level for the an archival object" do
    ao = create(:json_archival_object,
                resource: {ref: resource.uri},
                publish: true,
                level: "series")


    pdf = FindingAidPDF.new($repo_id, resource.id)
    pdf.each_ao do |record, depth, is_parent|
      expect(record.level).to eq("series")
    end
  end


end
