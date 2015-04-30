require "ua/version"
require 'erb'
require 'ostruct'
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
      
      module UAClass
      end
      
      def make_uaclass(a, *ar, &block)
        klass = Class.new(OpenStruct) do
          include UAClass
          define_method(:classid) do
            a
          end
          define_method(:prototype) do
            klass
          end
          define_method(:erb) do |text|
            ERB.new(text).result(binding)
          end
          define_method(:render) do 
            erb instance_exec &block
          end
        end 
        x = klass.new
        klass.const_set :Singleton_, x
        x
      end
     
     
      def get(a)
        @store[a]
      end
      
      def create(id)
        get(id).prototype.new
      end
      
      def add(a, *ar, &block)
        @store[a] = make_uaclass(a, *ar, &block)
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

if !(Ua.const_get(:NoConflict) rescue nil)
  include Ua::Commands
end
