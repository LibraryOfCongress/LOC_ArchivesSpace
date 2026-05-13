require 'tempfile'
require 'csv'

class LocImportFolioRestrictionsRunner < JobRunner

  register_for_job_type('loc_import_folio_restrictions_job', :create_permissions => :import_records,
                        :cancel_permissions => :cancel_importer_job)

  OFFSITE_WORDS = ["fort meade", "cabin branch", "landover"]

  def run
    @job.write_output("Starting Folio Restrictions Import Job\n")

    if @job.job_files.length != 1
      @job.write_output("\nNo spreadsheet found.\n")
      @job.finish!(:failed)

      raise Exception.new('No spreadsheet found.')
    end

    spreadsheet = @job.job_files[0]
    repos = {}
    report = [["REPOSITORY", "RECORD URL", "RESTRICTIONS", "SPATIAL_RESTRICTIONS"]]

    begin
      RequestContext.open(:current_username => @job.owner.username,
                          :repo_id => @job.repo_id) do

        DB.open(true) do
          CSV.read(spreadsheet.full_file_path).each_with_index do |row, i|
            if i == 0
              validate_headers(row)
            else
              lccn, restricted, _, restricted_int, location = row
              set_restricted_true = restricted.strip.downcase == "restricted"
              set_restricted_false = restricted.strip.downcase == "not restricted"
              set_spatial = OFFSITE_WORDS.any? {|word| location.include? word }
              if resource = Resource[lccn: lccn]
                needs_save = false
                if set_restricted_true && resource.restrictions != 1
                  resource.restrictions = 1
                  needs_save = true
                elsif set_restricted_false && resource.restrictions == 1
                  resource.restrictions = 0
                  needs_save = true
                end
                if set_spatial && resource.spatial_restrictions != 1
                  resource.spatial_restrictions = 1
                  needs_save = true
                end
                if needs_save
                  resource.save
                  repo_id = resource.repo_id
                  repos[repo_id] ||= Repository[id: repo_id]
                  report << [repos[repo_id].repo_code, "#{AppConfig[:frontend_proxy_url]}/resources/#{resource.id}", set_restricted_true, set_spatial]
                  @job.write_output("Updated #{resource.title}")
                end
              end
            end
          end
        end

        Tempfile.open("loc_import_folio_restrictions_report") do |file|
          report.each do |row|
            file.write CSV.generate_line(row)
          end
          file.close
          @job.add_file(file)
        end

        @job.job_files[0].delete
        @job.save
        @job.finish!(:completed)
        self.success!
      end
    rescue => e
      Log.exception(e)
      @job.write_output("Unexpected failure while running @job. Error: #{e}")

      @job.finish!(:failed)
      raise e
    end
  end

  private

  def validate_headers(row)
    unless row[0] == "lccn"
      raise "First column must be named 'lccn'"
    end
    unless row[3] == "restrictions"
      raise "Fourth column must be named 'restrictions'"
    end
    unless row[4] == "locations"
      raise "Fifth column must be named 'locations'"
    end
  end
end
