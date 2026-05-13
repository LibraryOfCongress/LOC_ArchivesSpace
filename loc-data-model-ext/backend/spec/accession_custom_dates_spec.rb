require 'spec_helper'

describe 'Accession Custom Date Fields' do

  it "persists custom library, received, and division acquisition dates" do
    # Define the data for the accession, including the custom date fields
    # Using static IDs
    # A repo_id is needed; this gets a global or creates one.
    repo_id = Repository.global_repo_id || Repository.create_with_global_repo[:id]
    
    accession_data = {
      :title => "Test Accession with All Custom Dates",
      :id_0 => "LOC_DATES_001", 
      :accession_date => "2025-01-01",
      :repo_id => repo_id,
      :date_received_by_library => "2025-02-15",
      :division_acquisition_date => "2025-03-01"
    }

    # Create the accession record
    # The .id is retrieved from the created record object.
    accession_id = Accession.create_from_json(JSONModel(:accession).from_hash(accession_data)).id
    
    # Fetch the persisted record directly using the Sequel model
    fetched_accession = Accession[accession_id]

    # Verify each custom date field
    # Using .to_s to ensure comparison is against "YYYY-MM-DD" string format
    expect(fetched_accession.date_received_by_library.to_s).to eq("2025-02-15")
    expect(fetched_accession.division_acquisition_date.to_s).to eq("2025-03-01")
  end

end
