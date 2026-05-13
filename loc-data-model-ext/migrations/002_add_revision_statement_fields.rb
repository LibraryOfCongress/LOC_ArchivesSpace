require 'db/migrations/utils'

Sequel.migration do
  up do
    alter_table(:revision_statement) do
      add_column(:agent, String)
      add_column(:agent_type, String)
      add_column(:type, String)
    end
  end
end
