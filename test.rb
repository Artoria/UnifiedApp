$: << "./lib"
require 'ua'
require 'cgi'

stream "com.ua.root", "com.ua.main"
add "com.ua.main", "title", "charset", "content", "css", "js" do
	%{
		<!doctype html>
	    <head>
		<title><%= title %> </title>
		<meta http-equiv="content-type" Content="text/html; Charset=<%= charset %>" >
		<style>
		   <%= context(css, :app) %>
		</style>
		<script>
		   <%= context(js, :app) %>
		</script>
		</head>
		<body>
		  <%= context(content, :html) %>
		</body>
		</html>
	}
end	

context String, :shell do |str|
  `#{str}`
end

context String, :html do |str|
  CGI.escapeHTML str
end

context String, :css_attr do |str|
  str.tr("_", "-")
end

context Object, :css_value do |any|
   any
end

add "com.ua.cssText", "name", "value", "sel" do
	"<%=sel%> { <%= context(name, :css_attr)%> : <%= context(value, :css_value) %>; }\n"
end

class CSSBuilder
  def initialize(name)
    @name = name
  end
  def method_missing(sym, value)
    r       = create "com.ua.cssText"
	r.name  = sym.to_s
	r.value = value
	r.sel   = @name
    append "com.ua.css", r
	self 
  end
end

def css(name)
  CSSBuilder.new(name)
end


x = get "com.ua.main"
x.title   = "Hello world"
x.charset = "GBK"
x.css     = add "com.ua.css"
x.js      = add "com.ua.js" 
x.content = context("dir", :shell)
cssbody = css("body")
cssbody.text_decoration("underline").font_size("48px")
go!

