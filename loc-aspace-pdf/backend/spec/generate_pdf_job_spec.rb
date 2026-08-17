require 'spec_helper'

describe 'Generate PDF Job' do

  let(:admin_user) {
    User.find(:username => "admin")
  }

  it "raises an error if include_unpublished and publish_to_pui are both set" do
    resource = create(:json_resource)
    json = build(:json_job,
                 :job_type => 'print_to_pdf_job',
                 :job => build(:json_print_to_pdf_job,
                               source: resource.uri,
                               include_unpublished: true,
                               publish_to_pui: true
                              ))

    expect {
      Job.create_from_json(json,
                           repo_id: $repo_id,
                           user: admin_user)
    }.to raise_error(JSONModel::ValidationException)
  end
end
