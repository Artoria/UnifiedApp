$: << "../lib"
require 'ua'
link 'com.ua.root', 'html'
model 'html' do
  %{
	  <!doctype html>
	  <html>
	  <head>
	  <title> <%= title || "Hello" %> </title>
	  </head>
	  <body>
	       <%= context get 'elements' %>
	  
	    <script>
		   $scope = {}
		   $views = {}
		   window.update = function(a){
			   $views[a].forEach(function(f, i){
					f.update();   
			   })
		   }
         <%= context get 'jsevent' %>
		     <%= context get 'jsinit' %>
	       <%= context get 'jsload' %>
        </script>
	  </body>
  }
end
model 'jsevent'
model 'jsinit'
model 'jsload'
model 'elements'
view String, :attrval do |str| str.inspect end
view String, :jsstr do |str| str.inspect end
view String, :domid   do |str| ('#' + str).inspect end
view String, :prop   do |str| '[' + str.inspect  + ']' end
view String, :code do |str, s = "($scope)"|
   str.gsub(/\{\{(.*?)\}\}/){
    s  + context($1, :prop)
   }
end
view String, :template do |text, s = "($scope)"|
  r = text.split(/(\{\{.*?\}\})/)
  outtext = ""
  r.each{|a|
    if a =~ /\{\{(.*?)\}\}/
	   outtext << '" + ' << s << context($1, :prop) << '+ "'
	else
	   outtext << a.inspect[1..-2]
	end 
  }
  outtext = '"' << outtext << '"'
end

view String, :models do |text|
  r = text.split(/(\{\{.*?\}\})/)
  out = []
  r.each{|a|
    if a =~ /\{\{(.*?)\}\}/
	     out << $1
    end
	}
  out
end

view Hash, :models do |hsh|
  out = [] 
  hsh.each{|k, v|
    out.concat context(k, :models)
    out.concat context(v, :models)
  }
  out.uniq
end


model 'element' do
	%{
		<<%=tagname%> id=<%=context domid, :attrval%>></<%=tagname%>>
	}	
end

get('element').class.class_eval do
  def domid
    id_.tr(".", "_")
  end
end


model 'value_changed' do
	%{
		 document.querySelector(<%= context element_id, :domid %>).oninput = function(){
			 ($scope)<%= context modelname, :prop %> = this.value
			 update(<%= context modelname, :jsstr %>)
		 }
	 }
end

model 'load' do
  %{
    document.querySelector(<%= context element_id, :domid %>).oninput()
  }
end


model 'update' do
	%{
     <% models.uniq.each do |m|%>
      if(typeof $views<%=context(m, :prop)%> === 'undefined'){
         $views<%=context(m, :prop)%> = []
      }
       $views<%=context(m, :prop)%>.push(document.querySelector(<%= context element_id, :domid %>))
     <% end %> 
		  document.querySelector(<%= context element_id, :domid %>).update = function(){
         <% before.each{|k, v| %>
         <%= context(k, :code) %> = <%= context(v, :code) %>
         <% }  if before%>
         this.innerHTML = <%= text %>
		 }
	 }
end


def inputbox(opt = {})
  a =    create 'element',
        tagname: "input",
      modelname: opt[:model]
  link 'elements', a.id_
  
  changed = create 'value_changed',
        element_id: a.domid,
         modelname: a.modelname
         
  load    = create 'load',
        element_id: a.domid,
         modelname: a.modelname
        
  link 'jsevent',       changed.id_
  link 'jsload', load.id_  
end

def div(opt = {})
  a   = create 'element',
        tagname: "div"
  link 'elements', a.id_
  
  update = create 'update',
       element_id: a.domid,
             text: context(opt[:text], :template),
           models: context(opt[:text], :models) +
                   context(opt[:before] || {}, :models),
           before: opt[:before]
            
  link 'jsevent', update.id_
end


inputbox model: 'a'
div text: 'Your name has changed to {{a}}'

inputbox model: 'op1'
inputbox model: 'op2'
div before: {"{{result}}" => "+{{op1}} * +{{op2}}"},
    text: "Your answer is {{result}}"

go!