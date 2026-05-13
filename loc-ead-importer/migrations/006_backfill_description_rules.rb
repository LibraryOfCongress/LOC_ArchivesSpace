Sequel.migration do
  up do
    $stderr.puts "AS-380: Backfilling Description Rules for existing Resource records..."

    # look up the ID for the main enumeration list
    enum = self[:enumeration].filter(:name => 'resource_finding_aid_description_rules').first
    return unless enum
    enum_id = enum[:id]

    # look up the specific integer IDs for our two rules
    dacs_val = self[:enumeration_value].filter(:enumeration_id => enum_id, :value => 'dacs').first
    dcrmg_val = self[:enumeration_value].filter(:enumeration_id => enum_id, :value => 'dcrmg').first

    if dacs_val.nil? || dcrmg_val.nil?
      $stderr.puts "WARNING: 'dacs' or 'dcrmg' values not found. Skipping backfill."
      return
    end

    dacs_id = dacs_val[:id]
    dcrmg_id = dcrmg_val[:id]

    # find the ID for the exact P&P repository
    pnp_repo_ids = self[:repository].filter(:repo_code => 'P&P').select_map(:id)

    if pnp_repo_ids.empty?
      $stderr.puts "Notice: 'P&P' repository not found. Setting all empty rules to DACS."
      self[:resource].filter(:finding_aid_description_rules_id => nil).update(:finding_aid_description_rules_id => dacs_id)
    else
      # update resources IN the P&P repository to DCRMG (only if currently blank)
      self[:resource].filter(:repo_id => pnp_repo_ids, :finding_aid_description_rules_id => nil).update(:finding_aid_description_rules_id => dcrmg_id)
      
      # update all resources NOT in the P&P repository to DACS (only if currently blank)
      self[:resource].exclude(:repo_id => pnp_repo_ids).filter(:finding_aid_description_rules_id => nil).update(:finding_aid_description_rules_id => dacs_id)
    end
    
    $stderr.puts "AS-380: Backfill complete!"
  end

  down do
  end
end