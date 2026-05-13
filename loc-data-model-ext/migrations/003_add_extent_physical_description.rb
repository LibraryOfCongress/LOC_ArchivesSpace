require 'db/migrations/utils'

Sequel.migration do
  up do
    alter_table(:extent) do
      add_column(:physical_description, String)
    end
  end
end
