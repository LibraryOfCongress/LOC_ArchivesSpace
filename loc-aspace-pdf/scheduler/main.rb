require 'logger'
require 'ashttp'
require 'asutils'
require 'config/config-distribution'
require 'json'
# this is important for auto-setting the data directory
require 'launcher_init'
require_relative '../loc_pdf_scheduler_user'
require_relative '../find_public_pdf_dir'
require_relative 'scheduler_state'

LOC_PDF_PUBLISHED_DIR = LocPDFDirectoryFinder.loc_pdf_published_dir

# subtract two minutes from the last check to make
# sure we catch everything
UPDATE_MARGIN_SECONDS = 120

# need to rethink this for deployment
ASPACE_API_URL = AppConfig[:backend_url]

SCHEDULER_USER = LocPDFSchedulerUser.username
SCHEDULER_SECRET = AppConfig[:loc_pdf_scheduler_user_secret]

class AccessDeniedError < StandardError
end

logfile = File.join(ASUtils.find_base_directory, "logs", "loc_pdf_scheduler.log")
$logger = Logger.new(logfile)

def run
  state = SchedulerState.new
  last_start_time = state.get_last_time - UPDATE_MARGIN_SECONDS
  now = Time.now

  $logger.info("Scheduler Running at #{now} for updates since #{Time.at(last_start_time)}")
  base_uri = URI(ASPACE_API_URL)
  login_uri = URI("#{ASPACE_API_URL}/users/#{SCHEDULER_USER}/login")
  update_feed_uri = URI("#{ASPACE_API_URL}/resource-update-feed?timestamp=#{last_start_time}")
  result = nil

  ASHTTP.start_uri(base_uri) do |http|
    req = Net::HTTP::Post.new(login_uri.path)
    req.set_form_data(password: SCHEDULER_SECRET)
    response = http.request(req)
    session = JSON.parse(response.body).fetch("session")
    headers = {"X-ArchivesSpace-Session": session}

    req = Net::HTTP::Get.new(update_feed_uri.request_uri, headers)
    response = http.request(req)
    result = JSON.parse(response.body)
    if result.has_key?('adds')
      result['adds'].each do |rec|
        $logger.info("Adding #{rec['title']}")
        job = {
          jsonmodel_type: "job",
          job: {
            jsonmodel_type: "print_to_pdf_job",
            source: rec['uri'],
            publish_to_pui: true
          }
        }
        req = Net::HTTP::Post.new("/repositories/#{rec['repo_id']}/jobs")
        req['X-ArchivesSpace-Session'] = session
        req['Content-Type'] = 'text/json'
        req.body = job.to_json
        res = http.request(req)
        if res.code =~ /^4/
          raise AccessDeniedError.new(res)
        end
        id = JSON.parse(res.body).fetch("id")
        $logger.info("PDF Job created with id: #{id}")
      end
    end
  end
  state.set_last_time(now)
end


begin
  run
rescue AccessDeniedError => e
  $logger.fatal("Access Error Prevented Scheduler from Running!")
  $logger.debug(e.inspect)
end
