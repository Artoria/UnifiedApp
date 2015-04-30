$: << "./lib"
require 'ua'

set "com.ua.root", %w{
     com.ua.main
}
set "com.ua.main", "Hello world"
go!
exit!


add "com.ua.main", "title", "charset", "content", "css", "js" do |node|
	ERB.new(<<-'EOF').result(node.instance_eval{binding})
		<!doctype html>
	    <head>
		<title><%= title %> </title>
		<meta http-equiv="content-type" Content="text/html; Charset=#{ context(charset, :attr) } }"
		<style>
		   #{css}
		</style>
		<script>
		   #{js}
		</script>
		</head>
		<body>
		  #{ context(content, :html) }
		</body>
		</html>
	EOF
end

context String, :attr do |str|
  str.inspect
end 

context String, :html do |str|
  str
end 

context Hash, :html do |hash|
  #todo
  hash
end



 
x = create "com.ua.main"
x.title   = "Hello world"
x.charset = "UTF-8"
x.css     = add "com.myapp.css"
x.js      = add "com.myapp.js"
add "com.myapp.object", "id", "css", "js", "html" do |node|
   stream "com.myapp.css", node.css
   stream "com.myapp.css", node.js
   "<div id=#{id.context(:attr)}>
     #{html.context(:html)}
    </div>"
end

public
def round_greeting!(text = "Hello world")
   css.border_radius 5
   html << text
end

o = create "com.myapp.object"
o.round_greeting!

a = create "com.myapp.object"
a.round_greeting!("Hello world again")

go!
