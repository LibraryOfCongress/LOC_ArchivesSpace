require 'spec_helper'

describe 'deleting digital objects with resources' do
  it 'deletes digital objects when deleting a resource' do

    digital_object_1 = create(:json_digital_object)
    digital_object_2 = create(:json_digital_object)

    resource = create(:json_resource,
                      instances: [
                        build(:json_instance_digital,
                              digital_object: {ref: digital_object_1.uri})])

    create(:json_archival_object,
           resource: {ref: resource.uri},
           instances: [
             build(:json_instance_digital,
                   digital_object: {ref: digital_object_2.uri})])

    expect(ArchivalObject.first(root_record_id: resource.id)).to_not be_nil
    expect(DigitalObject.first(id: digital_object_1.id)).to_not be_nil
    expect(DigitalObject.first(id: digital_object_2.id)).to_not be_nil

    obj = Resource[resource.id]
    obj.delete_with_digital_objects

    expect(ArchivalObject.first(root_record_id: resource.id)).to be_nil
    expect(DigitalObject.first(id: digital_object_1.id)).to be_nil
    expect(DigitalObject.first(id: digital_object_2.id)).to be_nil
  end

  it 'does not delete a digital object that is related to another record', :disable_database_transaction do

    digital_object_1 = create(:json_digital_object)
    digital_object_2 = create(:json_digital_object)
    digital_object_3 = create(:json_digital_object)

    resource = create(:json_resource,
                      instances: [
                        build(:json_instance_digital,
                              digital_object: {ref: digital_object_1.uri})])

    resource2 = create(:json_resource,
                      instances: [
                        build(:json_instance_digital,
                              digital_object: {ref: digital_object_3.uri})])

    ao1 = create(:json_archival_object,
                 resource: {ref: resource.uri},
                 instances: [
                   build(:json_instance_digital,
                         digital_object: {ref: digital_object_2.uri}),
                   build(:json_instance_digital,
                         digital_object: {ref: digital_object_3.uri})])

    

    expect(ArchivalObject.first(root_record_id: resource.id)).to_not be_nil
    expect(DigitalObject.first(id: digital_object_1.id)).to_not be_nil
    expect(DigitalObject.first(id: digital_object_2.id)).to_not be_nil

    obj = Resource[resource.id]
    expect {
      obj.delete_with_digital_objects
    }.to raise_error(LocDigitalObjectDeleter::OtherDigitalObjectReferencesError)
  end
end
