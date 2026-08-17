require 'db/migrations/utils'

Sequel.migration do

  up do
    alter_table(:user) do
      add_column(:loc_pdf_scheduler_user, Integer, default: 0)
    end
  end
end
