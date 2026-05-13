require 'spec_helper'

describe 'LocFolioReport' do

  it "generate an HTML report that looks about right" do
    resource = create(:json_resource,
                      ead_id: "EADID",
                      lccn: "LCCN",
                      restrictions: true,
                      spatial_restrictions: false
                     )
    params = {
      repo_id: $repo_id,
      format: "html"
    }

    report = DB.open do |db|
      LocFolioReport.new(params, nil, db)
    end
    content = report.get_content
    expect(content[0][:ead_id]).to eq "EADID"
    expect(content[0][:lccn]).to eq "LCCN"
    expect(content[0][:restrictions]).to eq "Yes"
    expect(content[0][:spatial_restrictions]).to eq "No"
    repo_id = JSONModel(:repository).id_for(resource.repository['ref'])
    repo_code = Repository[repo_id].repo_code
    expect(content[0][:repo_code]).to eq repo_code
  end
end
