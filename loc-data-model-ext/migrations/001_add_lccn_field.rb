require 'db/migrations/utils'

Sequel.migration do

  up do
    alter_table(:resource) do
      add_column(:lccn, String, :null => true)
    end

    alter_table(:accession) do
      add_column(:lccn, String, :null => true)
    end
  end
end
