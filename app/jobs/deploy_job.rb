class DeployJob < BackgroundJob
  @queue = :deploys

  def perform(params)
    @deploy = Deploy.find(params[:deploy_id])
    @deploy.run!
    commands = StackCommands.new(@deploy.stack)

    capture commands.fetch
    capture commands.clone(@deploy)
    Dir.chdir(@deploy.working_directory) do
      capture commands.checkout(@deploy.until_commit)
      Bundler.with_clean_env do
        capture commands.bundle_install
        capture commands.deploy(@deploy.until_commit)
      end
    end
    @deploy.complete!
  rescue StandardError => e
    begin
      @deploy.failure! if @deploy
    rescue
      Rails.logger.error "Unable to mark job as failed!"
    end
    raise e
  end

  def capture(command)
    @deploy.write("$ #{command.to_s}\n")
    command.stream! do |line|
      @deploy.write(line)
    end
    @deploy.write("\n")
  end

end