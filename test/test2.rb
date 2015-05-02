$: << "../lib"
require 'ua'

class SayHelloApplication < Ua::Application
  def initialize
  	    super
		stream "com.ua.root", "com.ua.js.run"
		add "com.ua.js.main" do
			"
				(function(){
					if(typeof window !== 'undefined') {
						window.alert(<%= context(message, :js_string) %> );
					}
					if(typeof console !== 'undefined') {
			    		console.log( <%= context(message, :js_string) %> );
		    		}
					if(typeof WScript !== 'undefined') {
			    		WScript.Echo( <%= context(message, :js_string) %> );
		    		}
				})()		
			"
		end
		add "com.ua.js.run" do
			"<%
			    IO.binwrite('test.js', context(get('com.ua.js.main'), :app))
			    context(execjs || 'node.exe', :shell, 'test.js') 
		    %>"
		end

		context String, :js_string do |str|
  			str.inspect # should be quote_string(str), but this partly works
		end

		context String, :shell do |*args|
  			`#{args.join(" ")}`
		end
	end
end

def say_hello(hello = "Hello world")
  app = SayHelloApplication.new
  app.get('com.ua.js.main').message = hello
  app.get('com.ua.js.run').execjs   = "wscript.exe"
  app.go!
end

say_hello "abc"
