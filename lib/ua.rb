require "ua/version"

module Ua
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
         raise "Can't find a handler"
      end
      
      
      #
      # setup an output variable
      #
      def set(a, b)
         @store[a] = b 
      end

      TOPLEVEL = "com.ua.root"      
      def go!(name = TOPLEVEL)
        context(@store[name], :app)
      end
      
      
      def context(a, b = nil, &bl)
        if block_given?
           make_context([a, b], bl)
        else
           output_by_context(a, b)
        end
      end
      
      app = SINGLETON_APP = new
      app.context Array, :app do |arr|
        arr.each{|x|
          app.go!(x)
        }
      end
      
      app.context String, :app do |str|
        puts str
      end
      
      def self.export_commands(*names)
        names.each{|name|
          (class << eval("self", TOPLEVEL_BINDING); self; end).send(:define_method, name) do |*a, &b|
             SINGLETON_APP.send(name, *a, &b)
          end
        }
      end
      export_commands :set, :go!, :context
  end
end
