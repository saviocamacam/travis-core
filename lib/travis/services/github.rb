module Travis
  module Services
    module Github
      autoload :FetchConfig, 'travis/services/github/fetch_config'
      autoload :FindAdmin,   'travis/services/github/find_admin'
      autoload :SyncUser,    'travis/services/github/sync_user'

      class << self
        def setup(config = Travis.config.oauth2)
          GH.set :client_id => config[:client_id], :client_secret => config[:client_secret] if config
        end

        def authenticated(user, &block)
          fail "we don't have a github token for #{user.inspect}" if user.github_oauth_token.blank?
          GH.with(:token => user.github_oauth_token, &block)
        end
      end
    end
  end
end
