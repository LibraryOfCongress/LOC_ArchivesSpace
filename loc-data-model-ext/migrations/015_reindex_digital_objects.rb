Sequel.migration do
  up do
    # AS-500: Bump system_mtime on digital objects to force a background
    # Solr reindex, applying the new PUI alphabetic title_sort logic
    # to all existing production records.
    self[:digital_object].update(:system_mtime => Time.now)
  end

  down do
  end
end