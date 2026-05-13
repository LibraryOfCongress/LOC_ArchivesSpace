class LocRecordBatch < ASpaceImport::RecordBatch

  def initialize(opts = {})
    super
    @post_serialization_record_filter = ->(record) { true }
  end

  def post_serialization_record_filter=(predicate)
    @post_serialization_record_filter = predicate
  end

  def close
    return if @closed
    flush
    @working_file.close

    @batch_file = ASUtils.tempfile("import_batch_result")

    @batch_file.write("[")

    uris = []
    File.open(@working_file.path).each_with_index do |line, i|
      @batch_file.write(",") unless i == 0

      rec = ASUtils.json_parse(line)
      rec = ASpaceImport::Utils.update_record_references(rec, @uri_remapping)
      @post_serialization_record_filter.call(rec)

      uris << rec['uri']

      @batch_file.write(ASUtils.to_json(rec))
    end

    @working_file.unlink

    @batch_file.write("]")
    @batch_file.close
    @closed = true
  end

  def closest_archival_object
    obj = self.working_area.reverse.find { |o| o.class.record_type == "archival_object" }
    block_given? ? yield(obj) : obj
  end

  def find_by_uri(uri)
    obj = self.working_area.reverse.find { |o| o.uri == uri }
    obj
  end

end
