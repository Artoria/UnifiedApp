require "ua/version"
require 'erb'
require 'ostruct'
module Ua
  module Commands
  end
  class Application
      module UAClass; end
      module Apply; end
      def initialize
         @store   = {}
         @context = {}
      end
      
      def default_context
         context Array, :app do |arr|
            arr.map{|a| context(a, :app)}.join
         end
      
        context Apply, :app do |arr|
           get(arr.stream_).map{|a|app a}.join
        end
        
        context String, :app do |str|
           str
        end
        
        context UAClass, :app do |element|
          element.render
        end
        
        context Array, :stream_add do |arr, *a|
          arr.concat a
          ""
        end
        context String, :get do |obj, *a|
           context(get(obj), *a)
        end
        
        context UAClass, :stream_add do |obj, *a|
          obj.stream_ ||= stream_generate
          get(obj.stream_).concat a
          obj.extend Apply
          ""
        end
        
        context UAClass, :append_add do |obj, *a|
          obj.stream_ ||= stream_generate
          get(obj.stream_).concat a
          ""
        end
     end
      
      def make_context(a, b)
         @context[a] = b
      end
      
      def tmpid
         r = get("tmp.id") || 0
         r += 1
         set "tmp.id", r
         "temp.#{r}"
      end
      
      def output_by_context(a, b, *c)
         r = a.singleton_class rescue a.class
         r.ancestors.each{|i|
            h = @context[[i, b]]            
            catch(:continue){
              return h.call(a, *c) if h
            }
         }
         r.ancestors.each{|i|
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
          u[-1, 0] = "context #{a.class} #{a.respond_to?(:stream_) ? a.stream_ : nil }#{b}"
          $@ = u + $@
        end
      end
      
      
      #
      # setup an output variable
      #
      def _parent(a)
        u = @store
        col = ""
        arr = a.split(".") 
        arr[0..-2].each{|x|
          col << "." << x 
          if u[x] == nil
            u[x] = {}
          elsif !u[x].respond_to?(:[])
            raise "#{col} is not valid"
          end
          u = u[x] 
        }
        [u, arr[-1]]
      end 
      
      def set(a, b)
         path, val = _parent(a)
         path[val] = b
         b
      ensure
        $@.unshift a if $@  
      end
      
      
      def get(a)
        path, val = _parent(a)
        path[val] 
      ensure
        $@.unshift a if $@
      end
      
      TOPLEVEL = "com.ua.root"      
      def go!(name = TOPLEVEL)
         puts app(name)
      end
      
      def app(name = TOPLEVEL)
         context(get(name), :app)
      end
      
      
      def context(a, b = nil, *c, &bl)
        if block_given?
           make_context([a, b], bl)
        else
           output_by_context(a, b, *c)
        end
      end
      
      
      
      def make_uaclass(a, *ar, &block)
        autoinit = false
        block ||= begin
           autoinit = true
           lambda{
              "<%= context(get(stream_), :app) %>"
           }
        end
        that = self
        code = block.call
        codename = "proc.#{a}"
        set codename, code
        klass = Class.new(OpenStruct) do
          include UAClass
          
          define_method(:initialize) do |*args|
          begin
              Ua::Application.push_app that
              super(*args)
              self.stream_ = that.stream_generate
          ensure
              Ua::Application.pop_app
          end
          end
          define_method(:classid) do
            a
          end
          define_method(:prototype) do
            klass
          end
          define_method(:erb) do |text__|
          begin
            Ua::Application.push_app that  
            ERB.new(text__).result(binding)
          ensure
            Ua::Application.pop_app
          end
          end
          define_method(:render) do
          begin  
            Ua::Application.push_app that          
            erb get codename
          ensure
            Ua::Application.pop_app
          end
          end
          define_singleton_method(:to_s) do
            a
          end
        end 
        x = klass.new
        klass.const_set :Singleton_, x
        x
      end
     
      
      
      def stream_generate
        u = tmpid
        set u, []
        u
      end
      
      def create(id)
        get(id).prototype.new 
      end
      
      def add(a, *ar, &block)
        set a, make_uaclass(a, *ar, &block)
      end
      
      def create(name)
        get(name).clone
      end
      
      def self.push_app(app)
        @app_stack.push app
      end
      def self.pop_app
        @app_stack.pop
      end
      def self.top_app
        @app_stack.last
      end
      
      app = SINGLETON_APP = new
      @app_stack = [app]
      
      def initialize
        @store   = {}
        @context = {}
        default_context
        add("com.ua.root").prototype.send :include, Ua::Application::Apply
      end
      
      app.default_context
      app.add("com.ua.root").prototype.send :include, Ua::Application::Apply
      
      def self.singleton
         SINGLETON_APP
      end
      
      def stream(a, *b)
        context(get(a), :stream_add, *b)
      end
      
      def append(a, *b)
        context(get(a), :append_add, *b)
      end
      
      def self.export_commands(*names)
        that = self
        names.each{|name|  
          (Commands).send(:define_method, name) do |*a, &b|
             that.top_app.send(name, *a, &b)
          end
        }
      end
      
      
      export_commands :set, :go!,    :context, :add,               :create,
                      :get, :stream, :append,  :stream_generate, :mount
                      
      
        
  end
  
  
end

if !(Ua.const_get(:NoConflict) rescue nil)
  include Ua::Commands
end
