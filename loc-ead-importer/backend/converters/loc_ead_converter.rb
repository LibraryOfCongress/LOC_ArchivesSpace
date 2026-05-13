require_relative 'lib/loc_record_batch'
require_relative 'lib/note_builder'
require_relative 'lib/loc_ead_converter_constants'

class LocEADConverter < EADConverter
  include LocEADConverterConstants

  def is_legal_collection?
    @is_legal_collection_cache ||= begin
      resource = ancestor(:resource)
      resource && LEGAL_COLLECTION_EADIDS.include?(resource.ead_id)
    end
  end

  def is_special_rbsc_collection?
    @is_special_rbsc ||= begin
      resource = ancestor(:resource)
      resource && RBSC_SPECIAL_DATES_EADIDS.include?(resource.ead_id)
    end
  end

  def self.import_types(show_hidden = false)
    [
      {
        :name => "loc_ead_xml",
        :description => "Import LOC EAD3 records from an XML file"
      }
    ]
  end

  def self.instance_for(type, input_file)
    if type == "loc_ead_xml"
      self.new(input_file)
    else
      nil
    end
  end

  def self.profile
    "Convert EAD3 To ArchivesSpace JSONModel records"
  end

  def self.filing_title_lookup(ead_id)
    @@filing_title_lookup ||= Nokogiri::XML::Document.parse(IO.read(File.join(File.dirname(__FILE__), '../lib/loc_divisions_ead_master_sort_01.xml')))
    @@filing_title_lookup.xpath("//doc[@eadid='#{ead_id}']/@alpha_srt").text
  end

  # fix bug with core node close handler
  def handle_closer(node)
    @node = node
    if node.is_a? Array
      @node_name = node[0]
      @node_depth = node[1]
    else
      @node_name = node.local_name
      @node_depth = node.depth
    end

    super
    @node = nil
  end

  # AS‑250 helper – parse the value of a <physdesc> string
  def parse_physdesc_content(text)
    parts = {
      container_summary: nil,
      number:            nil,
      extent_type:       nil,
      physical_details:  nil,
      dimensions:        nil
    }

    text = text.to_s.strip
    return parts if text.empty?

    # example: "701 items (chiefly photographic prints); 57 x 41 cm. or smaller."
    if text =~ /\A([\d,]+)\s+([^()]+)\s+\(([^()]+)\);\s*(.+)\.?\z/m
      parts[:number]            = Regexp.last_match(1).strip
      parts[:extent_type]       = Regexp.last_match(2).strip
      parts[:physical_details]  = Regexp.last_match(3).strip
      parts[:dimensions]        = Regexp.last_match(4).strip

    # split on the first number
    elsif text =~ /\A(.*?)([\d,]+(?:\.\d+)?)\b(.*)\z/m
      prefix, num, tail = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)
      parts[:container_summary] = prefix.strip.sub(/[[:punct:]]+\z/, '') unless prefix.strip.empty?
      parts[:number]            = num.strip
      remainder                 = tail.to_s.strip

      colon     = remainder.index(':')
      semicolon = remainder.index(';')

      if colon && semicolon
        if colon < semicolon
          parts[:extent_type]      = remainder[0...colon].strip
          parts[:physical_details] = remainder[(colon + 1)...semicolon].strip
          parts[:dimensions]       = remainder[(semicolon + 1)..-1].strip
        else
          parts[:extent_type] = remainder[0...semicolon].strip
          parts[:dimensions]  = remainder[(semicolon + 1)..-1].strip
        end
      elsif colon
        parts[:extent_type]      = remainder[0...colon].strip
        parts[:physical_details] = remainder[(colon + 1)..-1].strip
      elsif semicolon
        parts[:extent_type] = remainder[0...semicolon].strip
        parts[:dimensions]  = remainder[(semicolon + 1)..-1].strip
      else
        parts[:extent_type] = remainder
      end
    else
      # no number – give up and return an empty object
      return parts
    end

    parts.each { |k, v| parts[k] = nil if v&.empty? }
    parts
  end

  def self.configure
    super

    # Explanation:
    # The EADConverter was written without much forethought for cases where
    # we want to modify or chain tag handlers rather than clobbering them.
    # So this is an ugly workaround to allow us to reuse the core functionality
    # but also add our own bits.
    # When `super` above ran, the `with 'unitid'` block in the parent converter
    # defined a method called `_unitid`. So we are going to grab that method
    # as an unbound instance method right now, so we can use it in our
    # `with 'unitid'` block below.
    @@core_unitid_handler = self.instance_method(:_unitid)
    @@core_container_handler = self.instance_method(:_container)
    @@core_list_handler = self.instance_method(:_list)
    @@core_unittitle_handler = self.instance_method(:_unittitle)

    # Handle <controlnote> specifically for setting id_0 from LCCN once
    with 'controlnote' do |node|
      # AS-362: Handle <controlnote label="otherNote"> with LCCN as an "Other Finding Aid" note.
      if att('label') == 'otherNote' && inner_xml.downcase.include?('lccn')
        _make_catalog_record_note(inner_xml, att('id'), att('audience') != 'internal')
        return
      end

      lccn = nil
      inner_node = Nokogiri::XML::DocumentFragment.parse(inner_xml.strip)
      lccn_ref   = inner_node.xpath('//ref').first
      if lccn_ref && node.attribute('id') == 'lccnNote'
        href_attr = lccn_ref.attribute('href')
        if href_attr
          href_str = href_attr.value
          lccn = href_str.split('/').last
          lccn = lccn.strip if lccn && !lccn.strip.empty?
        end
      end

      if lccn
        ancestor(:resource) do |obj|
          obj.lccn = lccn
          if obj.id_0.nil?
            obj.id_0 = lccn
          end
        end
      end

      doc = Nokogiri::XML::DocumentFragment.parse(node.inner_xml)

      # Process the <controlnote> as a repeatable multipart note.
      new_note = JSONModel(:note_multipart).new({
        "type" => "Control Note",
        "subnotes" => []
      })

      # Iterate over <p> child elements in the document fragment and create subnotes.
      doc.xpath("./p").each do |p_node|
        subnote = JSONModel(:note_text).new({
          "content" => p_node.inner_html.strip
        })
        new_note.subnotes << subnote
      end

      # If no <p> elements exist, capture the entire text content as one subnote.
      if new_note.subnotes.empty?
        text_content = doc.inner_html.strip
        unless text_content.empty?
          subnote = JSONModel(:note_text).new({ "content" => text_content })
          new_note.subnotes << subnote
        end
      end

      # Add the new note to the resource's notes array.
      ancestor(:resource) do |resource|
        resource.notes ||= []
        resource.notes << new_note
      end
    end

    # c, c1, c2, etc...
    (0..12).to_a.map {|i| "c" + (i+100).to_s[1..-1]}.push('c').each do |c|
      with c do |*|
        has_magmar_id = att('id') =~ /^magmar/

        make :archival_object, {
               :level => att('level') || 'file',
               :other_level => att('otherlevel'),
               :ref_id => !has_magmar_id ? att('id') : nil,
               :loc_magmar_id => has_magmar_id ? att('id') : nil,
               :resource => ancestor(:resource),
               :parent => ancestor(:archival_object),
               :publish => att('audience') != 'internal'
             } do |archival_object|
          if @last_top_container
            @last_top_container_scopes << archival_object.uri
          end
        end
      end

      # last minute additions to the archival object created by a <c*> tag
      # for properties that are additive or dependent on other properties.
      and_in_closing c do |node|
        archival_object = context_obj

        if (staged_refs = archival_object.instance_variable_get(:@staged_see_also_refs))
          # This runs if unittitle had a "See also" but no <relatedmaterial> tag was ever found.
          # We must create the note from scratch here.
          related_materials_note = ASpaceImport::JSONModel(:note_multipart).new({
            "type" => "relatedmaterial",
            "publish" => true,
            "subnotes" => []
          })

          staged_refs.each do |ref_xml|
             new_subnote = ASpaceImport::JSONModel(:note_text).new({
              "content" => ref_xml, "publish" => true
            })
            related_materials_note.subnotes << new_subnote
          end

          archival_object.notes << related_materials_note
          archival_object.remove_instance_variable(:@staged_see_also_refs)
        end

        if (case_numbers = archival_object.instance_variable_get(:@case_numbers)) && !case_numbers.empty?
          prefix = case_numbers.join(', ')
          original_title = archival_object.title.to_s.strip

          if original_title.empty?
            archival_object.title = prefix
          else
            # If there is a title, add the separator.
            archival_object.title = "#{prefix}: #{original_title}"
          end

          archival_object.remove_instance_variable(:@case_numbers)
        end

        if @container_ranges[archival_object.uri]
          @container_ranges[archival_object.uri].each do |range_info|
            prefix = ""
            range_str = range_info[:range]
            container_type = range_info[:type]
            if /^([^\d]+)([\d-]+)$/.match(range_str)
              range_str = $2
              prefix = $1
            elsif /^([a-zA-Z]+)(\d+)-\1(\d+)$/.match(range_str)
              range_str = "#{$2}-#{$3}"
              prefix = $1
            end

            # Added guard against non-numeric ranges causing errors
            next unless range_str.match?(/^\d+-\d+$/)

            start_num, end_num = range_str.split('-').map(&:to_i)
            (start_num..end_num).each do |i|
              add_instance(
                top_container_type: container_type, # Use the stored type ('Box' or 'Reel')
                top_container_indicator: "#{prefix}#{i}",
                sub_container_type: nil,
                sub_container_indicator: nil
              )
            end
          end
          @container_ranges.delete(archival_object.uri)
        end

        if @extents_from_physdescs[archival_object.uri]
          make :extent, {
            portion:              "whole",
            number:               @extents_from_physdescs[archival_object.uri].to_s,
            extent_type:          "folders",
          }.compact do |extent|
            archival_object.extents << extent
          end
          @extents_from_physdescs.delete(archival_object.uri)
        end

        # now add the top container to the archival object if:
        # 1) the archival object has no instances with a top container
        #    link
        # 2) the archival object's parent or resource is in scope
        top_container_refs = archival_object.instances.map {
          |i| i.sub_container
        }.compact.map { |sc| sc['top_container']['ref'] }
        if top_container_refs.empty? && @last_top_container && \
           @repo_code != "p&p" && \
           (@last_top_container_scopes.include?(archival_object.resource['ref']) || \
            (archival_object.parent && \
             @last_top_container_scopes.include?(archival_object.parent['ref'])))
          make :instance, {
                 :instance_type => instance_type
               } do |instance|
            make :sub_container, {
                   top_container: { ref: @last_top_container.uri },
                 } do |sub_container|
              set instance, :sub_container, sub_container
            end
            archival_object.instances << instance
          end
        end
        # delete this object's uri from the top container scope
        @last_top_container_scopes.delete(archival_object.uri)

        # create a new digital object instance or append to existing
        if @filename_unitids[archival_object.uri]
          if (digital_object_instance = archival_object.instances.find { |i| !i.digital_object.nil? })
            @digital_object_additional_notes[digital_object_instance.digital_object['ref']] = @filename_unitids[archival_object.uri]
          else
            make :digital_object, {
                   digital_object_id: SecureRandom.uuid,
                   publish: true,
                   title: archival_object.title
                 } do |obj|
              file_version = ASpaceImport::JSONModel(:file_version).new
              file_version.file_uri = @filename_unitids[archival_object.uri]
              file_version.publish = true
              obj.file_versions << file_version
              note = ASpaceImport::JSONModel(:note_digital_object).new
              note.type = 'descriptivenote'
              note.content = [@filename_unitids[archival_object.uri]]
              obj.notes << note
              _add_digital_access_note(obj)
              instance = ASpaceImport::JSONModel(:instance).new
              instance.instance_type = "digital_object"
              instance.digital_object = { 'ref' => obj.uri }
              archival_object.instances << instance
            end
          end
          @filename_unitids.delete(archival_object.uri)
        end
      end
    end

    with 'unittitle' do |node|
      unittitle_fragment = Nokogiri::XML::DocumentFragment.parse(inner_xml.strip)
      refs_to_move = unittitle_fragment.xpath(".//ref[contains(translate(., 'SEEALSO', 'seealso'), 'see also')]") + \
                     unittitle_fragment.xpath(".//ref[contains(translate(., 'SEAMCONTIR', 'seamcontir'), 'see same container')]")

      # catch "and" and ";" appended refs
      catch_next = false
      appended_children = {}
      parent_ref_id = nil
      unittitle_fragment.children.each do |child|
        if refs_to_move.include? child
          parent_ref_id = child.object_id
          appended_children[parent_ref_id] = []
          catch_next = true
        elsif parent_ref_id && child.node_type == 3 && child.text.strip =~ /(,?\s?and|;)/
          appended_children[parent_ref_id] << child
          catch_next = true
        elsif catch_next && child.name == "ref"
          appended_children[parent_ref_id] << child
          catch_next = false
        else
          catch_next = false
          parent_ref_id = nil
        end
      end

      unless refs_to_move.empty?
        ancestor(:resource, :archival_object) do |obj|
          related_materials_note = obj.notes.find do |n|
            n['type'] == 'relatedmaterial' && n['jsonmodel_type'] == 'note_multipart'
          end

          if related_materials_note
            # The relatedmaterial note already exists. Append to it.
            refs_to_move.each do |ref_node|
              content = ref_node.to_xml
              if appended_children[ref_node.object_id]
                appended_children[ref_node.object_id].each do |appended|
                  content += appended.to_xml.gsub(/\n/, ' ')
                  appended.remove
                end
              end
              new_subnote = ASpaceImport::JSONModel(:note_text).new({
                "content" => content, "publish" => true
              })
              related_materials_note.subnotes << new_subnote
              ref_node.remove
            end
          else
            # The note doesn't exist yet. Stage the content for later.
            staged_refs = obj.instance_variable_get(:@staged_see_also_refs) || []
            refs_to_move.each do |ref_node|
              content = ref_node.to_xml
              if appended_children[ref_node.object_id]
                appended_children[ref_node.object_id].each do |appended|
                  content += appended.to_xml.gsub(/\n/, ' ')
                  appended.remove
                end
              end
              staged_refs << content
              ref_node.remove
            end
            obj.instance_variable_set(:@staged_see_also_refs, staged_refs)
          end
        end
      end


      unittitle_date = unittitle_fragment.xpath(".//date")
      backup_unittitle = is_special_rbsc_collection? ? unittitle_date.to_s : nil
      unittitle_date.remove

      # Get the text content from the fragment and then format it
      cleaned_title = format_content(unittitle_fragment.to_s)

      # Normalize all internal whitespace to single spaces
      cleaned_title.gsub!(/\s+/, ' ')

      # Collapse consecutive commas (" , , ") into a single comma and space
      cleaned_title.gsub!(/(\s*,\s*)+/, ', ')

      # Trim any lingering whitespace from the ends after normalization
      cleaned_title.strip!

      # Remove a leading comma and space left over from a date removal
      cleaned_title.sub!(/^, /, '')

      # Remove a trailing comma, preserving a quote character if one is present
      cleaned_title.sub!(/,\s*(['"]?)\z/, '\1')

      if cleaned_title.empty? && is_special_rbsc_collection?
        cleaned_title = backup_unittitle
      end

      # Set the title for the current archival object or resource
      ancestor(:resource, :archival_object) do |obj|
        unless obj.class.record_type == "note_multipart"
          obj.title = cleaned_title
        end
      end

      # Store the cleaned title and its associated object ID in memo for potential
      # use by other handlers
      unless cleaned_title.empty?
        memo(:last_unittitle_and_object_id, [cleaned_title, context_obj.id])
      end

      # If a 'ref_id' attribute is present on the unittitle tag, assign it to the
      # archival object
      if ref_id = att('id')
        ancestor(:archival_object) do |rec|
          rec.ref_id = ref_id if rec
        end
      end
    end

    with 'dao' do |node|
      cleaned_xml = clean_ampersands(node.outer_xml)
      doc = Nokogiri::XML::DocumentFragment.parse(cleaned_xml)
      dao = doc.xpath("dao").first

      # Extract descriptivenote node and its text content
      descriptivenote_node = dao.xpath('descriptivenote').first
      descriptivenote_text = descriptivenote_node ? descriptivenote_node.text.strip : ""

      # Non-conflicting import for href
      file_uri = if dao.attr('label') == "Filepath"
                   descriptivenote_text
                 elsif dao.attr('href')
                   dao.attr('href')
                 else
                   REQUIRED_FIELD_PLACEHOLDER
                 end

      title = has_multiple_instances_title = descriptivenote_text
      unittitle = memo(:last_unittitle_and_object_id)
      if unittitle && unittitle[1] == context_obj.id
        title = unittitle[0]
      end

      # Prepare a unique Digital Object ID, handling potential duplicates
      dedupe_ids = false
      digital_object_id = if dao.attr('href') && dao.attr('href').include?('/')
                            dedupe_ids = true
                            dao.attr('href').split('/').last.sub(/\/$/, '')
                          else
                            SecureRandom.uuid
                          end

      # chop off prefixes for MI repository
      if @repo_code == "mi" && digital_object_id =~ /^\w+\.(\w+)$/
        digital_object_id = Regexp.last_match(1)
      end

      # Handle cases where multiple <dao> tags point to the same digital content
      if dedupe_ids && @digital_object_ids[digital_object_id]
        # this assumes that both instances of the <dao> tag have the same descriptivenote content...
        @rewrite_titles[@digital_object_ids[digital_object_id]] = has_multiple_instances_title
      else
        make :digital_object, {
               digital_object_id: digital_object_id,
               publish: att('audience') != 'internal',
               title: title,
               ead_dao_type: att('daotype')
             } do |obj|
          obj.file_versions << {
            :use_statement => att('role'),
            :file_uri => file_uri,
            :xlink_actuate_attribute => (att('actuate') == 'onload' ? 'onLoad' : att('actuate')),
            :xlink_show_attribute => 'new',
            :publish => att('audience') != 'internal',
          }

          # Add access note for born-digital or non-HTTPS DAOs.
          if (att('daotype')&.downcase == 'borndigital') || !file_uri.to_s.include?('https')
            _add_digital_access_note(obj)
          end

          # Check if <descriptivenote> exists and its text is not the excluded phrase
          if descriptivenote_node && descriptivenote_text.downcase.strip != "digital content available"
            descriptivenote_content = descriptivenote_node.inner_html.strip
            unless descriptivenote_content.empty?
              # Create a 'note_digital_object' with a specific type for the new label
              make :note_digital_object, {
                :type => 'descriptivenote',
                :persistent_id => descriptivenote_node.attribute('id')&.value,
                :publish => true,
                :content => format_content(descriptivenote_content)
              } do |note|
                set obj, :notes, note
              end
            end
          end

          @digital_object_ids[digital_object_id] = obj.uri
        end
      end
      make :instance, {
             :instance_type => 'digital_object',
             :digital_object => { ref: @digital_object_ids[digital_object_id] }
           } do |instance|
        set ancestor(:archival_object), :instances, instance
      end
    end

    def implied_top_container?
      return false unless @last_top_container
      return false if @last_top_container_scopes.empty?
      archival_object = @batch.closest_archival_object
      return false if archival_object.nil?
      return true if archival_object.parent && \
                     @last_top_container_scopes.include?(archival_object.parent['ref'])
      return true if archival_object.resource && \
                     @last_top_container_scopes.include?(archival_object.resource['ref'])
      return true if @last_top_container_scopes.include?(archival_object.uri)
      return false
    end

    def add_instance(top_container_type:, top_container_indicator:, sub_container_type:, sub_container_indicator:, instance_type: nil)
      top_container_uri = get_or_make_top_container_uri(top_container_type,
                                                        top_container_indicator,
                                                        nil,
                                                        nil)
      make :instance, {
              :instance_type => instance_type
            } do |instance|
        make :sub_container, {
                top_container: { ref: top_container_uri },
                type_2: sub_container_type,
                indicator_2: sub_container_indicator
              } do |sub_container|
          set instance, :sub_container, sub_container
          remember_instance(instance)
        end

        set ancestor(:resource, :archival_object), :instances, instance
      end
    end

    with 'container' do |node|
      return nil if node.inner_xml.strip.empty?

      instance_type = att('label')
      instance_type = instance_type.downcase.strip if instance_type
      inner_xml_content = inner_xml.strip
      local_type = att('localtype')

      # AS-395: Complex music container parsing logic.
      if local_type == 'box-folder' && (inner_xml_content.include?(',') || inner_xml_content.include?(' to '))

        parse_indicator = lambda do |indicator_str|
          indicator_str = indicator_str.to_s.strip
          return ['', indicator_str.to_i] if indicator_str.match?(/^\d+$/)
          match = indicator_str.match(/^(.*?)\s*(\d+)$/)
          return [match[1].strip, match[2].to_i] if match
          [indicator_str, nil]
        end

        parts = inner_xml_content.split(/\s*,\s*/)

        parts.each do |part|
          next if part.strip.empty?

          if part.include?(' to ')
            start_part, end_part = part.split(/\s+to\s+/, 2)

            # Defend against malformed ranges like "306/1 to " which cause end_part to be nil
            next if start_part.to_s.strip.empty? || end_part.to_s.strip.empty?

            start_box_str, start_folder_str = start_part.strip.split('/', 2)
            end_box_str, end_folder_str = end_part.strip.split('/', 2)

            start_box_prefix, start_box_num = parse_indicator.call(start_box_str)

            sub_container_indicator = case start_folder_str.to_s.strip
            when '1', '' then nil
            when /^\d+$/ then "#{start_folder_str}-*"
            else start_folder_str
            end

            add_instance(
              top_container_type: 'Box', top_container_indicator: start_box_str,
              sub_container_type: sub_container_indicator ? 'folder' : nil,
              sub_container_indicator: sub_container_indicator, instance_type: instance_type
            )

            end_box_prefix, end_box_num = parse_indicator.call(end_box_str)
            if start_box_num && end_box_num && start_box_prefix == end_box_prefix && end_box_num > start_box_num + 1
              (start_box_num + 1...end_box_num).each do |box_num|
                indicator = start_box_prefix.empty? ? box_num.to_s : "#{start_box_prefix} #{box_num}"
                add_instance(
                  top_container_type: 'Box', top_container_indicator: indicator,
                  sub_container_type: nil, sub_container_indicator: nil, instance_type: instance_type
                )
              end
            end

            sub_container_indicator = case end_folder_str.to_s.strip
            when '1' then '1'
            when /^\d+$/ then "1-#{end_folder_str}"
            else end_folder_str
            end

            add_instance(
              top_container_type: 'Box', top_container_indicator: end_box_str,
              sub_container_type: sub_container_indicator ? 'folder' : nil,
              sub_container_indicator: sub_container_indicator, instance_type: instance_type
            )

          else
            box_str, folder_str = part.strip.split('/', 2)

            # Defend against empty parts resulting from stray commas or slashes
            next if box_str.to_s.strip.empty?

            add_instance(
              top_container_type: 'Box', top_container_indicator: box_str,
              sub_container_type: folder_str ? 'folder' : nil,
              sub_container_indicator: folder_str, instance_type: instance_type
            )
          end
        end
        return
      end

      # delete container range data for the parent AO if it exists
      # per AS-321; make a note instead per AS-383
      if context_obj.jsonmodel_type == 'archival_object' && context_obj.parent && \
         @container_ranges[context_obj.parent['ref']]
        parent_obj = @batch.find_by_uri(context_obj.parent['ref'])
        range_note = JSONModel(:note_singlepart).new(
          {
            type: "physdesc",
            publish: true,
            label:   'Container Range',
            content: [@container_ranges[parent_obj.uri].map { |range| "#{range[:type]}: #{range[:range]}" }.join("\n")]
          }
        )
        parent_obj.notes << range_note
        @container_ranges.delete(parent_obj.uri)
      end

      local_type = att('localtype')

      # defers ALL ranges (box, reel, etc.)
      # to the and_in_closing hook, where a decision can be made based on the presence of children.
      if inner_xml.strip.split(',').all? {|c| c.strip =~ /^\w*\s?\d+-\w*\d+$/ }
        # store a map of container ranges to create when the <c tag closes
        # if the <c tag ends up with no children with containers.
        @container_ranges[context_obj.uri] ||= []
        # Determine the type for the range expansion. Default to 'Box'.
        range_type = local_type&.include?('reel') ? 'Reel' : 'Box'
        inner_xml.strip.split(',').each do |range_str|
          @container_ranges[context_obj.uri] << { range: range_str.strip, type: range_type }
        end
        return

      # Handle standalone reel containers that are not ranges.
      # This ensures single reels always become separate top containers.
      elsif local_type == 'reel'
        add_instance(
          top_container_type: 'Reel',
          top_container_indicator: inner_xml.strip,
          sub_container_type: nil,
          sub_container_indicator: nil,
          instance_type: instance_type
        )
        return

      # Handle non-range compound containers.
      elsif att('localtype') =~ /^(\w*)[-\/](\w*)$/
        top_container_type = $1
        sub_container_type = $2

        # If a compound type contains 'reel', split it into separate top containers.
        if top_container_type.include?('reel') || sub_container_type.include?('reel')
          indicators = inner_xml.strip.split('/')

          # This creates the first top container (e.g., Box 50 from "box-reel" and "50/1")
          add_instance(
            top_container_type: top_container_type.capitalize,
            top_container_indicator: indicators[0],
            sub_container_type: nil,
            sub_container_indicator: nil,
            instance_type: instance_type
          )
          # This creates the second, separate top container for the reel (e.g., Reel 1)
          add_instance(
            top_container_type: sub_container_type.capitalize,
            top_container_indicator: indicators[1],
            sub_container_type: nil,
            sub_container_indicator: nil,
            instance_type: instance_type
          )
          return
        end

        if inner_xml.strip =~ /([^\/]+)\/([^\/]+),\s+([^\/]+)\/([^\/]+)/
          add_instance(
            top_container_type: top_container_type,
            top_container_indicator: $1,
            sub_container_type: sub_container_type,
            sub_container_indicator: $2,
            instance_type: instance_type
          )
          add_instance(
            top_container_type: top_container_type,
            top_container_indicator: $3,
            sub_container_type: sub_container_type,
            sub_container_indicator: $4,
            instance_type: instance_type
          )
          return
        end
        top_container_indicator = sub_container_indicator = format_content(inner_xml)
        if inner_xml.strip =~ /^([^\/]+)\/([^\/]+)$/
          top_container_indicator = $1
          sub_container_indicator = $2
        end
        add_instance(
          top_container_type: top_container_type,
          top_container_indicator: top_container_indicator,
          sub_container_type: sub_container_type,
          sub_container_indicator: sub_container_indicator,
          instance_type: instance_type
        )
        return
      elsif inner_xml.strip =~ /^([^\/]+)\/([^\/]+)\/([^\/]+)$/
        ind1, ind2, ind3 = $1, $2, $3
        type = att('localtype')
        last_instance = recall_instance
        # if it looks like this 3-part indicator is referencing the most recent instance
        # and top_container, link to the top container.
        if last_instance && @last_top_container && \
           last_instance.sub_container["top_container"]["ref"] == @last_top_container.uri && \
           last_instance.sub_container["indicator_2"] == ind2.downcase
          sub_instance = ASpaceImport::JSONModel(:instance).new(last_instance.to_hash)
          sub_instance["sub_container"]["indicator_3"] = ind3
          sub_instance["sub_container"]["type_3"] = type
          set ancestor(:archival_object), :instances, sub_instance
          return
        end
      elsif att('localtype') && att('localtype').downcase == 'folder' && implied_top_container? && @repo_code != "p&p"
        # we don't want to create a second instance on the first object to
        # create an implied top container:
        if !context_obj.instances.empty? && \
           context_obj.instances[0].sub_container['top_container']['ref'] == @last_top_container.uri && \
           context_obj.instances[0].sub_container["indicator_2"].nil?
          context_obj.instances[0].sub_container["type_2"] = "folder"
          context_obj.instances[0].sub_container["indicator_2"] = inner_xml.strip
        else
          make :instance, {
                 :instance_type => instance_type
               } do |instance|
            make :sub_container, {
                   top_container: { ref: @last_top_container.uri },
                   type_2: 'folder',
                   indicator_2: inner_xml.strip
                 } do |sub_container|
              set instance, :sub_container, sub_container
              remember_instance(instance)
            end

            set ancestor(:resource, :archival_object), :instances, instance
          end
        end
        return
      elsif @repo_code == "mss" && context != :instance && !att('parent') && att('localtype') == 'box'
        # For AS-295, need to prevent core handler from trying to add this to the existing instance,
        # which in this case may be associated with a box from an ancestor or sibling
        add_instance(
          top_container_type: 'box',
          top_container_indicator: inner_xml,
          sub_container_type: nil,
          sub_container_indicator: nil,
          instance_type: instance_type
        )
        return
      end

      core_container_handler = @@core_container_handler.bind(self)
      core_container_handler.call(node)
      instance = recall_instance
      instance.instance_type = instance_type
    end

    with 'physdesc' do |node|
      if @repo_code == "mss" && @last_top_container && inner_xml.strip =~ /\(?(\d+)\s(folders?)\)?/
        ancestor(:archival_object, :resource) do |obj|
          unless defined?(obj.instances) && (instance = obj.instances.last)
            sub_container = ASpaceImport::JSONModel(:sub_container).new
            sub_container.top_container = { "ref": @last_top_container.uri }
            instance = ASpaceImport::JSONModel(:instance).new
            instance.sub_container = sub_container
            obj.instances << instance
          end

          @extents_from_physdescs[obj.uri] ||= 0
          @extents_from_physdescs[obj.uri] += $1.to_i
        end

        return
      end

      # grab the raw value
      raw_content  = Nokogiri::XML::DocumentFragment.parse(inner_xml).text.strip
      label_attr   = att('label')
      portion_val  = (att('altrender')&.downcase == 'materialspec') ? 'materialtype' : 'whole'
      full_text = (label_attr ? "#{label_attr}: #{raw_content}" : raw_content)
                    .gsub(/\s+/, ' ').strip

      if @repo_code == "afc"
        portion_val = if label_attr && label_attr.downcase.include?("whole")
                        "whole"
                      elsif raw_content.include?("item")
                        "whole"
                      else
                        "part"
                      end
      end

      # AS-307
      multiples = raw_content.gsub(/\s+(and|plus)\s+/, "__SPLIT__").split("__SPLIT__")
      if context_obj.jsonmodel_type == "resource" && multiples.size > 1 && \
         multiples.all? {|snip| /^(\d+)\s([\w\s]+)$/.match? (snip)}
        multiples.each do |number_and_type|
          md = /^(\d+)\s([\w\s]+)$/.match(number_and_type)
          make :extent, {
            portion:              portion_val,
            number:               md[1],
            extent_type:          md[2],
            physical_description: md[0]
          }.compact do |extent|
            set ancestor(:resource), :extents, extent
          end
        end
      elsif context_obj.jsonmodel_type == "resource"
        # decompose the MARC‑style string
        parsed       = parse_physdesc_content(raw_content)
        make :extent, {
          portion:              portion_val,
          container_summary:    parsed[:container_summary],
          number:               parsed[:number] || "0",
          extent_type:          parsed[:extent_type] || "unknown",
          physical_details:     parsed[:physical_details],
          dimensions:           parsed[:dimensions],
          physical_description: full_text
        }.compact do |extent|
          set ancestor(:resource), :extents, extent
        end
      end

      # verbatim text (note + resource‑level, unchanged)
      full_text ||= (label_attr ? "#{label_attr}: #{raw_content}" : raw_content)
      full_text   = full_text.gsub(/\s+/, ' ').strip

      ancestor(:resource) do |res|
        if res.respond_to?(:physical_description=)
          old = Array(res.physical_description).reject(&:empty?).join('; ')
          res.physical_description = [old, full_text].reject(&:empty?).join('; ')
        end
      end

      if context_obj.jsonmodel_type == "archival_object"
        unless full_text.empty?
          make :note_singlepart, {
            type:    'physdesc',
            label:   (label_attr || 'Physical Description'),
            publish: (att('audience') != 'internal'),
            content: full_text
          } do |note|
            # Set the note to the archival_object, not the resource
            set ancestor(:archival_object), :notes, note
          end
        end
      end

      # suppress the core handler
      true
    end

    with 'langmaterial' do |node|
      doc = Nokogiri::XML::DocumentFragment.parse(node.inner_xml)

      # Ensure the "Language" dropdown(s) appear above the "Language of Materials" note.
      code_lang_materials     = []
      fallback_lang_materials = []
      note_lang_materials     = []

      found_a_valid_code = false

      # Process each <language> tag found within <langmaterial>.
      doc.xpath('.//*[local-name()="language"]').each do |lang_node|
        lang_code = lang_node['langcode']&.to_s&.strip
        next if lang_code.nil? || lang_code.empty?

        # Found at least one valid language code
        found_a_valid_code = true

        # Get all associated scripts. Scripts can be siblings if the language is in a <languageset>.
        script_codes = []
        if lang_node.parent&.name == 'languageset'
          sibling_scripts = lang_node.parent.xpath('./*[local-name()="script"]').map do |script_node|
            script_node['scriptcode']&.to_s&.strip
          end.compact.reject(&:empty?)
          script_codes.concat(sibling_scripts)
        end

        # Also check for a scriptcode attribute directly on the <language> tag
        if lang_node['scriptcode']
          script_codes << lang_node['scriptcode'].to_s&.strip
        end

        script_codes.uniq!

        # Handle cases:
        # A language is present, but no scripts. Create lang_material with nil script.
        # A language and scripts are present. Create all combinations.
        if script_codes.empty?
          make :lang_material, {} do |langmat|
            langmat.language_and_script = { 'language' => lang_code, 'script' => nil }
            code_lang_materials << langmat
          end
        else
          script_codes.each do |script_code|
            make :lang_material, {} do |langmat|
              langmat.language_and_script = { 'language' => lang_code, 'script' => script_code }
              code_lang_materials << langmat
            end
          end
        end
      end

      # If no valid (non-empty) langcode was found, add fallback "eng"
      unless found_a_valid_code
        make :lang_material, {} do |langmat|
          langmat.language_and_script = { 'language' => 'eng' }
          fallback_lang_materials << langmat
        end
      end

      # Create a note from the remaining descriptive text of <langmaterial>
      doc.search('.//language', './/script', './/languageset').each(&:remove)
      content = format_content(doc.to_s)

      unless content.strip.empty?
        make :lang_material, {
          :jsonmodel_type => 'lang_material',
          :notes => {
            'jsonmodel_type' => 'note_langmaterial',
            'type' => 'langmaterial',
            'persistent_id' => att('id'),
            'publish' => att('audience') != 'internal',
            'content' => [content]
          }
        } do |note_lang_mat|
          note_lang_materials << note_lang_mat
        end
      end

      # attach them to the Resource in the order we want:
      (code_lang_materials + fallback_lang_materials + note_lang_materials).each do |langmat|
        # Store at RESOURCE level
        set ancestor(:resource, :archival_object), :lang_materials, langmat
      end
    end

    with 'unitdate' do |node|
      if context_obj.jsonmodel_type == 'archival_object' && is_special_rbsc_collection?
        make :note_multipart, {
               :publish => true
             } do |note|
          NoteBuilder.new(note, node).build_scopenote_from_unitdate
          ancestor(:archival_object) do |obj|
            obj.notes << note
          end
        end
        return
      end

      norm_dates = (att('normal') || "").strip.split('/')

      norm_dates.map! {|d| d =~ /^([0-9]{4}(\-?(1[0-2]|0[1-9])(\-?(0[1-9]|[12][0-9]|3[01]))?)?)$/ ? d : nil}
      norm_dates.map! {|d| d =~ /^\d{6}$/ ? "#{d[0..3]}-#{d[4..5]}" : d }
      norm_dates.map! {|d| d =~ /^\d{8}$/ ? "#{d[0..3]}-#{d[4..5]}-#{d[6..7]}" : d }
      norm_dates.compact!
      norm_dates.sort!

      if norm_dates.empty? && inner_xml =~ /^(\d{4})-(\d{4})$/
        norm_dates = [Regexp.last_match(1), Regexp.last_match(2)].sort
      end

      # AS-378: determine the date_type by prioritizing the unitdatetype attribute.
      # handles 'bulk' and 'inclusive' explicitly, and defaults to 'inclusive'
      # for all other cases, including when the attribute is absent
      unitdatetype = att('unitdatetype')&.strip&.downcase

      date_type_for_aspace = case unitdatetype
                             when 'bulk'
                               'bulk'
                             when 'inclusive'
                               'inclusive'
                             else
                               'inclusive'
                             end

      make :date, {
        :date_type => date_type_for_aspace,
        :expression => inner_xml,
        :label => 'creation',
        :begin => norm_dates[0],
        :end => norm_dates[1],
        :calendar => att('calendar'),
        :era => att('era'),
        :certainty => att('certainty')
      } do |date|
        set ancestor(:resource, :archival_object), :dates, date
      end
    end

    with 'unitid' do |node|
      # AS-334: Rationalize unitid label before processing.
      original_label = att('label')

      # Look up the label in our map. Default to the original label if not found.
      standardized_label = original_label ? UNITID_LABEL_MAP.fetch(original_label, original_label) : nil

      if standardized_label == 'do not import'
        return
      end

      # Handle cases where the unitid should become a note.
      if standardized_label == 'didnote'
        make :note_singlepart, {
          type:    'didnote',
          publish: true,
          label:   original_label,
          content: inner_xml.strip
        } do |note|
          set ancestor(:resource, :archival_object), :notes, note
        end
        return
      elsif standardized_label == 'odd'
        # 'odd' notes must be multipart to be valid in this context.
        make :note_multipart, {
          type: 'odd',
          publish: true,
          label: original_label
        } do |note|
          note.subnotes << ASpaceImport::JSONModel(:note_text).new({
            'jsonmodel_type' => 'note_text',
            'content' => inner_xml.strip,
            'publish' => true
          })
          set ancestor(:resource, :archival_object), :notes, note
        end
        return
      end

      if context_obj.jsonmodel_type == 'archival_object' && att('id') && context_obj.ref_id.nil?
        context_obj.ref_id = att('id')
      end

      if context_obj.jsonmodel_type == 'archival_object' && is_legal_collection? && standardized_label.nil?
        id_text = format_content(inner_xml.strip)
        unless id_text.empty?
          context_obj.instance_variable_set(:@case_numbers, []) unless context_obj.instance_variable_get(:@case_numbers)
          context_obj.instance_variable_get(:@case_numbers) << id_text
        end
        # Return to skip core handler and prevent setting the component_id
        return
      end

      if context_obj.jsonmodel_type == 'resource'
        # we might already have an `id_0`, but
        # we prefer to use `unitid` if possible.
        fallback_id = nil
        ancestor(:resource) do |obj|
          fallback_id = obj.id_0
          obj.id_0 = nil
        end
        core_unitid_handler = @@core_unitid_handler.bind(self)
        core_unitid_handler.call(node)
        context_obj.id_0 ||= fallback_id

        # If the resource-level unitid contains "guide",
        # override it with the EAD ID from <recordid>.
        if context_obj.id_0 && context_obj.id_0.match?(/guide/i)
          # Use the ead_id parsed out from <recordid>
          if context_obj.ead_id && !context_obj.ead_id.strip.empty?
            context_obj.id_0 = context_obj.ead_id
          else
            # If for some reason ead_id is missing, don't leave "Guide" in id_0
            context_obj.id_0 = REQUIRED_FIELD_PLACEHOLDER
          end
        end
      end

      if standardized_label == "Digital ID"
        title = digital_id_title = inner_xml
        unittitle = memo(:last_unittitle_and_object_id)
        if unittitle && unittitle[1] == context_obj.id
          title = unittitle[0]
        end
        id = inner_xml.strip.empty? ? SecureRandom.uuid : inner_xml
        @digital_object_ids ||= {}
        # if we already saw this ID, we want to make sure
        # to set the digital object title back to the "Digital ID"
        # since it relates to more than one unit title
        if @digital_object_ids[id]
          @rewrite_titles[@digital_object_ids[id]] = digital_id_title
        else
          make :digital_object, {
                 :digital_object_id => id,
                 :title => title
               } do |digital_object|
            @digital_object_ids[id] = digital_object.uri # More explicit than context_obj.uri
            _add_digital_access_note(digital_object)     # Add access note
          end
        end
        make :instance, {
               :instance_type => 'digital_object',
               :digital_object => { ref: @digital_object_ids[id] }
             } do |instance|
          set ancestor(:archival_object), :instances, instance
        end
        ancestor(:archival_object) do |obj|
          obj.component_id = nil
        end

      # AS-263 Creating Containers from <unitid>
      elsif standardized_label == "Box"
        top_container_uri = get_or_make_top_container_uri("box",
                                                          inner_xml.strip,
                                                          nil,
                                                          nil)
      elsif standardized_label && (["box-folder", "oversize-folder"].include? standardized_label.downcase)
        top_container_type, subtype = standardized_label.downcase.split('-')
        top_indicator, sub_indicator = inner_xml.strip.split('/')
        top_container_uri = get_or_make_top_container_uri(top_container_type,
                                                          top_indicator,
                                                          nil,
                                                          nil)
        if sub_indicator
          make :instance, {} do |instance|
            set ancestor(:archival_object), :instances, instance
          end
          instance = context_obj
          make :sub_container, {
                 top_container: {'ref' => top_container_uri},
                 type_2: subtype,
                 indicator_2: sub_indicator
               } do |sub_container|
            set instance, :sub_container, sub_container
          end
          remember_instance(instance, ancestor(:archival_object).uri)
        end

      elsif standardized_label && (["folder", "folder-sleeve", "sleeve"].include? standardized_label.downcase)
        parent_instance_id = ancestor(:archival_object).parent["ref"]
        parent_instance = recall_instance(parent_instance_id)
        types = standardized_label.downcase.split('-')
        indicators = inner_xml.strip.split('/')
        if parent_instance && indicators.size == 3
          child_instance = ASpaceImport::JSONModel(:instance).new(parent_instance.to_hash)
          child_instance["sub_container"]["indicator_3"] = indicators[2]
          child_instance["sub_container"]["type_3"] = types.last
          set ancestor(:archival_object), :instances, child_instance
        end
      elsif standardized_label && (["LCCN", "LCCN:", "LCCNs", "LCCNs:"].include? standardized_label.strip) && \
            context_obj.jsonmodel_type == "archival_object"
        doc = Nokogiri::XML::DocumentFragment.parse(node.inner_xml)
        if doc.xpath("//ref").size > 0
          make :note_multipart, {
                 :type => 'otherfindaid',
                 :label => 'Catalog Record',
                 :persistent_id => att('id'),
                 :publish => true
               } do |note|
            text_note = ASpaceImport::JSONModel(:note_text).new
            text_note.content ||= ""
            text_note.content = doc.inner_html.strip
            text_note.publish = true
            note.subnotes.push(text_note)
            ancestor(:archival_object) do |archival_object|
              set archival_object, :notes, note
              if archival_object.component_id == node.inner_xml.strip
                archival_object.component_id = nil
              end
            end
          end
        elsif inner_xml =~ /^\d+$/
          if inner_xml == ancestor(:resource).id_0
            ancestor(:archival_object) do |archival_object|
              archival_object.component_id = nil
            end
          else
            ancestor(:archival_object) do |archival_object|
              archival_object.component_id = inner_xml
            end
          end
        end
      elsif standardized_label == "filename"
        ancestor(:archival_object) do |archival_object|
          @filename_unitids[archival_object.uri] = inner_xml unless archival_object.nil?
        end
        return
      elsif (label = standardized_label) && (id = inner_xml)
        ancestor(:archival_object) do |obj|
          break if obj.nil?
          if obj.component_id.nil? || obj.component_id.empty?
            obj.component_id = "#{label}: #{id}"
          else
            obj.additional_identifiers << "#{label}: #{id}"
          end
        end
      end
    end

    with 'recordid' do |node|
      doc = Nokogiri::XML::DocumentFragment.parse(node.outer_xml)

      # Grab the <recordid> element
      recordid_node = doc.at_xpath('recordid')
      next unless recordid_node

      # Text inside <recordid>
      record_id_text = recordid_node.text.to_s.strip
      next if record_id_text.empty?

      # Truncate after the last slash
      truncated_with_prefix = record_id_text.split('/').last.strip

      # Remove prefix
      truncated_id = truncated_with_prefix.sub(/^[^.]+\./, '')

      # instanceurl -> EAD Location
      record_id_instance_url = recordid_node['instanceurl'] || ""

      # Assign to Resource
      ancestor(:resource) do |resource|
        resource.ead_id       = truncated_id
        resource.ead_location = record_id_instance_url
      end
    end

    # turn off core chronlist handlers
    with 'chronlist' do |*|
      return nil
    end

    with 'chronitem' do |*|
      return nil
    end

    with 'chronitem/event' do |*|
      return nil
    end

    # turn off core handler for archdesc/did
    with "archdesc/did" do |*|
      return nil
    end

    with 'head' do |node|
      # AS-337: Capture the ID from any head tag to be ignored later.
      if (id = att('id'))
        @ignored_note_head_ids << id
      end

      # Replicate core behavior to set the label for various note types.
      if context == :note_multipart
        if context_obj.type != "bioghist"
          context_obj.label ||= format_content( inner_xml )
        end
      elsif context == :note_chronology
        context_obj.title ||= format_content( inner_xml )
      end
    end

    %w(accessrestrict accruals acqinfo altformavail appraisal
       arrangement bioghist custodhist
       fileplan odd originalsloc phystech
       prefercite processinfo relatedmaterial scopecontent
       separatedmaterial userestrict ).each do |note_tag|

      with note_tag do |node|
        return nil if context_obj.jsonmodel_type == 'note_multipart' && \
                      context_obj.type == node.name

        make :note_multipart, {
               :type => node.name,
               :persistent_id => att('id'),
               :publish => true
             } do |note|
          NoteBuilder.new(note, node).build_note
          ancestor(:resource, :archival_object) do |obj|
            if node.name == 'relatedmaterial'
              if (staged_refs = obj.instance_variable_get(:@staged_see_also_refs))
                staged_refs.each do |ref_xml|
                  new_subnote = ASpaceImport::JSONModel(:note_text).new({
                    "content" => ref_xml, "publish" => true
                  })
                  note.subnotes << new_subnote
                end
                obj.remove_instance_variable(:@staged_see_also_refs)
              end
            end
            obj.notes << note
          end
        end
      end
    end

    with 'otherfindaid' do |node|
      if inner_xml.downcase.include?('lccn')
        _make_catalog_record_note(inner_xml, att('id'), att('audience') != 'internal')
      else
        make :note_multipart, {
               :type => 'otherfindaid',
               :persistent_id => att('id'),
               :publish => true
             } do |note|
          NoteBuilder.new(note, node).build_note
          ancestor(:resource, :archival_object) do |obj|
            obj.notes << note
          end
        end
      end
    end

    with 'item/list' do |*|
      return nil
    end

    with 'defitem' do |node|
      return nil
    end

    with 'list' do |*|
      # if a <list> tag occurs within a parent note-making tag,
      # handle it there.
      return nil if ancestor(:note_multipart)
      raise "Unexpected <list> tag in a non-note context #{inner_xml}"
    end

    with "origination" do |*|
      remember_origination_label(att("label"))
    end

    with 'origination/name' do |*|
      make_person_template(:role => 'source')
      set_agent_relator
    end

    with 'origination/persname' do |*|
      make_person_template(:role => 'source')
      set_agent_relator
    end

    with 'origination/corpname' do |*|
      make_corp_template(:role => 'source')
      set_agent_relator
    end

    with 'origination/famname' do |*|
      make_family_template(:role => 'source')
      set_agent_relator
    end

    with 'languagedeclaration' do |node|
      doc = Nokogiri::XML::DocumentFragment.parse(node.outer_xml)
      langcode = doc.xpath('//language/@langcode').first
      langcode = langcode.text if langcode
      script = doc.xpath('//script/@scriptcode').first
      script = script.text if script
      ancestor(:resource) do |record|
        record.finding_aid_language = langcode
        record.finding_aid_script = script
      end
    end

    with 'didnote' do |*|
      make :note_singlepart, {
        type:    'didnote',
        publish: true,
        label:   att('label'),
        content: inner_xml.gsub('&amp;', '&')
      } do |note|
        # Set the note to the archival_object, not the resource
        set ancestor(:resource, :archival_object), :notes, note
      end
    end
  end

  with 'maintenanceevent' do |node|
    doc        = Nokogiri::XML::DocumentFragment.parse(node.outer_xml)
    event_node = doc.at_xpath('maintenanceevent')
    next unless event_node

    # Extract sub-elements
    eventtype_node        = event_node.at_xpath('eventtype')
    eventdatetime_node    = event_node.at_xpath('eventdatetime')
    agenttype_node        = event_node.at_xpath('agenttype')
    agent_node            = event_node.at_xpath('agent')
    eventdescription_node = event_node.at_xpath('eventdescription')

    eventtype        = eventtype_node && (eventtype_node['value'] || eventtype_node.text.strip)
    eventdatetime    = eventdatetime_node && (eventdatetime_node['standarddatetime'] || eventdatetime_node.text.strip)
    agenttype        = agenttype_node && (agenttype_node['value'] || agenttype_node.text.strip)
    agent            = agent_node && agent_node.text.strip
    eventdescription = eventdescription_node && eventdescription_node.text.strip

    make :revision_statement, {
      date:        eventdatetime,
      description: eventdescription,
      type:        eventtype,
      agent_type:  agenttype,
      agent:       agent
    } do |revision_stmt|
      set ancestor(:resource), :revision_statements, revision_stmt
    end
  end

  # We need a way to rewrite records after they have all been serialized to
  # json the first time, so we set the batch's post_serialization_record_filter
  # which will be called when the batch closes and writes the final batch file.
  def initialize(input_file)
    super
    @batch = LocRecordBatch.new
    # stores values of any 'id' att found on <head> tags within notes
    @ignored_note_head_ids = Set.new
    @rewrite_titles = {}
    @digital_object_ids = {}
    @container_ranges = {}
    @extents_from_physdescs = {}
    @filename_unitids = {}
    @digital_object_additional_notes = {}
    @last_top_container = nil
    @last_top_container_scopes = Set.new
    @end_of_month_re = /^(\d+)-(\d+)-(3\d)$/
    @note_with_head_tag_re = /^\s*<head[^>]*>([^<]+)<\/head>\s*(.*)\Z/m
    @publish_finding_aids_by_default = false
    @batch.post_serialization_record_filter = ->(record) {
      if record["jsonmodel_type"] == "digital_object" && @rewrite_titles[record["uri"]]
        record["title"] = @rewrite_titles[record["uri"]]
      end
      if record["jsonmodel_type"] == "digital_object" && @digital_object_additional_notes[record["uri"]]
        note = ASpaceImport::JSONModel(:note_digital_object).new
        note.type = 'descriptivenote'
        note.content = [@digital_object_additional_notes[record['uri']]]
        record["notes"] << note
      end
    }
    # Note: Do not rely on `ancestor` helper in the record filter,
    # it can return the wrong object!
    # instead use @batch.closest_archival_object
    @batch.record_filter = ->(record) {
      if record["jsonmodel_type"] == "top_container"
        @last_top_container = nil
        @last_top_container_scopes.clear
        if record['type'] == 'box' && record['indicator'] =~ /^(\w+\s)?\d+$/
          @last_top_container = record
          @batch.closest_archival_object do |archival_object|
            break if archival_object.nil?
            @last_top_container_scopes << archival_object.uri
            if archival_object.parent
              @last_top_container_scopes << archival_object.parent['ref']
            elsif archival_object.resource
              @last_top_container_scopes << archival_object.resource['ref']
            end
          end
        end
      end

      # handles cleanup of dangling <ref> tags whose targets were ignored.
      # runs only if we have stored ignored IDs
      if record.respond_to?(:notes) && !@ignored_note_head_ids.empty?
        record.notes.each do |note|
          case note['jsonmodel_type']
          when 'note_multipart'
            if note['subnotes']
              note['subnotes'].each do |subnote|
                subnote['content'] = cleanup_dangling_refs(subnote['content']) if subnote['content']
              end
            end
          when 'note_singlepart'
            if note['content']
              note['content'].map! { |content_string| cleanup_dangling_refs(content_string) }
            end
          end
        end
      end

      if record.respond_to? :notes
        record.notes.each do |note|
          case note.jsonmodel_type
          when "note_multipart"
            label = note.label
            note.subnotes.each do |subnote|
              if @note_with_head_tag_re.match(subnote["content"])
                if (note.label.nil? || note.label.empty?) && note.type != "bioghist"
                  note.label = $1.strip
                  subnote["content"] = $2
                elsif note.label == $1.strip
                  subnote["content"] = $2
                else
                  # don't strip out the <head> content if for some reason it
                  # can't populate the note label.
                end
              end
              if subnote["content"]
                subnote["content"].gsub!(/<ref([^>]*href=[^>]*>[^<]+)<\/ref>/, '<extref\1</extref>')
              end
            end
          when "note_singlepart"
            if note.type == "didnote"
              # handle the <head> tag if it exists
              if @note_with_head_tag_re.match(note.content[0])
                head_content = $1.strip
                content_after_head = $2

                # If the note doesn't already have a label from the attribute, use the <head>
                if note.label.nil? || note.label.empty?
                  note.label = head_content
                end

                # strip the <head> tag from the content
                note.content[0] = content_after_head
              end

              # if label is still nil, default it to "Note"
              if note.label.nil?
                note.label = "Note"
              end

              # Handle the italic "Note:" text
              if note.content[0].start_with?('<emph render="italic">Note:')
                note.content[0].sub!('<emph render="italic">Note:</emph>', '')
                note.content[0].sub!('<emph render="italic">Note: </emph>', '')
              end
            end
          end
        end
      end

      # AS-291
      if record["jsonmodel_type"] == "digital_object"
        record["publish"] = true
        record.file_versions.each do |fv|
          fv["publish"] = true
        end
      end

      # Automatically publish agent records created via batch import.
      if ['agent_person', 'agent_corporate_entity', 'agent_family'].include?(record['jsonmodel_type'])
        record['publish'] = true
      end

      if record.respond_to? :dates
        record.dates.each do |date|
          if date['begin'] && @end_of_month_re.match(date['begin'])
            if !Date.valid_date?($1.to_i, $2.to_i, $3.to_i) && \
               Date.valid_date?($1.to_i, $2.to_i, -1)
              date['begin'] = Date.new($1.to_i, $2.to_i, -1).to_s
            end
          end
          if date['end'] && @end_of_month_re.match(date['end'])
            if !Date.valid_date?($1.to_i, $2.to_i, $3.to_i) && \
               Date.valid_date?($1.to_i, $2.to_i, -1)
              date['end'] = Date.new($1.to_i, $2.to_i, -1).to_s
            end
          end
        end
      end

      if record["jsonmodel_type"] == "resource" && record.finding_aid_filing_title.nil?
        record.finding_aid_filing_title = self.class.filing_title_lookup(record.ead_id)
      end

      if record["jsonmodel_type"] == "resource" && @repo_code == "p&p" && record.extents.size > 1
        record.extents.each { |e| e.portion = "part" }
      end

      if record["jsonmodel_type"] == "resource" && ["mi", "rs"].include?(@repo_code)
        record.extents.each do |e|
          if e.physical_description.include? "("
            e.portion = "part"
          else
            e.portion = "whole"
          end
        end
      end

      if record["jsonmodel_type"] == "resource"
        record['publish'] = @publish_finding_aids_by_default

        # AS-380: Set Description Rules by repository on import
        if @repo_code == "p&p"
          record.finding_aid_description_rules = "dcrmg"
        else
          record.finding_aid_description_rules = "dacs"
        end
      end

      true
    }
  end

  # Because of the way the batch_import_job_runner is designed,
  # we can't grab the repository in `initialize` - the runner
  # instantiates the converter before opening the RequestContext.
  def run
    repo_id = RequestContext.get(:repo_id)
    @repo_code = Repository[repo_id].repo_code.downcase
    super
  end

  # It looks like EAD3 replaced "@type" with "@localtype"
  # so we can use this hack to keep core handlers like
  # "_container" working.
  def att(attribute, namespace = nil)
    value = super(attribute, namespace)
    value = super('localtype', namespace) if attribute == 'type' && value.nil?

    if (attribute == 'id' || attribute == 'label') && value&.start_with?('mfer')
      return nil
    end

    value
  end

  def memo(key, value = nil)
    @memo ||= {}
    if value
      @memo[key] = value
    else
      return @memo[key]
    end
  end

  def remember_origination_label(label)
    memo("origination_label", label) if label
  end

  def recall_origination_label
    memo("origination_label")
  end

  def relator_for_label(label)
    return nil if label.nil?
    MARC_RELATOR_REVERSE_LOOKUP[label.downcase]
  end

  def set_agent_relator
    label = recall_origination_label
    return unless label

    standardized_term = ORIGINATION_LABEL_MAP.fetch(label.downcase, label)

    final_relator_code = relator_for_label(standardized_term)

    final_relator = final_relator_code || standardized_term

    if final_relator
      ancestor(:resource, :archival_object) do |record|
        if record.linked_agents.last
          record.linked_agents.last['relator'] = final_relator
        end
      end
    end
  end

  private

  def clean_ampersands(xml)
    xml.gsub("&amp;", "___AMPERSAND___").gsub("&", "___AMPERSAND___").gsub("___AMPERSAND___", "&amp;")
  end

  # Removes <ref> tags whose 'target' attribute matches an ID from an
  # ignored <head> tag, leaving the inner text in place
  # @param content [String] The note content to clean
  # @return [String] The cleaned content
  def cleanup_dangling_refs(content)
    # Return early if there's nothing to do
    return content if content.nil? || !content.include?('<ref') || @ignored_note_head_ids.empty?

    # Use HTML fragment parser for robustness with mixed content (text + tags)
    doc_fragment = Nokogiri::HTML::DocumentFragment.parse(content)
    modified = false

    # Use .css selector for simplicity
    doc_fragment.css("ref[target]").each do |ref_node|
      if @ignored_note_head_ids.include?(ref_node['target'])
        # Unwrap the <ref> tag, keeping its text content
        ref_node.replace(ref_node.children)
        modified = true
      end
    end

    # Avoid re-serializing if no changes were made
    if modified
      # Use .to_html for fragments parsed as HTML
      doc_fragment.to_html.strip
    else
      content
    end
  end

  # Creates a multipart "Other Finding Aid" note with the "Catalog Record" label.
  # @param content [String] The raw inner_xml of the note tag.
  # @param id [String] The persistent_id from the EAD tag's 'id' attribute.
  def _make_catalog_record_note(content, id, publish_status)

    formatted_content = format_content(content)

    cleaned_content = formatted_content.sub(/\A\s*Catalog Record\s*:?\s*/i, '').lstrip

    make :note_multipart, {
      :type => 'otherfindaid',
      :persistent_id => id,
      :publish => publish_status,
      :label => 'Catalog Record'
    } do |note|
      note.subnotes << {
        'jsonmodel_type' => 'note_text',
        'content' => cleaned_content,
        'publish' => publish_status
      }
      set ancestor(:resource, :archival_object), :notes, note
    end
  end

  # AS-396: Creates a standard access restriction note for digital objects
  # that are available only on-site
  # AS-451: Assume restricted digital objects have ead_dao_type "borndigital"
  def _add_digital_access_note(digital_object)
    if digital_object.ead_dao_type.nil?
      digital_object.ead_dao_type = "borndigital"
    end

    note_text = "Access to this digital content is available onsite only and requires advance request. Consult reference staff for more information."

    # Avoid adding duplicate notes
    return if digital_object.notes.any? do |note|
      note['type'] == 'accessrestrict' && note['content'].include?("available onsite only")
    end

    access_note = ASpaceImport::JSONModel(:note_digital_object).new(
      type: 'accessrestrict',
      label: 'Conditions Governing Access',
      content: [note_text],
      publish: true
    )

    digital_object.notes << access_note
  end

  def publish_finding_aids_by_default!
    @publish_finding_aids_by_default = true
  end
end
