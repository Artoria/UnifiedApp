$: << "../lib"
require 'ua'
require 'ua/uadb'
class My < Ua::Application
  include Ua::SQLite3Support
end

x = My.new
p x