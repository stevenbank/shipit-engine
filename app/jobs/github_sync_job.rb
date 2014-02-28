class GithubSyncJob < BackgroundJob
  extend Resque::Plugins::Lock

  @queue = :default

  MAX_PAGES = 2

  def perform(params)
    @stack = Stack.find(params[:stack_id])
    repo  = @stack.github_repo

    commits = fetch_missing_commits(repo.rels[:commits])
    commits.reverse.each do |gh_commit|
      @stack.commits.from_github(gh_commit, fetch_state(gh_commit)).save!
    end
  end

  def fetch_missing_commits(relation)
    commits = []

    MAX_PAGES.times do
      resource = relation.get
      resource.data.map do |commit|
        return commits if known?(commit.sha)
        commits << commit
      end

      relation = resource.rels[:next]
      break if relation.nil?
    end

    commits
  end

  protected

  def fetch_state(commit)
    Shipit.github_api.statuses(@stack.github_repo_name, commit.sha).last.try(:state)
  end

  def known?(sha)
    @stack.commits.where(sha: sha).exists?
  end

end