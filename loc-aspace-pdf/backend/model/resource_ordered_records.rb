require_relative 'record'
module PDF
  class ResourceOrderedRecords < Record

    attr_reader :entries

    Entry = Struct.new(:uri, :display_string, :depth, :level)

    def initialize(*args)
      super

      @entries = Array(json['uris']).map {|entry| entry.stringify_keys}
                   .map {|entry| Entry.new(entry.fetch('ref'),
                                           entry.fetch('display_string'),
                                           entry.fetch('depth'),
                                           entry.fetch('level'))}
    end
  end
end
