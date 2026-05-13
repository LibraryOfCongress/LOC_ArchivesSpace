require 'db/migrations/utils'

Sequel.migration do

  up do
    # Check for date_received_by_library before adding
    unless schema(:accession).map(&:first).include?(:date_received_by_library)
      alter_table(:accession) do
        add_column(:date_received_by_library, Date, null: true)
      end
    end

    # Check for division_acquisition_date before adding
    unless schema(:accession).map(&:first).include?(:division_acquisition_date)
      alter_table(:accession) do
        add_column(:division_acquisition_date, Date, null: true)
      end
    end
  end
end