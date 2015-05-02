$: << "../lib"
require 'ua'
require 'win32api'
class Maker < Ua::Application
    def initialize
	   super
	   add 'com.dll.a' do
		 %{ 
		   extern "C" <%= context(type.last, :app, []) %> __stdcall <%= context(funcname, :app) %>(<%= context(type.rhead, :app, args || (:a..:z).to_a) %>){
			   <%= context(fbody, :clang, type) %>
		   }
		 }
	   end
	   
	   get('com.dll.a').prototype.class_eval do
		  def uacontext(a)
		    case a
			 when :compile
		        @dll ||= begin
					self.name ||= Ua::Application.top_app.tmpid + ".cpp"
					self.funcname ||= "func"
					IO.binwrite self.name, context(self, :app)
					self.dllname ||= self.name + ".dll"
					system "g++ #{self.name} -o #{self.dllname} -static -s -shared -Wl,--add-stdcall-alias"
					lambda{|*args|
					   Win32API.new(self.dllname, self.funcname, args.map{|x| Integer === x ? "L" : "p"}, "L").call(*args) 
					}
				end 
			end
		  end 
	   end
	   
	end
end



class AlgeType
  attr_accessor :type, :next
  def initialize(type = nil)
    @type = type
    @next = nil
  end
  def detach
    AlgeType.new(@type)
  end
  
  def >> rhs
     x = AlgeType.new(@type)
     case rhs
	    when AlgeType
		    x.next = rhs  
		  else	
		    x.next = AlgeType.new(rhs)
	   end
     x
  end
  
  def * rhs
     t = Array(@type).compact 
     d = if AlgeType === rhs then rhs else AlgeType.new(rhs) end
     t += Array(d.type)
     AlgeType.new t
  end
  
  def last
    if self.next
      self.next.last
    else
      self
    end
  end
  
  def rhead
    if self.next
      self.detach >> self.next.rhead 
    else
      nil
    end
  end
 
  def coerce(rhs)
     [AlgeType.new(rhs), self]
  end
  
  def cfunc(expr)
    x = Ua::Application.top_app.create 'com.dll.a',
          type: self,
          fbody: expr
    context(x, :compile)
  end
end

def int() AlgeType.new([:int]) end
def unit() AlgeType.new([]) end

app = Maker.new
Ua::Application.push_app app
app.context AlgeType, :app do |atype, val|
    ret = []
    i = 0
  	while atype && atype.type
      unless val.empty?
         ret << [context(atype.type, :app).to_s << " " << context(val[i], :app).to_s]
      else 
         ret << [context(atype.type, :app).to_s]
      end
      atype = atype.next
      i += 1
    end
    ret.join(",") 
end


class Expr
  attr_accessor :atom
  def initialize(atom)
    @atom = "(" + atom.to_s + ")"
  end
  def +(rhs)
    Expr.new(context(self, :expr) + "+" + context(rhs, :expr))
  end
  def uacontext(app, *a)  
    if app == :clang
      return "return #{context(self, :expr)};"
    elsif app == :expr
      return @atom
    end
    throw :continue
  end
end

def var(a)
  Expr.new(a)
end

app.context Symbol, :app, &:to_s


r = (int.>> int.>> int).cfunc var(:a) + var(:b)
p r.call(3, 5)

