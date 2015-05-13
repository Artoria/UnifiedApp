$: << "../lib"
require 'ua'

module Calc
  [:+, :-, :*, :/, :**].each{|x|
    define_method(x) do |rhs| Expr.new(self, x, rhs) end 
  }
  def coerce(rhs)
    [view(rhs, :lift), self]
  end
end

class Expr < Ua::Application::ModelHash
  def initialize(atom, op, atom2)
    super(:atom => view(atom, :lift), op => op, :atom2 => view(atom2, :lift))
  end
  include Calc
end


class Atom < Ua::Application::ModelHash
  def initialize(atom)
    super(:value => atom)
  end
  include Calc
end

class FCall < Ua::Application::ModelHash
  def initialize(fname, arg)
    super(:fname => fname, :arg => view(arg, :lift))
  end
  include Calc
end





calc = lambda{|a, op, b|
  view(a).send(op, view(b))
}
forall [:atom, :+, :atom2] => :expr, &calc 
forall [:atom, :-, :atom2] => :expr, &calc
forall [:atom, :*, :atom2] => :expr, &calc
forall [:atom, :/, :atom2] => :expr, &calc
forall [:atom, :**, :atom2] => :expr, &calc
forall :value => :expr do |val|
  val
end
forall [:fname, :arg] => :expr do |fname, expr|
  Math.send(fname, view(expr))
end

build = lambda{|a, op, b|
  "(#{view(a)}) #{op} (#{view(b)})"
}
forall [:atom, :+, :atom2] => :build, &build 
forall [:atom, :-, :atom2] => :build, &build
forall [:atom, :*, :atom2] => :build, &build
forall [:atom, :/, :atom2] => :build, &build
forall [:atom, :**, :atom2] => :build, &build
forall :value => :build do |val|
  val
end
forall [:fname, :arg] => :build do |fname, expr|
  "#{fname}(#{view(expr)})"
end


forall  Calc  => :lift do |v| v end
forall Object => :lift do |v| Atom.new(v) end 


def sin(a); FCall.new(:sin, view(a, :lift)); end
def cos(a); FCall.new(:cos, view(a, :lift)); end
def tan(a); FCall.new(:tan, view(a, :lift)); end
u = sin(sin(1)) ** 2 + cos(sin(1)) ** 2
puts view(u, :build) + " = "
puts view(u, :expr)