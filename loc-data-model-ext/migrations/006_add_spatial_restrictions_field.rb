require 'db/migrations/utils'

Sequel.migration do

  up do
    alter_table(:resource) do
      add_column(:spatial_restrictions, Integer, default: 0)
    end
  end
end
