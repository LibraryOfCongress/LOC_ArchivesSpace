require 'spec_helper'


FactoryBot.define do
  factory :json_loc_import_folio_restrictions_job, class: JSONModel(:loc_import_folio_restrictions_job)
end

describe 'LOC Import Folio Restrictions' do

  let(:admin_user) {
    User.find(:username => "admin")
  }

  let(:resource1) do
    create(:json_resource, lccn: "123")
  end

  let(:resource2) do
    create(:json_resource, lccn: "abc")
  end


  let(:job) do
    tmp = ASUtils.tempfile("doc-#{Time.now.to_i}")
    tmp.write("lccn,restricted/not restricted,onsite/offsite,restrictions,locations\n")
    tmp.write("\"#{resource1.lccn}\",\"Not restricted\",\"does not matter\",\"0\",\"afc onsite\"\n")
    tmp.write("\"#{resource2.lccn}\",\"Restricted\",\"does not matter\",\"1\",\"afc onsite|afc fort meade\"\n")
    tmp.rewind
    json = build(:json_job,
                 :job_type => 'loc_import_folio_restrictions_job',
                 :job => build(:json_loc_import_folio_restrictions_job))
    job = Job.create_from_json(json,
                               :repo_id => $repo_id,
                               :user => admin_user)
    job.add_file(tmp)

    job
  end

  let(:bad_job) do
    tmp = ASUtils.tempfile("doc-#{Time.now.to_i}")
    tmp.write("lccn,restricted/not restricted,onsite/offsite,oops,locations\n")
    tmp.write("\"#{resource1.lccn}\",\"Not restricted\",\"does not matter\",\"0\",\"afc onsite\"\n")
    tmp.write("\"#{resource2.lccn}\",\"Restricted\",\"does not matter\",\"1\",\"afc onsite|afc fort meade\"\n")
    tmp.rewind
    json = build(:json_job,
                 :job_type => 'loc_import_folio_restrictions_job',
                 :job => build(:json_loc_import_folio_restrictions_job))
    job = Job.create_from_json(json,
                               :repo_id => $repo_id,
                               :user => admin_user)
    job.add_file(tmp)
    job
  end

  it "updates restrictions and spatial restrictions" do
    job_runner = JobRunner.for(job)
    job_runner.run
    obj1 = JSONModel(:resource).find(resource1.id)
    expect(obj1.restrictions).to be_falsey
    expect(obj1.spatial_restrictions).to be_falsey
    obj2 = JSONModel(:resource).find(resource2.id)
    expect(obj2.restrictions).to be_truthy
    expect(obj2.spatial_restrictions).to be_truthy
  end

  it "errors if the CSV headers are incorrect" do
    job_runner = JobRunner.for(bad_job)
    expect {
      job_runner.run
    }.to raise_error
  end
end
