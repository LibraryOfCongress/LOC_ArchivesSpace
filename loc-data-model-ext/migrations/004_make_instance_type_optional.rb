require 'db/migrations/utils'

Sequel.migration do
  up do
    alter_table(:instance) do
      set_column_allow_null :instance_type_id
    end
  end
end
