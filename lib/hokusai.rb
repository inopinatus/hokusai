require "hokusai/version"
require "active_support"
require "yaml"

module Hokusai

  ##
  # Templatable models support taking a snapshot of their data, for later use stamping out clones.
  #
  # Include this module to obtain the +as_template+ and +from_template+ methods that support a simple container
  # such as Hokusai::Container.
  #
  # Configure it with the +template+ declaration, which accepts a list of columns and an +includes+ option
  # for nested assocations.
  #
  # === Example
  #
  #   class Device < ActiveRecord::Base
  #     include Hokusai::Templatable
  #
  #     has_many :interfaces
  #
  #     template :name, :model, :location, :year, include: [:interfaces]
  #   end

  module Templatable
    extend ActiveSupport::Concern

    included do
      class_attribute :🌊
    end

    module ClassMethods
      # Define the template specification for the model.
      def template(*template_columns, **options)
        template_columns = Array(template_columns).map(&:to_s)
        included_associations = Array(options[:include]).map(&:to_s)

        self.🌊 = {
          columns: template_columns,
          associations: included_associations,
        }
      end

      ##
      # Build a new, unsaved instance of the model (and any included associations) from the template supplied.
      # The block will be called with the new instance.
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

    ##
    # Serialize this object (and any included associations) according to the template specification.
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

  ##
  # This module supplies a simple container for snapshots of template-style data.
  # These templates are used when stamping out new objects.
  #
  # A Hokusai container communicates with models via the +as_template+ method and +from_template+ class method.
  # The data will be serialized as YAML; this container class is otherwise not concerned with its structure.
  #
  # Relies on the presence of two columns: +hokusai_class+ (string) and +hokusai_template+ (text).

  module Container
    extend ActiveSupport::Concern

    included do
      validates :hokusai_class, :hokusai_template, presence: true
    end

    # Set current template data, calling +as_template+ on the origin.
    #
    # Intended for use via <tt>@template = Template.new(origin: project, ...attrs...)</tt>
    #
    def origin=(object)
      self.hokusai_class = object.class.to_s
      self.hokusai_template = YAML.dump(object.as_template)
    end

    # Stamp out a new object from the template. Calls +from_template+ on the applicable class with
    # the deserialized template data, passing on any supplied block.
    #
    # The semantics of +from_template+ are left to the receiving model.  If using the supplied
    # concern <tt>Hokusai::Templatable</tt> then a new, unsaved model object will be instantiated,
    # with nested models included as specified.
    #
    def stamp(&block)
      hokusai_class.constantize.from_template(YAML.load(hokusai_template), &block)
    end
  end
end
