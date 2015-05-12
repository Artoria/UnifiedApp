module Ua
	module Util
		class Helper
			def initialize(obj)
				@obj = obj
			end

			def [](*args)
				if args.size == 1
					@obj[args[0]]
				else
					args.map{|x| @obj[x]}
				end
			end

			alias values_at []


			def []=(*args)
				last = args.pop(1)
				args.zip(last).each{|k|
					a,b = k
					@obj[a] = b
				}
			end
			
			def define_context(name, &block)
			  app = Ua::Application.top.app
			  app.context @obj.prototype, name, &block 
			end
			
			def app
			  render :app
			end
			
			def render(ctxt = Ua::Application.top.context)
			  context(@obj, ctxt)
			end
		end
		def ua(obj_or_str)
			if Ua::Application::UAClass === obj_or_str
				return Helper.new(obj_or_str)
			elsif String === obj_or_str
				return Helper.new(Ua::Application.top_app.get(obj_or_str))
			end
			raise ArgumentError, "Don't know how to make ua from #{obj_or_str}", caller(3)
		end
		
		
		class AppHelper
			def initialize(app = Ua::Application.top_app)
				@app = app
			end
			def push
				Ua::Application.push_app @app
			end
			def define_command(name, id, *names, &bl)
				bl ||= lambda{|a| a}
				uaobject = Helper.new @app.get id
				(class << self; self; end).send :define_method, name do |*args|
					uaobject[*names] = args
					bl.call(context(uaobject, :app))
				end
			end
			def pop
				Ua::Application.pop_app if Ua::Application.top_app == @app
			end
		end
		
		def uapp(app = Ua::Application.top_app)
			AppHelper.new(app)
		end
		
		def istr(str)
		  first = str[/^\s*(\S)/, 1]
		  str.split("\n").map{|x| x.sub(/^\s*#{Regexp.escape(first)}/, "")}.join("\n")
		end
		
		def method_respond_to(a)
		  lambda{|x| 
		    x.respond_to?(a) && lambda{|*args, &bl| x.send(a, *args, &bl) }
		  }
		end
	end
end
