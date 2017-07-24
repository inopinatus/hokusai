require "hokusai/version"
require "active_support"
require "yaml"

module Hokusai
  module Templatable
    #
    # Templatable models support taking a snapshot of their data, for later use stamping out clones.
    #
    # Include this module to obtain the +as_template+ and +from_template+ methods that support a simple container
    # such as Hokusai::Container.
    # 
    # Configure it with the +template+ declaration, which takes a list of columns and an optional +includes+ option
    # for nested assocations.
    #
    # ==== Example
    # class Template < ActiveRecord::Base
    #   include Hokusai::Container
    #   validates :name, presence: true
    # end
    #
    # class Device < ActiveRecord::Base
    #   include Hokusai::Templatable
    #
    #   belongs_to :owner
    #   has_many :interfaces
    #
    #   template :owner_id, :name, :model, :location, :year, include: [:interfaces]
    #
    #   # ...
    # end
    #
    # class Interfaces < ActiveRecord::Base
    #   include Hokusai::Templatable
    #   belongs_to :device
    #   template :name, :address, :enabled
    #   # ...
    # end
    #
    # device = Device.create!(name: "router", model: "CX-6790", location: "SFO", year: 2017)
    # device.interfaces << Interface.create!([{name: "de0", address: "10.0.0.1", enabled: false}, {name: "lo0", address: "127.0.0.1", enabled: true}])
    #
    # Template.create!(origin: device, name: 'SFO router template')
    #
    # new_device = Template.last.use do |dev|
    #   dev.name = "router-2"
    # end
    #
    # new_device.save!
    #
    extend ActiveSupport::Concern

    included do
      class_attribute :🌊
    end

    class_methods do
      def template(*template_columns, **options)
        template_columns = Array(template_columns).map(&:to_s)
        included_associations = Array(options[:include]).map(&:to_s)

        self.🌊 = {
          columns: template_columns,
          associations: included_associations,
        }
      end

      def from_template(template, &block)
        if template.is_a?(Array)
          template.map { |tpl| from_template(tpl, &block) }
        else
          new_attrs = template.slice(*🌊[:columns])
          template.slice(*🌊[:associations]).each do |association, association_template|
            new_attrs[association] = reflect_on_association(association).klass.from_template(association_template)
          end
          new(new_attrs, &block)
        end
      end
    end

    def as_template
      result_hash = {}

      🌊[:columns].each_with_object(result_hash) do |column|
        result_hash[column] = read_attribute_for_template(column)
      end

      🌊[:associations].each do |association|
        records = send(association)
        result_hash[association] = if records.respond_to?(:to_ary)
          records.to_ary.map { |r| r.as_template }
        else
          records.as_template
        end
      end

      result_hash
    end

    private
    alias :read_attribute_for_template :send
  end

  module Container
    #
    # A simple container mixin for snapshots of template-style data. They are then used when stamping out new objects.
    #
    # A Hokusai container communicates with models via the +as_template+ method and +from_template+ class method.
    # The data will be serialized as YAML; this container class is otherwise not concerned with
    # its structure.
    #
    # The provided mixin (<tt>Hokusai::Templatable</tt>) implements the +as_template+ and +from_template+
    # methods and supplies the +template+ method to assist with their configuration.  For advanced configurations
    # you may need to roll your own.
    # 
    # Relies on the presence of hokusai_class:string and hokusai_template:text columns.
    #
    extend ActiveSupport::Concern

    included do
      validates :hokusai_class, :hokusai_template, presence: true
    end

    # Set current template data, calling +as_template+ on the origin.
    #
    # Supports usage as @template = Template.new(origin: project, ...attrs...)
    #
    def origin=(object)
      self.hokusai_class = object.class.to_s
      self.hokusai_template = YAML.dump(object.as_template)
    end

    # Stamp out a new object from the template. Calls +from_template+ on the matching model's class with
    # the deserialized template data, passing on any supplied block.
    #
    # The semantics of +from_template+ are left to the receiving model.  If using the supplied
    # mixin <tt>Hokusai::Templatable</tt> then a new but unsaved model object will be instantiated,
    # with dependent nested models if specified.
    #
    def stamp(&block)
      hokusai_class.constantize.from_template(YAML.load(hokusai_template), &block)
    end
  end
end
