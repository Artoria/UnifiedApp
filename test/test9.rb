$: << "../lib"
require 'ua'

forall 0 => :fib do |num|
   1
end

forall 1 => :fib do |num|
   1
end

forall Numeric => :fib do |num|
   view(num - 1, :fib) + view(num - 2, :fib)  
end

p view(110, :fib)

