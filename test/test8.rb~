$: << "../lib"
require 'ua'

forall :to_s => :to_s do |str|
  puts "never reach here"
end


forall :to_s => :inspect do |str|
  str.inspect
end


forall Object => :to_s do |obj|
  obj.to_s
end

module Shortform; end

forall [Shortform, :tagname, :id] => :htmlelement do |x, tagname, id|
  "<" << view(tagname) << " id=" << view(id, :inspect) << "/>" 
end 

forall [:tagname, :id] => :htmlelement do |tagname, id|
  "<" << view(tagname) << " id=" << view(id, :inspect) << "></" << view(tagname) << ">" 
end 

x = modelhash\
       tagname: "Orzfly",
       id:      42
       
puts view(x, :htmlelement)
x.extend Shortform
puts view(x, :htmlelement)

