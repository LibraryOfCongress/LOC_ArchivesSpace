require 'fileutils'
require_relative '../find_public_pdf_dir'
require_relative '../loc_pdf_scheduler_user'

LOC_PDF_PUBLISHED_DIR = LocPDFDirectoryFinder.loc_pdf_published_dir
LOC_PDF_SCHEDULER_USERNAME = LocPDFSchedulerUser.username

class User

  def self.LOC_PDF_SCHEDULER_USERNAME
    AppConfig.has_key?(:loc_pdf_scheduler_username) && AppConfig[:loc_pdf_scheduler_username] || "loc_pdf_scheduler_user"
  end
end

class Group

  def self.LOC_PDF_SCHEDULER_GROUP_CODE
    'loc_pdf_scheduler'
  end

  def self.LOC_PDF_SCHEDULER_GROUP_PERMISSIONS
      ["view_all_records", "create_job"]
  end
end

# sanity check - there should never be more than 1 api user account
if User.filter(loc_pdf_scheduler_user: 1).count > 1
  raise "There are appears to be more than 1 user flagged as `loc_pdf_scheduler_user`. \
Check the user table in the database."
end

if loc_user = User.find(loc_pdf_scheduler_user: 1)
  loc_user.username = User.LOC_PDF_SCHEDULER_USERNAME
  loc_user.save
else
  User.create_from_json(JSONModel(:user).from_hash(username: User.LOC_PDF_SCHEDULER_USERNAME,
                                                   name: "LOC PDF Scheduler User"),
                        {
                          source: "local",
                          is_system_user: 1,
                          is_hidden_user: 1,
                          loc_pdf_scheduler_user: 1
                        })
end

if AppConfig.has_key?(:loc_pdf_scheduler_user_secret)
  DBAuth.set_password(User.LOC_PDF_SCHEDULER_USERNAME, AppConfig[:loc_pdf_scheduler_user_secret])
end

ArchivesSpaceService.create_group(Group.LOC_PDF_SCHEDULER_GROUP_CODE, "LOC API User Group", [User.LOC_PDF_SCHEDULER_USERNAME],
                                  Group.LOC_PDF_SCHEDULER_GROUP_PERMISSIONS)

group = Group[group_code: Group.LOC_PDF_SCHEDULER_GROUP_CODE]

group.remove_all_permission
Group.LOC_PDF_SCHEDULER_GROUP_PERMISSIONS.each do |permission_code|
  group.grant(permission_code)
end
group.save


# add permissions to export plugin controller
ArchivesSpaceService.loaded_hook do
  update_feed_ctrl = RESTHelpers::Endpoint.find_by_uri("/resource-update-feed", [:get])
  update_feed_ctrl.permissions([:view_all_records])
end


# * Overrides to support unpublished content in PDFs *

JSONModel(:print_to_pdf_job).add_validation("no_unpubished_published_pdf") do |hash|
  errors = hash["include_unpublished"] && hash["publish_to_pui"] ? [["include_unpublished", "cannot be checked when publishing to PUI"]] : []
  errors
end

class Resource

  def include_unpublished!
    @include_unpublished = true
  end

  def include_unpublished?
    @include_unpublished ||= false
    @include_unpublished
  end
end

module Trees

  alias_method :apply_exclusions_to_descendants_orig, :apply_exclusions_to_descendants

  # excluding unpublished content is baked into the
  # ordered_records generator, so we just cheat a bit
  # and wipe out the exclusions after the fact.
  def apply_exclusions_to_descendants(excluded_rows, parent_to_child_id)
    if self.respond_to?(:include_unpublished?) && self.include_unpublished?
      return {}
    else
      apply_exclusions_to_descendants_orig(excluded_rows, parent_to_child_id)
    end
  end
end
