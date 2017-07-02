module Swagger
  module Docs
    class AppRoute

      attr_reader :route, :application

      delegate :defaults, :path, :verb, to: :route

      def initialize(application, route)
       @route = route
       @application = application
      end

      def route_path
        if defined?(@route.path.spec)
          @route.path.spec
        else
          @route.path
        end
      end

      def mount_path
        return if application == Config.base_application
        base_path = Config.base_application.routes.routes.detect do |r|
          r.app == application || r.app.app == application
        end
        return unless base_path

        if defined?(base_path.path.spec)
          base_path.path.spec
        else
          base_path.path
        end
      end

    end
  end
end
