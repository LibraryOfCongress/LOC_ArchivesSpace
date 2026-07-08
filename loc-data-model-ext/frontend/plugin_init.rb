ArchivesSpace::Application.config.after_initialize do

  module AspaceFormHelper

    alias_method :define_template_orig, :define_template

    # I can't think of a cleaner way to do this without further
    # enhancements to the core plugin API. We want to redefine
    # one of the note subrecord templates, so we sneak it in this
    # way, rendering an override template that calls define_template
    # then pointing the original name at the override.
    # The overide ERB file MUST pass the template name as:
    # <original name>_override
    # If it passes the original name we will be in infinite recursion.
    def define_template(name, definition = nil, &block)
      if name == "chronology_item"
        override_template = case action_name
                            when "merge_selector"
                              "chronology_item_template_merge_override"
                            else
                              "chronology_item_template_override"
                            end
        render_aspace_partial :partial => "notes/#{override_template}"
        @templates['chronology_item'] = @templates['chronology_item_override']
      else
        define_template_orig(name, definition, &block)
      end
    end

  end


  class BulkImportTemplatesController

    def download
      if TEMPLATE_FILES.any? { |template| template.fetch(:filename) == params['filename'] }
        if plugin_template_dir = ASUtils.find_local_directories.find { |local_dir| File.exist?(File.join(local_dir, 'templates', params['filename'])) }
          send_file File.join(plugin_template_dir, 'templates', params['filename']), status: 202
        else
          send_file "#{Rails.root}/docs/#{params['filename']}", status: 202
        end
      else
        redirect_to(:controller => :bulk_import_templates, :action => :index)
      end
    end
  end

  # AS-131: RDE Cleanup & Validation Fixes
  # Reopen ArchivalRecordChildren to clean RDE rows before JSONModel validation
  class ArchivalRecordChildren
    class << self
      alias_method :clean_loc_orig, :clean unless method_defined?(:clean_loc_orig)
      alias_method :clean_instances_loc_orig, :clean_instances unless method_defined?(:clean_instances_loc_orig)

      def clean(data)
        # Strip blank additional identifiers from the array before validation
        if data['additional_identifiers'].is_a?(Array)
          data['additional_identifiers'].reject! { |id| id.nil? || id.strip.empty? }
        end
        clean_loc_orig(data)
      end

      def clean_instances(data)
        # Prevent validation error on empty instance type
        # The schema allows instance_type to be missing (ifmissing: nil),
        # but minLength: 1 causes an error if the UI sends an empty string "".
        if data['instances'].is_a?(Array)
          data['instances'].each do |instance|
            if instance.has_key?('instance_type') && instance['instance_type'].to_s.strip.empty?
              instance.delete('instance_type')
            end
          end
        end
        clean_instances_loc_orig(data)
      end
    end
  end

end
