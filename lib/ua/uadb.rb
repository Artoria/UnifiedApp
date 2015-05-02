module Ua
  class SQLite3Table
    def initialize(db, table)
	   require 'SQLite3'
	   @db, @table = db, table
	   @database = ::SQLite3::Database.new(@db + ".db") 
	end
  
	def [](a)
	   case a
	     when lambda{|x| Integer(x) rescue false}
		     @database.execute "select * from #{@table} where id=?", a.to_i
		   when Hash
		     k = a.keys
		     x = k.map{|name| "#{name} = ?"}.join(" and ")
		     y = k.map{|name| a[name]}
		     @database.execute "select * from #{@table} where " + x, y 
	     end
    end
  end
  
  class SQLite3DB
    def initialize(name)
      @name = name
	end
	def [](a)
	  SQLite3Table.new(@name, a)
	end
  end
  
  class SQLite3
    def [](a)
	   SQLite3DB.new(a)
	  end
  end
  
  module SQLite3Support
    def default_context
	   set "db3", SQLite3.new
	  end
  end
end