module AdditionalIdentifiers

  def self.included(base)
    base.extend(ClassMethods)
  end

  def update_from_json(json, opts = {}, apply_nested_records = true)
    if json.additional_identifiers&.size
      opts[:additional_identifiers] = JSON.dump(json.additional_identifiers)
      json.additional_identifiers = []
    end
    obj = super(json, opts, apply_nested_records)
  end

  module ClassMethods

    def create_from_json(json, opts = {})
      if json.additional_identifiers&.size
        opts[:additional_identifiers] = JSON.dump(json.additional_identifiers)
        json.additional_identifiers = []
      end
      obj = super(json, opts)
    end

    def sequel_to_jsonmodel(objs, opts)
      jsons = super
      jsons.each do |json|
        if json.additional_identifiers.is_a? String
          json.additional_identifiers = JSON.parse(json.additional_identifiers)
        end
      end
    end

  end
end
