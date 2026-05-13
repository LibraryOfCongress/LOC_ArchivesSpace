require 'db/migrations/utils'

Sequel.migration do
  up do
    # The LOC dev server got into a state where it thought this
    # migrartion had not been run - so we make this migration
    # optional
    unless schema(:digital_object).map(&:first).include?(:ead_dao_type)
      alter_table(:digital_object) do
        add_column(:ead_dao_type, String)
      end
    end
    unless schema(:digital_object).map(&:first).include?(:other_ead_dao_type)
      alter_table(:digital_object) do
        add_column(:other_ead_dao_type, String)
      end
    end
  end
end
