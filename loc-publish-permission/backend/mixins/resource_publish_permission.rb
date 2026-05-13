module ResourcePublishPermission

  class PermissionException < StandardError
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  def update_from_json(json, opts = {}, apply_nested_records = true)
    user = User[:username => RequestContext.get(:current_username)]
    if (json.publish ? 1 : 0) != self.publish && !user.can?(:publish_resource_record)
       raise PermissionException
    end
    super
  end

  module ClassMethods

    def create_from_json(json, opts = {})
      user = User[:username => RequestContext.get(:current_username)]
      if (json.publish && !user.can?(:publish_resource_record))
        raise PermissionException
      end
      super
    end
  end
end
