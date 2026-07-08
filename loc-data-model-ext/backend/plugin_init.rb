require_relative 'model/loc_titleless_date_unittitle'

module JSONModel::Validations
  if JSONModel(:digital_object)
    JSONModel(:digital_object).add_validation("check_digital_object_otherdaotype") do |hash|
      check_otherdaotype(hash)
    end
  end


  def self.check_otherdaotype(hash)
    errors = []

    if hash["ead_dao_type"] == "otherdaotype"
      errors << ["other_ead_dao_type", "missing required property"] if hash["other_ead_dao_type"].nil?
    end

    errors
  end
end

# AS-329
class TopContainer

  def display_string
    ["#{type ? type.capitalize : ''}", indicator].compact.join(" ").gsub(/:\Z/, '')
  end
end

# AS-436
class ImportArchivalObjects
  alias_method :create_archival_object_orig, :create_archival_object

  def create_archival_object(parent_uri)
    ao = create_archival_object_orig(parent_uri)
    if @row_hash["additional_identifier"]
      ao.additional_identifiers << @row_hash["additional_identifier"]
    end
    if @row_hash["additional_identifier_2"]
      ao.additional_identifiers << @row_hash["additional_identifier_2"]
    end

    if digital_object_instance = ao.instances.select { |instance| instance['instance_type'] == 'digital_object' }&.first
      digital_object_id = JSONModel(:digital_object).id_for(digital_object_instance['digital_object']['ref'])
      digital_object = DigitalObject.to_jsonmodel(digital_object_id)
      need_to_save = false
      if ead_dao_type = @row_hash["ead_dao_type"]
        digital_object.ead_dao_type = ead_dao_type
        need_to_save = true
        if ead_dao_type == "otherdaotype"
          digital_object.other_ead_dao_type = @row_hash["other_ead_dao_type"]
        end
      end

      if @row_hash["descriptive_note"] || @row_hash["descriptive_note_label"]
        note = JSONModel(:note_digital_object).new
        note.type = 'descriptivenote'
        note.label = @row_hash["descriptive_note_label"]
        note.content = [@row_hash["descriptive_note"]]
        digital_object.notes << note.to_hash
        need_to_save = true
      end

      if need_to_save
        obj = DigitalObject.get_or_die(digital_object_id)
        obj.update_from_json(digital_object)
      end
    end

    ao
  end

end

# AS-436
class NotesHandler
  alias_method :create_note_orig, :create_note

  def create_note(type, note_label, content, publish, dig_obj = false, b_date = nil, e_date = nil, local_restriction = nil)
    if type =~ /^(.*)_\d$/
      type = $1
    end
    create_note_orig(type, note_label, content, publish, dig_obj, b_date, e_date, local_restriction)
  end

end

class ContainerInstanceHandler
  alias_method :validate_container_instance_orig, :validate_container_instance

  def validate_container_instance(instance_type, type, instance, errs, subcont = {})
    sc = { "jsonmodeltype" => "sub_container" }
    if instance_type.nil?
      # hey, no problem!
    else
      instance.instance_type = value_check(@instance_types, instance_type, errs)
    end
    %w(2 3).each do |num|
      if subcont["type_#{num}"]
        sc["type_#{num}"] = value_check(@container_types, subcont["type_#{num}"], errs)
        sc["indicator_#{num}"] = subcont["indicator_#{num}"] || "Unknown"
        sc["barcode_#{num}"] = subcont["barcode_#{num}"] || nil
      end
    end
    sc
  end
end

# AS-512
class SpreadsheetBuilder
  alias_method :dataset_iterator_orig, :dataset_iterator

  def dataset_iterator(&block)
    DB.open do |db|
      @ao_ids.each_slice(BATCH_SIZE) do |batch|
        base_fields = [:id, :lock_version] + FIELDS_OF_INTEREST.fetch(:archival_object).map {|field| field.column}
        base = ArchivalObject
                .filter(:id => batch)
                .order(Sequel.lit("FIELD(id, #{batch.join(',')})"))
                .select(*base_fields)

        subrecord_datasets = {}
        SUBRECORDS_OF_INTEREST.each do |subrecord|
          next unless selected?(subrecord.to_s)

          subrecord_fields = [:archival_object_id] + FIELDS_OF_INTEREST.fetch(subrecord).map {|field| field.column}

          subrecord_datasets[subrecord] = {}

          db[subrecord]
            .filter(:archival_object_id => batch)
            .select(*subrecord_fields)
            .each do |row|
            subrecord_datasets[subrecord][row[:archival_object_id]] ||= []
            subrecord_datasets[subrecord][row[:archival_object_id]] << FIELDS_OF_INTEREST.fetch(subrecord).map {|field| [field.name, field.value_for(row[field.column])]}.to_h
          end
        end
        if selected?('instance')
          # Instances are special
          db[:instance]
            .join(:sub_container, Sequel.qualify(:sub_container, :instance_id) => Sequel.qualify(:instance, :id))
            .join(:top_container_link_rlshp, Sequel.qualify(:top_container_link_rlshp, :sub_container_id) => Sequel.qualify(:sub_container, :id))
            .join(:top_container, Sequel.qualify(:top_container, :id) => Sequel.qualify(:top_container_link_rlshp, :top_container_id))
            .filter(Sequel.qualify(:instance, :archival_object_id) => batch)
            .filter(Sequel.~(Sequel.qualify(:instance, :instance_type_id) => BackendEnumSource.id_for_value('instance_instance_type', 'digital_object'))).or(Sequel.qualify(:instance, :instance_type_id) => nil)
            .select(
              Sequel.as(Sequel.qualify(:instance, :archival_object_id), :archival_object_id),
              Sequel.as(Sequel.qualify(:instance, :instance_type_id), :instance_type_id),
              Sequel.as(Sequel.qualify(:top_container, :type_id), :top_container_type_id),
              Sequel.as(Sequel.qualify(:top_container, :indicator), :top_container_indicator),
              Sequel.as(Sequel.qualify(:top_container, :barcode), :top_container_barcode),
              Sequel.as(Sequel.qualify(:sub_container, :type_2_id), :sub_container_type_2_id),
              Sequel.as(Sequel.qualify(:sub_container, :indicator_2), :sub_container_indicator_2),
              Sequel.as(Sequel.qualify(:sub_container, :barcode_2), :sub_container_barcode_2),
              Sequel.as(Sequel.qualify(:sub_container, :type_3_id), :sub_container_type_3_id),
              Sequel.as(Sequel.qualify(:sub_container, :indicator_3), :sub_container_indicator_3),
            ).each do |row|

            subrecord_datasets[:instance] ||= {}
            subrecord_datasets[:instance][row[:archival_object_id]] ||= []
            subrecord_datasets[:instance][row[:archival_object_id]] << {
              :instance_type => EnumMapper.enum_id_to_spreadsheet_value(row[:instance_type_id], 'instance_instance_type'),
              :top_container_type => EnumMapper.enum_id_to_spreadsheet_value(row[:top_container_type_id], 'container_type'),
              :top_container_indicator => row[:top_container_indicator],
              :top_container_barcode => row[:top_container_barcode],
              :sub_container_type_2 => EnumMapper.enum_id_to_spreadsheet_value(row[:sub_container_type_2_id], 'container_type'),
              :sub_container_indicator_2 => row[:sub_container_indicator_2],
              :sub_container_barcode_2 => row[:sub_container_barcode_2],
              :sub_container_type_3 => EnumMapper.enum_id_to_spreadsheet_value(row[:sub_container_type_3_id], 'container_type'),
              :sub_container_indicator_3 => row[:sub_container_indicator_3],
            }
          end
        end

        if selected?('digital_object')
          # Digital Object Instances
          #
          # - only support editing one file version per digital object
          #   (or one row per digital object instance)
          seen_file_versions = {}
          db[:instance]
            .join(:instance_do_link_rlshp, Sequel.qualify(:instance_do_link_rlshp, :instance_id) => Sequel.qualify(:instance, :id))
            .join(:digital_object, Sequel.qualify(:digital_object, :id) => Sequel.qualify(:instance_do_link_rlshp, :digital_object_id))
            .left_join(:file_version, Sequel.qualify(:file_version, :digital_object_id) => Sequel.qualify(:digital_object, :id))
            .filter(Sequel.qualify(:instance, :archival_object_id) => batch)
            .filter(Sequel.qualify(:instance, :instance_type_id) => BackendEnumSource.id_for_value('instance_instance_type', 'digital_object'))
            .select(
              Sequel.as(Sequel.qualify(:instance, :archival_object_id), :archival_object_id),
              Sequel.as(Sequel.qualify(:instance_do_link_rlshp, :id), :rlshp_id),
              Sequel.as(Sequel.qualify(:digital_object, :digital_object_id), :digital_object_id),
              Sequel.as(Sequel.qualify(:digital_object, :title), :digital_object_title),
              Sequel.as(Sequel.qualify(:digital_object, :publish), :digital_object_publish),
              Sequel.as(Sequel.qualify(:file_version, :id), :file_version_id),
              Sequel.as(Sequel.qualify(:file_version, :file_uri), :file_version_file_uri),
              Sequel.as(Sequel.qualify(:file_version, :caption), :file_version_caption),
              Sequel.as(Sequel.qualify(:file_version, :publish), :file_version_publish),
              ).each do |row|
            next if seen_file_versions.fetch(row[:rlshp_id], false)

            seen_file_versions[row[:rlshp_id]] = true

            subrecord_datasets[:digital_object] ||= {}
            subrecord_datasets[:digital_object][row[:archival_object_id]] ||= []
            subrecord_datasets[:digital_object][row[:archival_object_id]] << {
              :digital_object_id => row[:digital_object_id],
              :digital_object_title => row[:digital_object_title],
              :digital_object_publish => (row[:digital_object_publish] == 1).to_s,
              :file_version_file_uri => row[:file_version_file_uri],
              :file_version_caption => row[:file_version_caption],
              :file_version_publish => (row[:file_version_publish] == 1).to_s,
            }
          end
        end

        # Related Accessions are special
        if SpreadsheetBuilder.related_accessions_enabled? && selected?('related_accession')
          db[:accession_component_links_rlshp]
            .join(:accession, Sequel.qualify(:accession, :id) => Sequel.qualify(:accession_component_links_rlshp, :accession_id))
            .filter(Sequel.qualify(:accession_component_links_rlshp, :archival_object_id) => batch)
            .select(
              Sequel.qualify(:accession_component_links_rlshp, :archival_object_id),
              Sequel.qualify(:accession, :identifier),
            ).each do |row|
            subrecord_datasets[:related_accession] ||= {}
            subrecord_datasets[:related_accession][row[:archival_object_id]] ||= []

            accession_data = {}
            bits = Identifiers.parse(row[:identifier])
            4.times do |index|
              accession_data[:"id_#{index}"] = bits[index] || ''
            end

            subrecord_datasets[:related_accession][row[:archival_object_id]] << accession_data
          end
        end

        if selected?('langmaterial')
          # lang_material specialness
          db[:lang_material]
            .join(:language_and_script, Sequel.qualify(:language_and_script, :lang_material_id) => Sequel.qualify(:lang_material, :id))
            .filter(Sequel.qualify(:lang_material, :archival_object_id) => batch)
            .select(Sequel.qualify(:lang_material, :archival_object_id),
                    Sequel.qualify(:language_and_script, :language_id),
                    Sequel.qualify(:language_and_script, :script_id))
            .each do |row|
            subrecord_datasets[:language_and_script] ||= {}
            subrecord_datasets[:language_and_script][row[:archival_object_id]] ||= []
            subrecord_datasets[:language_and_script][row[:archival_object_id]] << {
              :language => row[:language_id] ? EnumMapper.enum_id_to_spreadsheet_value(row[:language_id], 'language_iso639_2') : nil,
              :script => row[:script_id] ? EnumMapper.enum_id_to_spreadsheet_value(row[:script_id], 'script_iso15924') : nil,
            }
          end

          db[:lang_material]
            .join(:note, Sequel.qualify(:note, :lang_material_id) => Sequel.qualify(:lang_material, :id))
            .filter(Sequel.qualify(:lang_material, :archival_object_id) => batch)
            .select(Sequel.qualify(:lang_material, :archival_object_id),
                    Sequel.qualify(:note, :notes))
            .each do |row|
            note_json = ASUtils.json_parse(row[:notes])

            subrecord_datasets[:note_langmaterial] ||= {}
            subrecord_datasets[:note_langmaterial][row[:archival_object_id]] ||= []
            subrecord_datasets[:note_langmaterial][row[:archival_object_id]] << {
              :content => Array(note_json['content']).first,
            }
          end
        end

        # Notes
        db[:note]
          .filter(:archival_object_id => batch)
          .select(:archival_object_id, :notes)
          .order(:archival_object_id, :id)
          .each do |row|
          note_json = ASUtils.json_parse(row[:notes])

          note_type = note_json.fetch('type', 'NOT_SUPPORTED').intern

          next unless (MULTIPART_NOTES_OF_INTEREST + SINGLEPART_NOTES_OF_INTEREST).include?(note_type)
          next unless selected?("note_#{note_type}")

          subrecord_datasets[note_type] ||= {}
          subrecord_datasets[note_type][row[:archival_object_id]] ||= []

          note_data = {}

          if MULTIPART_NOTES_OF_INTEREST.include?(note_type)
            text_subnote = Array(note_json['subnotes']).detect {|subnote| subnote['jsonmodel_type'] == 'note_text'}

            note_data[:content] = text_subnote ? text_subnote['content'] : nil
          elsif SINGLEPART_NOTES_OF_INTEREST.include?(note_type)
            note_data[:content] = Array(note_json['content']).first
          end

          self.class.extra_note_fields_for_type(note_type).each do |extra_column|
            target_record = extra_column.property_name.to_s == 'note' ? note_json : note_json.fetch(extra_column.property_name.to_s, {})
            value = Array(target_record.fetch(extra_column.name.to_s, nil)).first

            if extra_column.is_a?(EnumColumn)
              note_data[extra_column.name] = EnumMapper.enum_to_spreadsheet_value(value, extra_column.enum_name)
            else
              note_data[extra_column.name] = extra_column.value_for(value)
            end

          end

          subrecord_datasets[note_type][row[:archival_object_id]] << note_data
        end

        base.each do |row|
          locked_column_indexes = []

          current_row = []

          all_columns.each_with_index do |column, index|
            locked_column_indexes <<  index if column.locked

            if column.jsonmodel == :archival_object
              current_row << ColumnAndValue.new(column.value_for(row[column.column]), column)
            elsif column.is_a?(NoteContentColumn)
              note_content = subrecord_datasets.fetch(column.name, {}).fetch(row[:id], []).fetch(column.index, {}).fetch(:content, nil)
              if note_content
                current_row << ColumnAndValue.new(note_content, column)
              else
                current_row << ColumnAndValue.new(nil, column)
              end
            elsif EXTRA_NOTE_FIELDS.has_key?(column.jsonmodel)
              note_field_value = subrecord_datasets.fetch(column.jsonmodel, {}).fetch(row[:id], []).fetch(column.index, {}).fetch(column.name, nil)
              if note_field_value
                current_row << ColumnAndValue.new(note_field_value, column)
              else
                current_row << ColumnAndValue.new(nil, column)
              end
            else
              subrecord_data = subrecord_datasets.fetch(column.jsonmodel, {}).fetch(row[:id], []).fetch(column.index, nil)
              if subrecord_data
                # FIXME should do this? current_row << ColumnAndValue.new(column.value_for(value), column)
                current_row << ColumnAndValue.new(subrecord_data.fetch(column.name, nil), column)
              else
                current_row << ColumnAndValue.new(nil, column)
              end
            end
          end

          block.call(current_row, locked_column_indexes)
        end
      end
    end
  end
end

# AS-526: Define granular deletion permissions
Permission.define("delete_resource_record",
                  "The ability to delete Resource records",
                  :level => "repository")

Permission.define("delete_accession_record",
                  "The ability to delete Accession records",
                  :level => "repository")

# AS-526: Dynamically override core endpoint permissions using loc-publish-permission helper
ArchivesSpaceService.loaded_hook do
  # Override Resource Delete
  ep_resource = RESTHelpers::Endpoint.find_by_uri("/repositories/:repo_id/resources/:id", [:delete])
  ep_resource.permissions([:delete_resource_record]) if ep_resource

  # Override Accession Delete
  ep_accession = RESTHelpers::Endpoint.find_by_uri("/repositories/:repo_id/accessions/:id", [:delete])
  ep_accession.permissions([:delete_accession_record]) if ep_accession
end

# AS-546: register the title-less-date <unittitle> step for EAD3 export.
EAD3Serializer.add_serialize_step(LocTitlelessDateUnittitle)
