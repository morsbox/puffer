module Puffer
  module Component

    # <tt>Puffer::Component::Base</tt> is a base component low-level for puffer
    # fields. It provides all the base functionality for rendering visual fields
    # components.
    # Every component belongs to field by field's type
    # Every component should have some basic actions, based on parent controller
    # fieldsets, so they can be fallbacked as fieldsets.
    #
    # Also, every component can have additional actions for ajax requests
    # handling and component state changing
    class Base < AbstractController::Base

      abstract!

      module ClassMethods
        def controller_path
          @controller_path ||= name.sub(/Component$/, '').underscore unless anonymous?
        end
      end

      extend ClassMethods

      include AbstractController::Rendering
      include AbstractController::Translation
      include AbstractController::Logger
      include AbstractController::Layouts
      include ActionController::Helpers

      include ActionController::RequestForgeryProtection
      include ActionController::UrlFor
      include Rails.application.routes.url_helpers

      helper 'puffer/helpers/component', 'puffer/helpers/puffer'

      attr_reader :parent_controller, :field, :identifer, :record, :records, :resource, :opts
      delegate :env, :request, :params, :session, :to => :parent_controller
      helper_method :params, :session, :parent_controller, :field, :identifer, :component_id, :event_url, :event_path, :record, :records, :resource, :opts

      def initialize field
        super()
        @field = field
      end

      def process context, parent_controller, record, options = {}
        @parent_controller = parent_controller
        @record = record
        @opts = options
        @identifer = params[:identifer] || generate_identifer

        resource_params = params
        resource_params.merge!(:id => record.id) if record && record.respond_to?(:id)
        @resource = Puffer::Resource.new(resource_params, parent_controller)

        super context
      end

      def render *args, &block
        options = _normalize_render(*args, &block)
        options[:template] = fallback_action(options[:template])
        render_to_body(options).html_safe
      end

      def replace *args
        javascript_wrap :replace, render(*args)
      end

      def javascript_wrap type, html
        case type
        when :replace then
          "$('#{component_id}').replace('#{view_context.escape_javascript html}')".html_safe
        else
          html
        end
      end

      def method_for_action action_name
        super fallback_action(action_name)
      end

      def fallback_action action_name
        ((parent_controller._fieldset_fallbacks[action_name] || []).detect {|name| action_method? name.to_s} || action_name).to_s
      end

      def event_url name, options = {}
        resource.collection_url (options || {}).merge(event_options(name))
      end

      def event_path name, options = {}
        resource.collection_path (options || {}).merge(event_options(name))
      end

      def event_options name
        {:action => :event, :event => name, :field => field.to_s, :fieldset => field.field_set.name, :identifer => identifer}
      end

      def component_id
        "component_#{identifer}"
      end

    private

      def generate_identifer
        Digest::MD5.hexdigest(SecureRandom.uuid)
      end

    end
  end
end
