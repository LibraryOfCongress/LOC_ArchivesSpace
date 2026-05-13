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

end
