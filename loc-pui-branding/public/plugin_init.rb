ArchivesSpacePublic::Application.config.after_initialize do

  # --- AS-566: Decode WAF-bypassed XSS characters in facet values ---
  ApplicationController.class_eval do
    before_action :loc_restore_waf_bypassed_params

    def loc_restore_waf_bypassed_params
      if params[:filter_values].is_a?(Array)
        params[:filter_values] = params[:filter_values].map do |v|
          v.is_a?(String) ? v.gsub('__LT__', '<').gsub('__GT__', '>') : v
        end
      end
    end
  end

  class NoteRenderer
    alias_method :build_label_orig, :build_label

    def build_label(type, note)
      label = case type
              when 'scopecontent'
                "Scope and Content Note"
              else
                build_label_orig(type, note)
              end
    end
  end

  class SinglepartNoteRenderer
    alias_method :render_orig, :render

    # <p> tags in mixed content fields are a constant headache
    # in ArchivesSpace. If the users wraps the note content text
    # in a <p> tag, or if the importer brings it in that way,
    # we can end up with <p><p>CONTENT</p></p> being rendered.
    def render(type, note, result)
      result = render_orig(type, note, result)
      if result['note_text'] =~ /\A<p>\s*(<p>.*<\/p>)\s*<\/p>\z/m
        result['note_text'] = Regexp.last_match(1).strip
      end
      result
    end
  end

  class MultipartNoteRenderer
    alias_method :render_orig, :render

    def render(type, note, result)
      result = render_orig(type, note, result)
      if result['label']
        result['label'] = LocMixedContentParser.parse(result['label'], AppConfig[:public_proxy_url])
      end
      (result['subnotes'] || []).each do |subnote|
        if subnote['_title']
          subnote['_title'] = LocMixedContentParser.parse(subnote['_title'], AppConfig[:public_proxy_url])
        end
      end
      result
    end
  end

  class ContainersController
    alias_method :show_orig, :show

    def show
      show_orig

      # LOC customization:
      # We are adding the search within and date range controls to the facet panel
      unless @results&.empty?
        @search[:dates_within] = true if params.fetch(:filter_from_year, '').blank? && params.fetch(:filter_to_year, '').blank?
        @search[:text_within] = true
      end
    end
  end

  require_relative 'models/loc_citation_ext'
  require_relative 'controllers/objects_controller'
end
