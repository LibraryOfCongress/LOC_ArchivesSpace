require 'spec_helper'

describe "managed authorities api" do

  it "allows subjects to be created and attached to a resource" do
    resource = create(:json_resource)
    subjects = [
      build(:json_subject),
      build(:json_subject)
    ]

    request = JSONModel(:managed_authorities_request).from_hash(
      {
        resource: { ref: resource.uri },
        subjects: subjects
      }
    )
    url = URI("#{JSONModel::HTTP.backend_url}/managed_authorities")
    req = Net::HTTP::Post.new(url.request_uri)
    req['Content-Type'] = 'text/json'
    req.body = request.to_json

    response = JSONModel::HTTP.do_http_request(url, req)

    expect(response.code).to eq("200")
    resource = JSONModel(:resource).find_by_uri(resource.uri)
    expect(resource.subjects.size).to eq(subjects.size)
  end

  it "overwrites any existing subject relationships" do
    subjects = [
      create(:json_subject),
      create(:json_subject)
    ]
    resource = create(:json_resource, subjects: [{ref: subjects[0].uri}, {ref: subjects[1].uri}])

    new_subject = build(:json_subject)
    request = JSONModel(:managed_authorities_request).from_hash(
      {
        resource: { ref: resource.uri },
        subjects: [ new_subject ]
      }
    )
    url = URI("#{JSONModel::HTTP.backend_url}/managed_authorities")
    req = Net::HTTP::Post.new(url.request_uri)
    req['Content-Type'] = 'text/json'
    req.body = request.to_json

    response = JSONModel::HTTP.do_http_request(url, req)

    expect(response.code).to eq("200")
    resource = JSONModel(:resource).find_by_uri(resource.uri)
    expect(resource.subjects.size).to eq(1)
  end
end
