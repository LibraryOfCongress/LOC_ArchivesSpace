class ArchivesSpaceService < Sinatra::Base
  Endpoint.post("/managed_authorities")
    .description("Update Subjects and Resource-Subject links")
    .params(["request", JSONModel(:managed_authorities_request), "The subjects to create and attach", body: true])
    .permissions([:update_subject_record])
    .returns([200, :updated]) do
    resource_uri = params[:request]["resource"]["ref"]
    resource_id = JSONModel(:resource).id_for(resource_uri)
    resource = Resource[resource_id]
    # destroy all existing subject relationships
    Relationships::ResourceSubject.find_by_participants([resource]).values.flatten.each {|r| r.delete }
    subjects = params[:request]["subjects"].map {|hash| JSONModel(:subject).from_hash(hash) }
    now = Time.now
    opts = {
      :system_mtime => now,
      :user_mtime => now
    }
    subject_uris = []
    Array(subjects).each_with_index do |subject, i|
      subject = Subject.ensure_exists(subject, nil)
      Relationships::ResourceSubject.relate(resource, subject, opts.merge(aspace_relationship_position: i))
      subject_uris << subject.uri
    end
    json_response({linked_subject_uris: subject_uris })
  end

end
