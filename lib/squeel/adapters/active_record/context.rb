require 'squeel/context'

module Squeel
  module Adapters
    module ActiveRecord
      class Context < ::Squeel::Context

        def initialize(object)
          super
          @base = object.join_root.first
          @engine = @base.base_klass.arel_engine
          @arel_visitor = get_arel_visitor
          @default_table = Arel::Table.new(@base.table_name, :as => @base.aliased_table_name, :engine => @engine)
        end

        def find(object, parent = @base)
          if ::ActiveRecord::Associations::JoinDependency::JoinPart === parent
            case object
            when String, Symbol, Nodes::Stub
              assoc_name = object.to_s
              @object.join_root.drop(1).detect { |j|
                j.reflection.name.to_s == assoc_name && parent.children.any?{|c| c.tables.first.right == j.tables.first.right}
              }
            when Nodes::Join
              @object.join_root.drop(1).detect { |j|
                j.reflection.name == object._name && j.parent == parent &&
                (object.polymorphic? ? j.reflection.klass == object._klass : true)
              }
            else
              @object.join_root.drop(1).detect { |j|
                j.reflection == object && j.parent == parent
              }
            end
          end
        end

        def traverse(keypath, parent = @base, include_endpoint = false)
          parent = @base if keypath.absolute?
          keypath.path_without_endpoint.each do |key|
            parent = find(key, parent) || key
          end
          parent = find(keypath.endpoint, parent) if include_endpoint

          parent
        end

        def classify(object)
          if Class === object
            object
          elsif object.respond_to? :base_klass
            object.base_klass
          else
            raise ArgumentError, "#{object} can't be converted to a class"
          end
        end

        private

        def get_table(object)
          if [Symbol, String, Nodes::Stub].include?(object.class)
            Arel::Table.new(object.to_s, :engine => @engine)
          elsif Nodes::Join === object
            object._klass ? object._klass.arel_table : Arel::Table.new(object._name, :engine => @engine)
          elsif object.respond_to?(:aliased_table_name)
            Arel::Table.new(object.table_name, :as => object.aliased_table_name, :engine => @engine)
          else
            raise ArgumentError, "Unable to get table for #{object}"
          end
        end

        def get_arel_visitor
          @engine.connection.visitor
        end

      end

    end
  end
end
