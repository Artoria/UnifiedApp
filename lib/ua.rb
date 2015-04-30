require "ua/version"
require 'erb'
module Ua
  module Commands
  end
  class Application
      
      def initialize
         @store   = {}
         @context = {}
      end
      
      def make_context(a, b)
         @context[a] = b
      end
      
      def output_by_context(a, b)
         a.class.ancestors.each{|i|
            h = @context[[i, b]]
            return h.call(a) if h
         }
         a.class.ancestors.each{|i|
            h = i.instance_method(:uacontext) rescue nil
            return h.bind(a).call(b) if h
         }
         raise "Can't find a handler #{a.class} #{b}"
      end
      
      
      #
      # setup an output variable
      #
      def set(a, b)
         @store[a] = b 
      end

      TOPLEVEL = "com.ua.root"      
      def go!(name = TOPLEVEL)
         puts app(name)
      end
      
      def app(name = TOPLEVEL)
        context(@store[name], :app)
      end
      
      
      def context(a, b = nil, &bl)
        if block_given?
           make_context([a, b], bl)
        else
           output_by_context(a, b)
        end
      end
      
      
      class UAClass
        def initialize(bl, *ar)
          @ar = ar.map{|x| x.to_sym}
          @bl = bl
        end
        def method_missing(*a, &b)
          prototype.send(*a, &b)
        end
        def prototype
          @struct = Struct.new(*@ar)
          @proto ||= @struct.new
        end
        def copy
          r = prototype
          @struct.new(*r)
        end
        def render
          @bl.call self
        end
        def erb(str)
          ERB.new(str).result(binding)
        end
      end
      def get(a)
        @store[a]
      end
      def add(a, *ar, &block)
        @store[a] = UAClass.new(block, *ar)
      end
      
      def create(name)
        @store[name].copy
      end
      
      app = SINGLETON_APP = new
      app.context Array, :app do |arr|
        arr.map{|a| app.app a}.join
      end
      
      app.context String, :app do |str|
        str
      end
      
      app.context UAClass, :app do |klass|
        klass.render
      end
      
      def self.export_commands(*names)
        names.each{|name|
          (Commands).send(:define_method, name) do |*a, &b|
             SINGLETON_APP.send(name, *a, &b)
          end
        }
      end
      export_commands :set, :go!, :context, :add, :create, :get
  end
  
  
end

include Ua::Commands
