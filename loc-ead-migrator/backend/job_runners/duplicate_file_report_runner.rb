require 'tempfile'
require 'csv'

class LocDuplicateFileReportRunner < JobRunner

  register_for_job_type('loc_duplicate_file_report_job', :create_permissions => :import_records,
                        :cancel_permissions => :cancel_importer_job)

  def run
    ticker = Ticker.new(@job)
    last_error = nil
    begin
      ead_dirs = AppConfig[:loc_ead_migrator_ead_dirs].reject { |ead_dir| ead_dir =~ /incoming$/ }
      report = []
      report << [ "FILENAME", "FILEPATHS" ]
      seen_filenames = Set.new
      duplicates = Set.new
      duplicates_to_report = {}
      Dir.glob(ead_dirs.map { |d| "#{d}/*" }).select { |e| File.directory?(e) }.each do |ead_subdir|
        ticker.log("process directory: #{ead_subdir}")
        Dir.glob("#{ead_subdir}/**/*.xml").each do |ead_file|
          ead_filename = File.basename(ead_file)
          ead_source = File.dirname(ead_file)
          if seen_filenames.include? ead_filename
            duplicates.add ead_filename
          else
            seen_filenames.add ead_filename
          end
        end
      end
      Dir.glob(ead_dirs.map { |d| "#{d}/*" }).select { |e| File.directory?(e) }.each do |ead_subdir|
        Dir.glob("#{ead_subdir}/**/*.xml").each do |ead_file|
          ead_filename = File.basename(ead_file)
          next unless duplicates.include? ead_filename
          duplicates_to_report[ead_filename] ||= []
          duplicates_to_report[ead_filename] << ead_file
        end
      end

      self.success!

      Tempfile.open("loc_ead_migrator_report") do |file|
        duplicates_to_report.each do |ead_file, duplicates|
          file.write CSV.generate_line([ead_file, duplicates.join("\n")])
        end
        file.close
        @job.add_file(file)
      end

    rescue Exception => e
      ticker.log("Migration failed: #{e.inspect}")
      raise e
    end
  end
end
