$: << "../lib"
require 'ua'

module Calc
  [:+, :-, :*, :/].each{|x|
    define_method(x) do |rhs| Expr.new(self, x, rhs) end 
  }
end

class Expr < Ua::Application::ModelHash
  def initialize(atom, op, atom2)
    super(:atom => atom, op => op, :atom2 => atom2)
  end
  include Calc
end


class Atom < Ua::Application::ModelHash
  def initialize(atom)
    super(:value => atom)
  end
  include Calc
end


calc = lambda{|a, op, b|
  view(a, :expr).send(op, view(b, :expr))
}

forall [:atom, :+, :atom2] => :expr, &calc 
forall [:atom, :-, :atom2] => :expr, &calc
forall [:atom, :*, :atom2] => :expr, &calc
forall [:atom, :/, :atom2] => :expr, &calc
forall :value => :expr do |val|
  val
end

def atom(a); Atom.new(a); end


u = atom(3) + atom(5) * atom(4) - atom(2) / atom(2)
p view(u, :expr)