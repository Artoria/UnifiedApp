$: << "../lib"
require 'ua'



context Symbol, :mycontext do |sym|
   puts sym.to_s * 3
   sym.to_s
end

u = ua add 'test.context'
u.define_context(:mycontext) do |u| context(u.a) end
u[:a] = :Hello
puts u.render(:mycontext1)

