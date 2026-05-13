require 'spec_helper'


FactoryBot.define do
  factory :json_loc_ead_migrator_job, class: JSONModel(:loc_ead_migrator_job)
end

describe 'LOC EAD Migrator' do

  let(:eur_repo) {
    eur_repo = create(:json_repository, {:repo_code => "eur"})
  }

  let(:admin_user) {
    User.find(:username => "admin")
  }

  before(:each) do

    ead_dir = File.expand_path("./fixtures", File.dirname(__FILE__))

    allow(AppConfig).to receive(:[]).and_call_original
    allow(AppConfig).to receive(:[]).with(:loc_ead_migrator_ead_dirs).and_return([ead_dir])


    json = build(:json_job,
                 :job_type => 'loc_ead_migrator_job',
                 :job => build(:json_loc_ead_migrator_job, repository: "eur"))

    eur_repo
#    as_test_user("admin") do
    @job = Job.create_from_json(json,
                               :repo_id => eur_repo.id,
                               :user => admin_user)


  end

  it "can be run and record the aggregate results in a CSV report" do
    job_runner = JobRunner.for(@job)
    job_runner.run
    report = CSV.parse(
      File.read(
        File.absolute_path(@job.job_files.first.file_path, dir_string = AppConfig[:job_file_path])
      )
    )
    failures = report.select { |row| row[1] =~ /_bad/ }
    successes = report.select { |row| row[1] =~ /_good/ }
    repo_ids = successes.map { |row| JSONModel(:repository).id_for(
                             row[4].sub(/\/resources.*/, "")
                               ) }

    expect(repo_ids).to include eur_repo.id
    expect(successes.size).to be 1
    expect(failures.size).to be 1

    failures.each do |row|
      expect(row[3]).to eq "FAILED"
      expect(row[4]).to match /Property is required but was missing/
    end
    successes.each do |row|
      expect(row[3]).to match /converter:/
      expect(row[4]).to match /^\/repositories\/[\d]+\/resources\/[\d]+$/
      expect(@job.created_records.map { |job| job.record_uri }).to include(row[4])
    end

  end

end
