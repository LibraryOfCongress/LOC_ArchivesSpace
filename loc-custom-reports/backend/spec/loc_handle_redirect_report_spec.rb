require 'spec_helper'

describe 'LocHandleRedirectReport' do

  it "generates a CSV report with PUI URLs for published resources with handles" do
    
    good_resource = create(:json_resource, 
                           :ead_location => "http://hdl.loc.gov/loc.mss/eadmss.ms001",
                           :publish => true)

    no_handle_resource = create(:json_resource, 
                                :ead_location => nil, 
                                :publish => true)

    unpublished_resource = create(:json_resource, 
                                  :ead_location => "http://hdl.loc.gov/loc.mss/eadmss.ms002",
                                  :publish => false)

    params = {
      repo_id: $repo_id,
      format: "csv"
    }

    report = DB.open do |db|
      LocHandleRedirectReport.new(params, nil, db)
    end
    
    content = report.get_content

    target_row = content.find { |row| row[:ead_location] == good_resource.ead_location }

    expect(target_row).not_to be_nil

    unpublished_check = content.find { |row| row[:ead_location] == unpublished_resource.ead_location }
    expect(unpublished_check).to be_nil

    expected_path = "/repositories/#{$repo_id}/resources/#{good_resource.id}"
    expect(target_row[:pui_url]).to include(expected_path)
  end
end