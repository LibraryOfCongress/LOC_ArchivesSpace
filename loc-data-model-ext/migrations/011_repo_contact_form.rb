require 'db/migrations/utils'

Sequel.migration do

  up do
    alter_table(:agent_contact) do
      add_column(:contact_form, String, :null => true)
    end
  end
end
