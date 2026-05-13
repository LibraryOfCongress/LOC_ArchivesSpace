require 'spec_helper'

describe "permission to publish resource records" do
  it "enforces permission to publish at publish-all endpoints" do
    repo1 = create(:repo)
    repo2 = create(:repo)

    group1 = Group.create_from_json(build(:json_group), :repo_id => repo1.id)
    group1.grant("publish_resource_record")
    group1.grant("update_resource_record")

    group2 = Group.create_from_json(build(:json_group), :repo_id => repo2.id)
    group2.grant("update_resource_record")

    archivist = make_test_user("archivist")

    RequestContext.open(:repo_id => repo1.id) do
      group1.add_user(archivist)
      expect(archivist.can?("publish_resource_record")).to be_truthy
    end
    RequestContext.open(:repo_id => repo2.id) do
      group2.add_user(archivist)
      expect(archivist.can?("publish_resource_record")).to be_falsey
    end

    JSONModel.set_repository(repo1.id)
    RequestContext.put(:repo_id, repo1.id)
    resource1 = create(:json_resource)
    ao1 = create(:json_archival_object)

    JSONModel.set_repository(repo2.id)
    RequestContext.put(:repo_id, repo2.id)
    resource2 = create(:json_resource)
    ao2 = create(:json_archival_object)

    as_test_user('archivist') do
      expect(JSONModel::HTTP::post_form("/repositories/#{repo1.id}/resources/#{resource1.id}/publish").code).to eq('200')
      expect(JSONModel::HTTP::post_form("/repositories/#{repo2.id}/resources/#{resource2.id}/publish").code).to eq('403')
      expect(JSONModel::HTTP::post_form("/repositories/#{repo1.id}/resources/#{resource1.id}/unpublish").code).to eq('200')
      expect(JSONModel::HTTP::post_form("/repositories/#{repo2.id}/resources/#{resource2.id}/unpublish").code).to eq('403')
      expect(JSONModel::HTTP::post_form("/repositories/#{repo1.id}/archival_objects/#{ao1.id}/publish").code).to eq('200')
      expect(JSONModel::HTTP::post_form("/repositories/#{repo2.id}/archival_objects/#{ao2.id}/publish").code).to eq('403')
      expect(JSONModel::HTTP::post_form("/repositories/#{repo1.id}/archival_objects/#{ao1.id}/unpublish").code).to eq('200')
      expect(JSONModel::HTTP::post_form("/repositories/#{repo2.id}/archival_objects/#{ao2.id}/unpublish").code).to eq('403')
    end
  end

  it "enforces publish permissions when creating or updating a resource or component" do

    updaters = Group.create_from_json(build(:json_group), repo_id: $repo_id)
    updaters.grant("update_resource_record")

    publishers = Group.create_from_json(build(:json_group), repo_id: $repo_id)
    publishers.grant("publish_resource_record")

    archivist = make_test_user("archivist")
    super_archivist = make_test_user("super_archivist")

    updaters.add_user(archivist)
    updaters.add_user(super_archivist)
    publishers.add_user(super_archivist)

    # archivist cannot create a resource with publish == true
    json = build(:json_resource, { publish: false } )

    as_test_user('archivist') do
      expect { Resource.create_from_json(json, :repo_id => $repo_id) }.not_to raise_error
    end

    json = build(:json_resource, { publish: true } )
    as_test_user('archivist') do
      expect {
        Resource.create_from_json(json, :repo_id => $repo_id)
      }.to raise_error(ResourcePublishPermission::PermissionException)
    end



    resource_json = create(:json_resource, publish: false, instances: [])
    resource_obj = Resource[resource_json.id]

    # verify that archivist can make updates
    resource_json[:title] = "new title"
    as_test_user('archivist') do
      expect { resource_obj.update_from_json(resource_json) }.not_to raise_error
    end

    # refresh the jsonmodel and toggle publish
    resource_json[:publish] = true
    resource_json[:lock_version] = 1

    # verify archivist cannot save now.
    as_test_user('archivist') do
      expect { resource_obj.update_from_json(resource_json) }.to raise_error(ResourcePublishPermission::PermissionException)
    end

    # verify super archivist can save.
    as_test_user('super_archivist') do
      expect { resource_obj.update_from_json(resource_json) }.not_to raise_error
    end

    # repeat for components
    component_json = create(:json_archival_object, resource: { ref: resource_json.uri }, publish: false)

    component_json.publish = true
    component_obj = ArchivalObject[component_json.id]

    as_test_user('archivist') do
      expect { component_obj.update_from_json(component_json) }.to raise_error(ResourcePublishPermission::PermissionException)
    end

    as_test_user('super_archivist') do
      expect { component_obj.update_from_json(component_json) }.not_to raise_error
    end

    # tbd: ensure notes cannot be published either...?
  end
end
