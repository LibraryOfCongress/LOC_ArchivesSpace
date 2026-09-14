module JSONModel::Validations
  if JSONModel(:accession)
    JSONModel(:accession).add_validation("loc_disable_accession_publication") do |hash|
      loc_disable_accession_publication(hash)
    end
  end


  def self.loc_disable_accession_publication(hash)
    errors = []
    if hash["publish"]
      errors << ["publish", "accession publication not allowed"]
    end

    errors
  end
end
