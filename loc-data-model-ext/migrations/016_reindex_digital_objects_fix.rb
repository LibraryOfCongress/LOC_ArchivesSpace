Sequel.migration do
  up do
    # AS-500: Bump system_mtime on digital objects to force a background Solr reindex.
    # The previous 015 migration bypassed the sorting hook because it was bound
    # strictly to the PUIIndexer. This run should correctly apply the 'zzzz' prefix logic.
    
    db_table = self[:digital_object]
    max_id = db_table.max(:id) || 0
    current_id = 0
    batch_size = 5000

    while current_id <= max_id
      db_table.where { id >= current_id }.where { id < current_id + batch_size }.update(:system_mtime => Time.now)
      current_id += batch_size
    end
  end

  down do
  end
end