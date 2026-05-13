require 'tempfile'
require 'benchmark'
require 'csv'

REPO_DIRECTORIES = {
  "AFC" => "afc",
  "MI" => "mbrsmi",
  "G&M" => "gmd",
  "VHP" => "vhp",
  "RS" => "mbrsrs",
  "RBSC" => "rbc",
  "MUS" => "music",
  "P&P" => "pnp",
  "MSS" => "mss",
  "asian" => "asian",
  "eur" => "eur",
  "gdc" => "gdc",
  "hisp" => "hisp",
  "lca" => "lca"
}

EXCLUDE_FILENAMES = ['mu002006.xml', 'ms017015.xml', 'ms019044.xml', 'ms009006.xml', 'ms001028.xml']

class NoMultiThreadedBackgroundJobs < StandardError
end


class LocEadMigratorRunner < JobRunner

  register_for_job_type('loc_ead_migrator_job', :create_permissions => :import_records,
                        :cancel_permissions => :cancel_importer_job)

  class QuietTicker < Ticker
    alias_method :log_orig, :log

    # The Streaming JSON importer makes a log entry for every
    # record it creates. For batches this results in excessively huge logs.
    def log(s)
      unless s =~ /^Created:/
        log_orig(s)
      end
    end
  end


  def run
    ticker = QuietTicker.new(@job)
    unless AppConfig[:job_thread_count] == 1
      ticker.log("AppConfig[:job_thread_count] must be set to 1 to run this job")
      raise NoMultiThreadedBackgroundJobs.new
    end
    last_error = nil
    begin
      ead_dirs = AppConfig[:loc_ead_migrator_ead_dirs]
      report = []
      report << [ "SOURCE", "FILENAME", "FILESIZE", "CONVERSION TIME", "MESSAGE" ]
      seen_filenames = Set.new
      ticker.log("starting batch conversion for #{ead_dirs.join(', ')}")
      Dir.glob(ead_dirs.map { |d| "#{d}/*" }).select { |e| File.directory?(e) }.each do |ead_subdir|
        next unless REPO_DIRECTORIES[@job.job["repository"]] == File.basename(ead_subdir) || @job.job["repository"] == File.basename(ead_subdir)
        ticker.log("process directory: #{ead_subdir}")
        repo_code = @job.job["repository"]
        # ensure the repository exists
        repo = Repository.find(:repo_code => repo_code)
        if repo.nil?
          raise "please create repository #{repo_code} before running this job"
        end
        job_repo = Repository[@job.repo_id]
        if repo_code.downcase != job_repo.repo_code.downcase
          raise "please select the #{repo_code} repo before running this job for this repository."
        end

        Dir.glob("#{ead_subdir}/**/*.xml").each do |ead_file|
          ead_filename = File.basename(ead_file)
          ead_source = File.dirname(ead_file)
          next if seen_filenames.include? ead_filename
          if EXCLUDE_FILENAMES.include? ead_filename
            report << [ ead_source, ead_filename, "---", "SKIPPED", "file has been flagged for exclusion from batch import" ]
            next
          end
          seen_filenames.add ead_filename
          ead_filesize = File.size(ead_file) / 1024
          resource_uri = nil
          ticker.log("Converting #{ead_filename} \n")
          converter = Converter.for('loc_ead_xml', ead_file, { import_events: true, import_subjects: true })
          converer.publish_finding_aids_by_default!
          begin
            time_report = []
            RequestContext.open(:create_enums => true,
                                :current_username => @job.owner.username,
                                :repo_id => repo.id) do
              time_report << Benchmark.measure("converter:") do
                converter.run
              end
              time_report << Benchmark.measure("importer:") do
                File.open(converter.get_output_path, "r") do |fh|
                  batch = StreamingImport.new(fh, ticker, @import_canceled)
                  DB.open(DB.supports_mvcc?,
                          :retry_on_optimistic_locking_fail => true) do
                    batch.process
                  end
                  if batch.created_records
                    resource_uri = batch.created_records.values.last
                    log_created_uris([resource_uri])
                  end
                  success = true
                end
              end
            end
            time_report = time_report.map{ |tms| tms.format("%-12n%r") }.join("\n")
            ticker.log("Conversion of #{ead_filename} succeeded. Created #{resource_uri}")
            report << [ ead_source, ead_filename, ead_filesize, time_report, resource_uri ]
          rescue Exception => e
            message = if e.is_a? JSONModel::ValidationException
                        e.errors.reduce("") { |m, (k, v)| m << "#{k}: #{v.join('; ')}\n" }
                      else
                        e.inspect
                      end
            ticker.log("Conversion of  #{ead_filename} failed.")
            ticker.log(message)
            report << [ ead_source, ead_filename, ead_filesize, "FAILED", message ]
          ensure
            converter.remove_files
          end
        end
      end

      self.success!

      Tempfile.open("loc_ead_migrator_report") do |file|
        report.each do |row|
          file.write CSV.generate_line(row)
        end
        file.close
        @job.add_file(file)
      end

    rescue Exception => e
      ticker.log("Migration failed: #{e.inspect}")
      raise e
    end
  end

  private

  def log_created_uris(uris)
    if !uris.empty?
      DB.open do |db|
        @job.record_created_uris(uris)
      end
    end
  end

end
