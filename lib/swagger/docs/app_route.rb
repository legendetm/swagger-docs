module Swagger
  module Docs
    class AppRoute

      attr_reader :route, :application, :config

      delegate :defaults, :path, :verb, to: :route

      def initialize(config, application, route)
        @config = config
        @application = application
        @route = route
      end

      def route_path
        if defined?(@route.path.spec)
          @route.path.spec
        else
          @route.path
        end
      end

      def mount_path
        return if 1 == applications.size && application == applications[0]
        applications.each do |base_application|
          next if base_application == application

          base_path = base_application.routes.routes.detect do |r|
            r.app == application || r.app.respond_to?(:app) && r.app.app == application
          end
          return path_spec(base_path) if base_path
        end
        nil
      end

      private

      def applications
        @applications ||= Array(@config[:main_application].presence || @config[:applications])
      end

      def path_spec(path)
        if defined?(path.path.spec)
          path.path.spec
        else
          path.path
        end
      end

    end
  end
end
