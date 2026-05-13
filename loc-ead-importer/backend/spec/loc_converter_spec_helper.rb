require 'spec_helper'
require 'converter_spec_helper'
require_relative '../converters/loc_ead_converter'

# This helper is here to make it possible to test EAD to JSONModel
# mappings using small snippets of EAD rather than entire EADs.
# By yielding the converter's internal RecordBatch instance to the test,
# we can prime the record batch with the records we would expect to have
# in the hierarchy by the time the snippet was processed.
# When the parser reaches closing tags (e.g., </ead>, </c1>), RecordBatch
# records made when the opening tag was reached are 'popped' into the converter's
# working file. It's helpful to have access to those in the test too, so
# we also yield `records_in_working_file`.
def with_converter_instance(xml)
  input_file = ASUtils.tempfile("test_converter_input")
  input_file.write(xml)
  input_file.close
  converter = LocEADConverter.new(input_file)
  record_batch = converter.instance_variable_get(:@batch)
  record_filter = record_batch.instance_variable_get(:@record_filter)
  records_in_working_file = []
  record_batch.record_filter = ->(record) {
    # hang on to records that get written to the working file
    records_in_working_file << record
    record_filter.call(record)
    true
  }
  yield converter, record_batch, records_in_working_file
  input_file.unlink
end
