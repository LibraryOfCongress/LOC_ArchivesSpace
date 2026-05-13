require 'db/migrations/utils'

Sequel.migration do
  up do
    alter_table(:archival_object) do
      add_column(:additional_identifiers, :json, :null => true)
    end
  end
end
