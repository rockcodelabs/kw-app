require "dry/validation"
require "dry/monads"

Dry::Validation.load_extensions(:monads)
Dry::Schema.load_extensions(:monads)

# Shared Polish predicate messages; contracts defined after this inherit the load path.
Dry::Validation::Contract.config.messages.load_paths << Rails.root.join("config/dry_validation/errors.yml").to_s

#module Dry
#  module Validation
#    def self.Params(**options, &block)
#      #
#    end
#    singleton_class.send(:alias_method, :Form, :Params)
#
#    class Params
#
#    end
#    class Config
#      class << self
#        def messages
#          #
#        end
#      end
#    end
#
#    class Schema
#          def self.Params(**options, &block)
#      define(**options, processor_type: Params, &block)
#    end
#    singleton_class.send(:alias_method, :Form, :Params)
#
#      def self.configure
#
#      end
#
#      def self.define!
#
#      end
#      class MessageSet
#
#      end
#      class Message
#
#      end
#      class Config
#        class << self
#          def setting(name, value)
#            #
#          end
#
#          def messages
#            #
#          end
#        end
#      end
#      class Value
#        def self.[](value)
#          #
#        end
#      end
#    end
#  end
#  module Monads
#    module Either
#      module Mixin
#        def self.[](value)
#          #
#        end
#      end
#    end
#  end
#end
#module Dry
#  module Schema
#    # Params schema type
#    #
#    # @see Processor
#    # @see Schema#Params
#    #
#    # @api public
#    class Params < Processor
#      config.key_map_type = :stringified
#      config.type_registry_namespace = :params
#      config.filter_empty_string = true
#    end
#  end
#end
