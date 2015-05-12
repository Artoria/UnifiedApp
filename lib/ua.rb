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
         that = self
         context Array, :app do |arr|
            arr.map{|a| context(a, :app)}.join
         end
      
        context Apply, :app do |arr|
           get(arr.stream_).map{|a|that.app a}.join
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
         a[0] = get(a[0]).class if String === a[0] && has?(a[0])
         a[0] = a[0].class unless Module === a[0]
         @context[a] = b
      end
      
      def tmpid(prefix = "temp")
         r = get(count = "#{prefix}.id") || 0
         r += 1
         set count, r
         "#{prefix}.#{r}"
      end
      
      def output_by_context(a, b, *c)
         r = a.singleton_class rescue a.class
         r.ancestors.each{|i|
            h = i.instance_method(:uacontext) rescue nil
            catch(:continue){
              return h.bind(a).call(b, *c) if h
            }
         }
         r.ancestors.each{|i|
            h = @context[[i, b]]            
            catch(:continue){
              return a.instance_exec(a, *c, &h) if h
            }
         }
         puts "Can't find a handler #{a.class} #{b}"
         raise "Can't find a handler #{a.class} #{b}"
=begin
      ensure

        if $@
          unless $@.index{|x| x=="UAException"}
            $@.unshift("UAEnd")
            $@.unshift("UAException")
          end
          l, r = $@.index("UAException"), $@.index("UAEnd")
          u = $@.slice!(l..r)
          u[-1, 0] = "context #{a.class} #{b}"
          u += $@
          $@.replace u
        end
=end
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
      end
      
      def get(a)
        path, val = _parent(a)
        path[val] 
      end
      
      TOPLEVEL = "com.ua.root"      
      def go!(name = TOPLEVEL)
         puts app(name)
      end
      
      def app(name = TOPLEVEL)
         context(get(name), :app)
      end
      
      
      def context(a, b = Ua::Application.top.context, *c, &bl)
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
          include Enumerable
          define_method(:initialize) do |*args|
          begin
              Ua::Application.push_app that
              super(*args)
              self.stream_ = that.stream_generate
              self.id_     = that.tmpid("object")
              that.set self.id_, self
          ensure
              Ua::Application.pop
          end
          end
          def mapjoin
            map{|x| yield x}.join
          end
          def each
            get(stream_).each{|x|
              yield x
            }
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
            Ua::Application.pop
          end
          end
          define_method(:render) do
          begin  
            Ua::Application.push_app that          
            erb get codename
          ensure
            Ua::Application.pop
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
      
      def create(id, opt = {}, &b)
        x = get(id).prototype.new
        opt.each{|k, v| x.send "#{k}=", v }
        x         
      end
      
      def add(a = tmpid, *ar, &block)
        set a, make_uaclass(a, *ar, &block)
        get a
      end
      
      def delete(obj)
        set obj.id_, nil
      end
      
      module ArgVoid; end
      
      def self.push(app = ArgVoid, context = ArgVoid, controller = ArgVoid)
        app     = app     == ArgVoid ? @app_stack.last.app : app
        context = context == ArgVoid ? @app_stack.last.context : context
        controller = controller == ArgVoid ? @app_stack.last.controller : controller
        @app_stack.push StackFrame.new(app, context, controller)
      end
      
      def self.push_app(app)
         self.push(app)
      end
      
      
      def self.pop
        @app_stack.pop
      end
      def self.top
        @app_stack.last
      end
      def self.top_app
        top.app
      end
      
      app = SINGLETON_APP = new
      
      StackFrame = Struct.new(:app, :context, :controller)
      @app_stack = [StackFrame.new(app, :app, eval('self', TOPLEVEL_BINDING))]
      
      def initialize
        @store   = {}
        @context = {}
        bootup
      end
      
      def bootup
        default_context
        add("com.ua.root").prototype.send :include, Ua::Application::Apply
      end
      
      app.bootup
      
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
      
      def has?(key)
        get(key)
      end
      
      def stack_of(name)
         stack = "stack.#{name}"
         if has?(stack)
           get(stack)
         else
           set stack, (a = [])
           a
         end
      end
      
      
      def get_local(name)
        local = "local.#{name}"
        return get local if has?(local)  
        add local
        get local
      end
      
      def set_local(name, val)
        local = "local.#{name}"
        set local, val
        val
      end
      
      def push_local(name, newval = add)
        local = "local.#{name}"
        stack_of(local).push get local
        set local, newval
        newval
      end    
      
      def pop_local(name)
        local = "local.#{name}"
        r = get local
        set local, stack_of(local).pop
        r
      end
      
        
      export_commands :set, :go!,    :add,               :create,
                      :get, :stream, :append,  :stream_generate,
                      :get_local, :set_local, :push_local, :pop_local, :delete
                      
  end
    module Commands
        def context(obj, ctxt = Ua::Application.top.context, &b)
          Ua::Application.push(Ua::Application::ArgVoid, 
                               ctxt,   
                               self
                              )
          Ua::Application.top_app.context(obj, ctxt, &b)
        ensure
          Ua::Application.pop
        end
        alias model add
        alias view context
        alias link stream
        alias new create        
      end            
  
end


require 'ua/uadb'
require 'ua/util'
if !(Ua.const_get(:NoConflict) rescue nil)
  include Ua::Commands
  include Ua::Util
end
