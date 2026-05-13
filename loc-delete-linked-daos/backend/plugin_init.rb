class LocDigitalObjectDeleter

  class OtherDigitalObjectReferencesError < StandardError; end

  def self.delete_instance(instance, digital_object_ids_to_delete)
    if instance[:instance_type_id] && EnumerationValue[instance[:instance_type_id]][:value] == "digital_object"
      instance.object_graph.each do |model, ids_to_delete|
        if model == Relationships::InstanceInstanceDoLink
          ids_to_delete.each do |id|
            digital_object_id = Relationships::InstanceInstanceDoLink[id][:digital_object_id]
            digital_object_ids_to_delete << digital_object_id
            Relationships::InstanceInstanceDoLink[id].delete
          end
        end
      end
    end
  end
end


class Resource
  # it is not safe to use this outside a block that will raise a Sequel::Rollback
  # when it catches OtherDigitalObjectReferencesError
  # also, this is pretty specific to LOC data and will break for digital objects with
  # components or other subrecords not used by LOC.
  def delete_with_digital_objects
    digital_object_ids_to_delete = Set.new
    ArchivalObject.filter(root_record_id: self.id).each do |ao|
      ao.instance.each do |instance|
        next if instance.nil?
        LocDigitalObjectDeleter.delete_instance(instance, digital_object_ids_to_delete)
      end
    end
    self.instance.each do |instance|
      LocDigitalObjectDeleter.delete_instance(instance, digital_object_ids_to_delete)
    end
    digital_object_ids_to_delete.each do |digital_object_id|
      unless Relationships::InstanceInstanceDoLink[digital_object_id: digital_object_id].nil?
        raise LocDigitalObjectDeleter::OtherDigitalObjectReferencesError.new("See Digital Object #{digital_object_id}")
      end
    end
    Note.filter(digital_object_id: digital_object_ids_to_delete).delete
    FileVersion.filter(digital_object_id: digital_object_ids_to_delete).delete
    DigitalObject.handle_delete(digital_object_ids_to_delete)
    delete
  end
end
