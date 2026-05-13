require 'spec_helper'

describe 'LocMagmarReport' do

  it "generate an HTML report that looks about right" do
    resource = create(:json_resource)
    do1 = create(:json_digital_object,
                 file_versions: [
                   build(:json_file_version),
                   build(:json_file_version)
                 ])
    do2 = create(:json_digital_object,
                 file_versions: [
                   build(:json_file_version)
                 ])
    ao1 = create(:json_archival_object,
                 resource: { ref: resource.uri },
                 instances: [
                   build(:json_instance,
                         instance_type: "digital_object",
                         digital_object: { ref: do1.uri })
                 ],
                 loc_magmar_id: "MAGMAR1")
    ao2 = create(:json_archival_object,
                 resource: { ref: resource.uri },
                 instances: [
                   build(:json_instance,
                         instance_type: "digital_object",
                         digital_object: { ref: do1.uri }),
                   build(:json_instance,
                         instance_type: "digital_object",
                         digital_object: { ref: do2.uri })
                 ],
                 loc_magmar_id: "MAGMAR2")
    ao3 = create(:json_archival_object)

    params = {
      repo_id: $repo_id,
      format: "html"
    }

    report = DB.open do |db|
      LocMagmarReport.new(params, nil, db)
    end
    content = report.get_content
    expect(content.size).to eq 5
    expect(content[0][:public_url]).to include(ao1.uri)
    expect(content[0][:file_uri]).to eq do1.file_versions[0]['file_uri']
    expect(content[0][:loc_magmar_id]).to eq ao1.loc_magmar_id
  end
end
