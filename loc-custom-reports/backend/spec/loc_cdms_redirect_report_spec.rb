require 'spec_helper'

describe 'LocCdmsDirectReport' do

  it "generate an HTML report that looks about right" do
    resource = create(:json_resource)
    version = build(:json_file_version, file_uri: "https://hdl.loc.gov/loc.gmd/gm020010.gmdkislak.1983_007_00_0002")
    digital_object = create(:json_digital_object,
                            :file_versions => [version])
    archival_object = create(:json_archival_object,
                             title: "Solid standing baby figure",
                             resource: { ref: resource.uri },
                             instances: [
                               build(:json_instance,
                                     instance_type: "digital_object",
                                     digital_object: { ref: digital_object.uri })
                             ])

    params = {
      repo_id: $repo_id,
      format: "html"
    }

    report = DB.open do |db|
      LocCdmsRedirectReport.new(params, nil, db)
    end
    content = report.get_content
    expect(content.size).to eq 1
    expect(content[0][:public_url]).to include(archival_object.uri)
    expect(content[0][:file_uri]).to eq digital_object.file_versions[0]['file_uri']
  end
end
