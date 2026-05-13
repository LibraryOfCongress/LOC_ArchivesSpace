require 'spec_helper'


FactoryBot.define do
  factory :json_loc_delete_digital_objects_job, class: JSONModel(:loc_delete_digital_objects_job)
end

describe 'LOC Delete Digital Objects' do

  let(:admin_user) {
    User.find(:username => "admin")
  }

  let(:digital_objects) do
    10.times.collect { create(:json_digital_object) }
  end

  let(:resource) do
    create(:json_resource,
           instances: [build(:json_instance_digital,
                            :instance_type => 'digital_object',
                            :digital_object => {:ref => digital_objects.first.uri})])
  end

  let(:job) do
    json = build(:json_job,
                 :job_type => 'loc_delete_digital_objects_job',
                 :job => build(:json_loc_delete_digital_objects_job))
    job = Job.create_from_json(json,
                               :repo_id => $repo_id,
                               :user => admin_user)
    job
  end

  it "deletes any unlinked digital objects" do
    resource
    job_runner = JobRunner.for(job)
    job_runner.run
    expect(digital_objects.map {|obj| DigitalObject[obj.id] }.compact.size).to eq 1
  end

end
