require 'db/migrations/utils'

Sequel.migration do

  # List of old_code => [ new_code, descriptive_label ]
  RENAMED_CODES = {
    tib: ["bod", "Tibetan"],
    cze: ["ces", "Czech"],
    wel: ["cym", "Welsh"],
    ger: ["deu", "German"],
    gre: ["ell", "Greek, Modern (1453–)"],
    baq: ["eus", "Basque"],
    per: ["fas", "Persian"],
    fre: ["fra", "French"],
    arm: ["hye", "Armenian"],
    ice: ["isl", "Icelandic"],
    geo: ["kat", "Georgian"],
    mac: ["mkd", "Macedonian"],
    mao: ["mri", "Maori"],
    may: ["msa", "Malay"],
    bur: ["mya", "Burmese"],
    dut: ["nld", "Dutch"],
    rum: ["ron", "Romanian"],
    slo: ["slk", "Slovak"],
    alb: ["sqi", "Albanian"],
    chi: ["zho", "Chinese"]
  }

  # Codes to insert if missing
  NEW_LANGS = {
    kfk: "Kinnauri",
    khb: "Lü"
  }

  up do
    $stderr.puts("[loc-iso-lang-updates] Merging older codes → new codes and adding new codes")

    # Find the 'language_iso639_2' enumeration ID
    enum = self[:enumeration].filter(:name => 'language_iso639_2').select(:id).first
    unless enum
      raise "Enumeration 'language_iso639_2' not found. Migration aborted."
    end

    # Merge/rename older codes to newer
    RENAMED_CODES.each do |old_code, (new_code, _label)|
      # Find rows with old_code
      old_rows = self[:enumeration_value]
                   .filter(:value => old_code.to_s, :enumeration_id => enum[:id])
                   .select(:id)
                   .all
      next if old_rows.empty?

      # Check if there's a separate row(s) with new_code
      conflict_rows = self[:enumeration_value]
                        .filter(:value => new_code, :enumeration_id => enum[:id])
                        .all


      # Remove the conflict row(s) (i.e., any row that already has new_code),
      # so we can rename old_code -> new_code without duplication error.
      conflict_rows.each do |conflict|
        # if a new code has been added and is already in use, need to revert foreign
        # keys to the the old code id before proceeding to delete.
        self[:language_and_script].where(:language_id => conflict[:id]).update(:language_id => old_rows.first[:id])
        self[:resource].where(:finding_aid_language_id => conflict[:id]).update(:finding_aid_language_id => old_rows.first[:id])
        # Only remove if it's a *different* row (not the same row being renamed).
        unless old_rows.map{|r| r[:id]}.include?(conflict[:id])
          $stderr.puts("Deleting existing row with code '#{new_code}' (ID=#{conflict[:id]}) to allow merge.")
          self[:enumeration_value].where(:id => conflict[:id]).delete
        end
      end

      # Rename all old_code rows to new_code
      old_rows.each do |row|
        $stderr.puts("Renaming '#{old_code}' => '#{new_code}' (enumeration_value.id=#{row[:id]})")
        self[:enumeration_value].where(:id => row[:id]).update(:value => new_code)
      end
    end

    # Insert new codes if missing
    NEW_LANGS.each do |code, language|
      existing = self[:enumeration_value]
                    .filter(:value => code.to_s, :enumeration_id => enum[:id])
                    .select(:id)
                    .all
      if existing.empty?
        position = self[:enumeration_value]
                     .filter(:enumeration_id => enum[:id])
                     .max(:position).to_i + 1

        $stderr.puts("Inserting #{language} (code='#{code}') at position=#{position}")
        self[:enumeration_value].insert(
          :enumeration_id => enum[:id],
          :value          => code.to_s,
          :position       => position
        )
      else
        $stderr.puts("Code '#{code}' => '#{language}' already exists (#{existing.length} row(s)). Skipping.")
      end
    end
  end
end
