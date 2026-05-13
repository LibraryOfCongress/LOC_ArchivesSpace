require 'db/migrations/utils'

Sequel.migration do

  new_langs = { kfk: "Kinnauri", bod: "Tibetan" }

  up do
    $stderr.puts("Adding updated ISO 639-2 language codes found in Linda LaMacchia collection")
    enum = self[:enumeration].filter(:name => 'language_iso639_2').select(:id)
    new_langs.each do |code, language|
      rows = self[:enumeration_value].filter(:value => code.to_s, :enumeration_id => enum ).select(:id).all
      if rows.length == 0
        position = self[:enumeration_value].filter(
          enumeration_id: enum
        ).max(:position) + 1
        $stderr.puts("Adding #{language}")
        self[:enumeration_value].insert(:enumeration_id => enum, :value => code.to_s, :position => position)
      end
    end
  end
end
