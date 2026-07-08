require_relative 'indexer_common_ext.rb'

# Bind directly to IndexerCommon so the background indexer queue 
# executes this hook when processing the database.
if defined?(IndexerCommon)
  IndexerCommon.add_indexer_initialize_hook do |indexer|
    indexer.add_document_prepare_hook do |doc, record|
      IndexerCommon.generate_alpha_title_sort(doc, record)
    end
  end
end