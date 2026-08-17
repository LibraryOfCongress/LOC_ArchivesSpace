class SchedulerState

  def initialize(state_dir = "scheduler_state")
    @state_dir = File.join(AppConfig[:data_directory], state_dir)
  end

  def path_for
    FileUtils.mkdir_p(@state_dir)
    File.join(@state_dir, "last_run.dat")
  end

  def set_last_time(time)
    path = path_for

    File.open("#{path}", "w") do |fh|
      fh.puts(time.to_i)
    end
  end


  def get_last_time
    path = path_for

    begin
      File.open("#{path}", "r") do |fh|
        fh.readline.to_i
      end
    rescue Errno::ENOENT
      # If we've never generated pdfs, generate everything
      0
    end
  end
end
