class LocDeleteRepositoryRunner < JobRunner

  register_for_job_type('loc_delete_repository_job', :create_permissions => :delete_repository)

  def run
    ticker = Ticker.new(@job)

    repo_id_to_delete = Repository[repo_code: @job.job['repository']].id
    passphrase = @job.job['secret']

    begin
      raise "Can't find repository" unless repo_id_to_delete
      raise "Can't delete repository that is currently selected" unless repo_id_to_delete != @job.repo_id
      raise "Wrong passphrase" unless passphrase == "deleteit!"
      raise "Indexer must be disabled!" unless AppConfig[:enable_indexer] == false

      ticker.log("Deleting Repository #{@job.job['repository']}")
      repo = Repository.get_or_die(repo_id_to_delete)
      agent_id = repo.agent_representation_id
      agent = AgentCorporateEntity.get_or_die(agent_id)
      RequestContext.open(repo_id: repo.id, current_username: @job.owner.username) do
        repo.delete
        agent.delete
      end
      ticker.log("Deletion of repository #{repo_id_to_delete} is complete.")
    rescue Exception => e
      ticker.log("Migration failed: #{e.inspect}")
      e.backtrace.each do |line|
        ticker.log(line)
      end
      raise e
    end
  end

end
