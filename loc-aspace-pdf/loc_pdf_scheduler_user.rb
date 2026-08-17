require 'config/config-distribution'

class LocPDFSchedulerUser
  def self.username
    AppConfig.has_key?(:loc_pdf_scheduler_username) && AppConfig[:loc_pdf_scheduler_username] || "loc_pdf_scheduler_user"
  end
end
