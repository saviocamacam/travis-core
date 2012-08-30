require 'faraday/error'

module Travis
  module Github
    class Admin
      extend Travis::Instrumentation
      include Travis::Logging

      class << self
        def for_repository(repository)
          new(repository).find
        end
      end

      attr_reader :repository

      def initialize(repository)
        @repository = repository
      end

      def find
        admin = candidates.detect { |user| validate(user) }
        admin || raise_admin_missing
      end
      instrument :find

      private

        def candidates
          User.with_permissions(:repository_id => repository.id, :admin => true)
        end

        def validate(user)
          data = Github.authenticated(user) { repository_data }
          if data['permissions'] && data['permissions']['admin']
            user
          else
            info "[github-admin] #{user.login} no longer has admin access to #{repository.slug}"
            update(user, data['permissions'])
            false
          end
        rescue Faraday::Error::ClientError => error
          handle_error(user, error)
          false
        end

        def handle_error(user, error)
          case error.response.try(:status)
          when 401
            error "[github-admin] token for #{user.login} no longer valid"
            user.update_attributes!(:github_oauth_token => "")
          when 404
            info "[github-admin] #{user.login} no longer has any access to #{repository.slug}"
            update(user, {})
          else
            error "[github-admin] error retrieving repository info for #{repository.slug} for #{user.login}: #{error.inspect}"
          end
        end

        def repository_data
          data = GH["repos/#{repository.slug}"]
          info "[github-admin] could not retrieve data for #{repository.slug}" unless data
          data || { 'permissions' => {} }
        end

        def update(user, permissions)
          user.update_attributes!(:permissions => permissions)
        end

        def raise_admin_missing
          raise Travis::AdminMissing.new("no admin available for #{repository.slug}")
        end


        Travis::Notification::Instrument::Github::Admin.attach_to(self)
    end
  end
end
