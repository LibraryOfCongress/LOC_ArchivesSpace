class IndexerCommon

  def index_records(records, timing = IndexerTiming.new)
    batch = IndexBatch.new

    records = dedupe_by_uri(records)

    timing.time_block(:conversion_ms) do
      records.each do |record|
        values = record['record']
        uri = record['uri']

        reference = JSONModel.parse_reference(uri)
        record_type = reference && reference[:type]

        if !record_type || skip_index_record?(record) || (record_type != 'repository' && !record_types.include?(record_type.intern))
          next
        end

        doc = {}

        doc['id'] = uri
        doc['uri'] = uri
        doc['title'] =  values['title']
        doc['primary_type'] = record_type
        doc['types'] = [record_type]
        doc['json'] = ASUtils.to_json(sanitize_json(values))
        doc['suppressed'] = values.has_key?('suppressed') && values['suppressed']
        if doc['suppressed']
          doc['publish'] = false
        elsif is_repository_unpublished?(uri, values)
          doc['publish'] = false
        elsif values['has_unpublished_ancestor']
          doc['publish'] = false
        else
          doc['publish'] = values.has_key?('publish') && values['publish']
        end
        doc['system_generated'] = values.has_key?('system_generated') ? values['system_generated'].to_s : 'false'
        doc['repository'] = get_record_scope(uri)

        @document_prepare_hooks.each do |hook|
          hook.call(doc, record)
        end

        if ( !values["finding_aid_filing_title"].nil? && values["finding_aid_filing_title"].length > 0 )
          doc['title_sort'] ||= clean_for_sort(values["finding_aid_filing_title"])
        else
          doc['title_sort'] ||= clean_for_sort(values['title'])
        end

        # do this last of all so we know for certain the doc is published
        apply_pui_fields(doc, record)

        next if skip_index_doc?(doc)

        batch << clean_whitespace(doc)

        # Allow a single record to spawn multiple Solr documents if desired
        @extra_documents_hooks.each do |hook|
          batch.concat(hook.call(record))
        end
      end
    end

    index_batch(batch, timing)

    timing
  end

end
