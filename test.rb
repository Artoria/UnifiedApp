$: << "./lib"
require 'ua'
require 'cgi'

set "com.ua.root", %w{
     com.ua.main
}

add "com.ua.main", "title", "charset", "content", "css", "js" do |node|
	%{
		<!doctype html>
	    <head>
		<title><%= title %> </title>
		<meta http-equiv="content-type" Content="text/html; Charset=<%= charset %>"
		<style>
		   <%= css %>
		</style>
		<script>
		   <%= js %>
		</script>
		</head>
		<body>
		  <%= context(content, :html) %>
		</body>
		</html>
	}
end

context String, :attr do |str|
  str.inspect
end 

context String, :html do |str|
  CGI.escapeHTML str
end 

x = get "com.ua.main"
x.title   = "Hello world"
x.charset = "UTF-8"
x.css = ""
x.js = ""
x.content = "<h1>Hello world</h1>"
go!

