require_relative 'indexer_common_ext.rb'

if defined?(PUIIndexer)
  PUIIndexer.add_indexer_initialize_hook do |indexer|
    indexer.add_document_prepare_hook do |doc, record|
      IndexerCommon.generate_alpha_title_sort(doc, record)
    end
  end
end
