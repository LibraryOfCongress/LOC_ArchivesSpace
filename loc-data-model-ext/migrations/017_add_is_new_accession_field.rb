require 'db/migrations/utils'

Sequel.migration do

  up do
    alter_table(:accession) do
      add_column(:is_new, Integer, default: 0)
    end
  end
end
