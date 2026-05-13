
ArchivesSpace::Application.config.after_initialize do

  AspaceFormHelper::FormContext.class_eval do

    alias_method :label_and_textfield_orig, :label_and_textfield

    def label_and_textfield(name, opts = {})
      opts[:base_url] ||= "/"
      if obj[name] && readonly?
        field_html = case @active_template
                     when "chronology_item"
                       clean_mixed_content(obj[name], opts[:base_url])
                     else
                       obj[name]
                     end
        label_with_field(name, textfield(name, field_html, opts[:field_opts] || {}), opts)
      else
        label_and_textfield_orig(name, opts)
      end
    end

  end

end
