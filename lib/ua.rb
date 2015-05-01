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
      
      def output_by_context(a, b, *c)
         a.class.ancestors.each{|i|
            h = @context[[i, b]]            
            catch(:continue){
              return h.call(a, *c) if h
            }
         }
         a.class.ancestors.each{|i|
            h = i.instance_method(:uacontext) rescue nil
            catch(:continue){
              return h.bind(a).call(*c) if h
            }
         }
         raise "Can't find a handler #{a.class} #{b}"
      ensure
        if $@
          unless $@.index{|x| x=="UAException"}
            $@.unshift("UAEnd")
            $@.unshift("UAException")
          end
          l, r = $@.index("UAException"), $@.index("UAEnd")
          u = $@.slice!(l..r)
          u[-1, 0] = "context #{a.class} #{b}"
          $@ = u + $@
        end
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
      
      
      def context(a, b = nil, *c, &bl)
        if block_given?
           make_context([a, b], bl)
        else
           output_by_context(a, b, *c)
        end
      end
      
      module UAClass
      end
      
      def make_uaclass(a, *ar, &block)
        autoinit = false
        block ||= begin
           autoinit = true
           lambda{
              "<%= context(stream_ || [], :app) %>"
           }
        end
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
          define_singleton_method(:to_s) do
            a
          end
        end 
        x = klass.new
        x.stream_ = []
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
        get a
      end
      
      def create(name)
        @store[name].clone
      end
      
      app = SINGLETON_APP = new
      app.context Array, :app do |arr|
        arr.map{|a| context(a, :app)}.join
      end
      
      module Apply; end
      app.context Apply, :app do |arr|
        arr.stream_.map{|a| app.app a}.join
      end
      
      app.context String, :app do |str|
        str
      end
      
      app.context UAClass, :app do |element|
        element.render
      end
      
      app.context Array, :stream_add do |arr, *a|
        arr.concat a
        ""
      end
      app.context String, :get do |obj, *a|
         app.context(app.get(obj), *a)
      end
      app.context UAClass, :stream_add do |obj, *a|
        obj.stream_ ||= []
        obj.stream_.concat a
        ""
      end
      
      app.context UAClass, :append_add do |obj, *a|
        obj.stream_ ||= []
        obj.stream_.concat a
        ""
      end
      
      def stream(a, *b)
        context(get(a), :stream_add, *b)
      end
      
      def append(a, *b)
        context(get(a), :append_add, *b)
      end
      
      def self.export_commands(*names)
        names.each{|name|
          (Commands).send(:define_method, name) do |*a, &b|
             SINGLETON_APP.send(name, *a, &b)
          end
        }
      end
      export_commands :set, :go!, :context, :add, :create, :get, :stream, :append
  end
  
  
end

if !(Ua.const_get(:NoConflict) rescue nil)
  include Ua::Commands
  add("com.ua.root").prototype.send :include, Ua::Application::Apply
end
