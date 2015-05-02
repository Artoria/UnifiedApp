#--
# ERB::Compiler
class ERB
  # = ERB::Compiler
  #
  # Compiles ERB templates into Ruby code; the compiled code produces the
  # template result when evaluated. ERB::Compiler provides hooks to define how
  # generated output is handled.
  #
  # Internally ERB does something like this to generate the code returned by
  # ERB#src:
  #
  #   compiler = ERB::Compiler.new('<>')
  #   compiler.pre_cmd    = ["_erbout=''"]
  #   compiler.put_cmd    = "_erbout.concat"
  #   compiler.insert_cmd = "_erbout.concat"
  #   compiler.post_cmd   = ["_erbout"]
  #
  #   code, enc = compiler.compile("Got <%= obj %>!\n")
  #   puts code
  #
  # <i>Generates</i>:
  #
  #   #coding:UTF-8
  #   _erbout=''; _erbout.concat "Got "; _erbout.concat(( obj ).to_s); _erbout.concat "!\n"; _erbout
  #
  # By default the output is sent to the print method.  For example:
  #
  #   compiler = ERB::Compiler.new('<>')
  #   code, enc = compiler.compile("Got <%= obj %>!\n")
  #   puts code
  #
  # <i>Generates</i>:
  #
  #   #coding:UTF-8
  #   print "Got "; print(( obj ).to_s); print "!\n"
  #
  # == Evaluation
  #
  # The compiled code can be used in any context where the names in the code
  # correctly resolve. Using the last example, each of these print 'Got It!'
  #
  # Evaluate using a variable:
  #
  #   obj = 'It'
  #   eval code
  #
  # Evaluate using an input:
  #
  #   mod = Module.new
  #   mod.module_eval %{
  #     def get(obj)
  #       #{code}
  #     end
  #   }
  #   extend mod
  #   get('It')
  #
  # Evaluate using an accessor:
  #
  #   klass = Class.new Object
  #   klass.class_eval %{
  #     attr_accessor :obj
  #     def initialize(obj)
  #       @obj = obj
  #     end
  #     def get_it
  #       #{code}
  #     end
  #   }
  #   klass.new('It').get_it
  #
  # Good! See also ERB#def_method, ERB#def_module, and ERB#def_class.
  class Compiler # :nodoc:
    class PercentLine # :nodoc:
      def initialize(str)
        @value = str
      end
      attr_reader :value
      alias :to_s :value

      def empty?
        @value.empty?
      end
    end

    class Scanner # :nodoc:
      @scanner_map = {}
      def self.regist_scanner(klass, trim_mode, percent)
        @scanner_map[[trim_mode, percent]] = klass
      end

      def self.default_scanner=(klass)
        @default_scanner = klass
      end

      def self.make_scanner(src, trim_mode, percent)
        klass = @scanner_map.fetch([trim_mode, percent], @default_scanner)
        klass.new(src, trim_mode, percent)
      end

      def initialize(src, trim_mode, percent)
        @src = src
        @stag = nil
      end
      attr_accessor :stag

      def scan; end
    end

    class TrimScanner < Scanner # :nodoc:
      def initialize(src, trim_mode, percent)
        super
        @trim_mode = trim_mode
        @percent = percent
        if @trim_mode == '>'
          @scan_line = self.method(:trim_line1)
        elsif @trim_mode == '<>'
          @scan_line = self.method(:trim_line2)
        elsif @trim_mode == '-'
          @scan_line = self.method(:explicit_trim_line)
        else
          @scan_line = self.method(:scan_line)
        end
      end
      attr_accessor :stag

      def scan(&block)
        @stag = nil
        if @percent
          @src.each_line do |line|
            percent_line(line, &block)
          end
        else
          @scan_line.call(@src, &block)
        end
        nil
      end

      def percent_line(line, &block)
        if @stag || line[0] != ?%
          return @scan_line.call(line, &block)
        end

        line[0] = ''
        if line[0] == ?%
          @scan_line.call(line, &block)
        else
          yield(PercentLine.new(line.chomp))
        end
      end

      def scan_line(line)
        line.scan(/(.*?)(<%%|%%>|<%=|<%#|<%|%>|\n|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            yield(token)
          end
        end
      end

      def trim_line1(line)
        line.scan(/(.*?)(<%%|%%>|<%=|<%#|<%|%>\n|%>|\n|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            if token == "%>\n"
              yield('%>')
              yield(:cr)
            else
              yield(token)
            end
          end
        end
      end

      def trim_line2(line)
        head = nil
        line.scan(/(.*?)(<%%|%%>|<%=|<%#|<%|%>\n|%>|\n|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            head = token unless head
            if token == "%>\n"
              yield('%>')
              if is_erb_stag?(head)
                yield(:cr)
              else
                yield("\n")
              end
              head = nil
            else
              yield(token)
              head = nil if token == "\n"
            end
          end
        end
      end

      def explicit_trim_line(line)
        line.scan(/(.*?)(^[ \t]*<%\-|<%\-|<%%|%%>|<%=|<%#|<%|-%>\n|-%>|%>|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            if @stag.nil? && /[ \t]*<%-/ =~ token
              yield('<%')
            elsif @stag && token == "-%>\n"
              yield('%>')
              yield(:cr)
            elsif @stag && token == '-%>'
              yield('%>')
            else
              yield(token)
            end
          end
        end
      end

      ERB_STAG = %w(<%= <%# <%)
      def is_erb_stag?(s)
        ERB_STAG.member?(s)
      end
    end

    Scanner.default_scanner = TrimScanner

    class SimpleScanner < Scanner # :nodoc:
      def scan
        @src.scan(/(.*?)(<%%|%%>|<%=|<%#|<%|%>|\n|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            yield(token)
          end
        end
      end
    end

    Scanner.regist_scanner(SimpleScanner, nil, false)

    begin
      require 'strscan.rb'
      class SimpleScanner2 < Scanner # :nodoc:
        def scan
          stag_reg = /(.*?)(<%%|<%=|<%#|<%|\z)/m
          etag_reg = /(.*?)(%%>|%>|\z)/m
          scanner = StringScanner.new(@src)
          while ! scanner.eos?
            scanner.scan(@stag ? etag_reg : stag_reg)
            yield(scanner[1])
            yield(scanner[2])
          end
        end
      end
      Scanner.regist_scanner(SimpleScanner2, nil, false)

      class ExplicitScanner < Scanner # :nodoc:
        def scan
          stag_reg = /(.*?)(^[ \t]*<%-|<%%|<%=|<%#|<%-|<%|\z)/m
          etag_reg = /(.*?)(%%>|-%>|%>|\z)/m
          scanner = StringScanner.new(@src)
          while ! scanner.eos?
            scanner.scan(@stag ? etag_reg : stag_reg)
            yield(scanner[1])

            elem = scanner[2]
            if /[ \t]*<%-/ =~ elem
              yield('<%')
            elsif elem == '-%>'
              yield('%>')
              yield(:cr) if scanner.scan(/(\n|\z)/)
            else
              yield(elem)
            end
          end
        end
      end
      Scanner.regist_scanner(ExplicitScanner, '-', false)

    rescue LoadError
    end

    class Buffer # :nodoc:
      def initialize(compiler, enc=nil)
        @compiler = compiler
        @line = []
        @script = enc ? "#coding:#{enc.to_s}\n" : ""
        @compiler.pre_cmd.each do |x|
          push(x)
        end
      end
      attr_reader :script

      def push(cmd)
        @line << cmd
      end

      def cr
        @script << (@line.join('; '))
        @line = []
        @script << "\n"
      end

      def close
        return unless @line
        @compiler.post_cmd.each do |x|
          push(x)
        end
        @script << (@line.join('; '))
        @line = nil
      end
    end

    def content_dump(s) # :nodoc:
      n = s.count("\n")
      if n > 0
        s.dump + "\n" * n
      else
        s.dump
      end
    end

    # Compiles an ERB template into Ruby code.  Returns an array of the code
    # and encoding like ["code", Encoding].
    def compile(s)
      out = Buffer.new(self)
      content = ''
      scanner = make_scanner(s)
      scanner.scan do |token|
        next if token.nil?
        next if token == ''
        if scanner.stag.nil?
          case token
          when PercentLine
            out.push("#{@put_cmd} #{content_dump(content)}") if content.size > 0
            content = ''
            out.push(token.to_s)
            out.cr
          when :cr
            out.cr
          when '<%', '<%=', '<%#'
            scanner.stag = token
            out.push("#{@put_cmd} #{content_dump(content)}") if content.size > 0
            content = ''
          when "\n"
            content << "\n"
            out.push("#{@put_cmd} #{content_dump(content)}")
            content = ''
          when '<%%'
            content << '<%'
          else
            content << token
          end
        else
          case token
          when '%>'
            case scanner.stag
            when '<%'
              if content[-1] == ?\n
                content.chop!
                out.push(content)
                out.cr
              else
                out.push(content)
              end
            when '<%='
              out.push("#{@insert_cmd}((#{content}).to_s)")
            when '<%#'
              # out.push("# #{content_dump(content)}")
            end
            scanner.stag = nil
            content = ''
          when '%%>'
            content << '%>'
          else
            content << token
          end
        end
      end
      out.push("#{@put_cmd} #{content_dump(content)}") if content.size > 0
      out.close
      return out.script
    end

    def prepare_trim_mode(mode) # :nodoc:
      case mode
      when 1
        return [false, '>']
      when 2
        return [false, '<>']
      when 0
        return [false, nil]
      when String
        perc = mode.include?('%')
        if mode.include?('-')
          return [perc, '-']
        elsif mode.include?('<>')
          return [perc, '<>']
        elsif mode.include?('>')
          return [perc, '>']
        else
          [perc, nil]
        end
      else
        return [false, nil]
      end
    end

    def make_scanner(src) # :nodoc:
      Scanner.make_scanner(src, @trim_mode, @percent)
    end

    # Construct a new compiler using the trim_mode. See ERB#new for available
    # trim modes.
    def initialize(trim_mode)
      @percent, @trim_mode = prepare_trim_mode(trim_mode)
      @put_cmd = 'print'
      @insert_cmd = @put_cmd
      @pre_cmd = []
      @post_cmd = []
    end
    attr_reader :percent, :trim_mode

    # The command to handle text that ends with a newline
    attr_accessor :put_cmd

    # The command to handle text that is inserted prior to a newline
    attr_accessor :insert_cmd

    # An array of commands prepended to compiled code
    attr_accessor :pre_cmd

    # An array of commands appended to compiled code
    attr_accessor :post_cmd

    private
    def detect_magic_comment(s)
      if /\A<%#(.*)%>/ =~ s or (@percent and /\A%#(.*)/ =~ s)
        comment = $1
        comment = $1 if comment[/-\*-\s*(.*?)\s*-*-$/]
        if %r"coding\s*[=:]\s*([[:alnum:]\-_]+)" =~ comment
          enc = $1.sub(/-(?:mac|dos|unix)/i, '')
          enc = Encoding.find(enc)
        end
      end
    end
  end
end

#--
# ERB
class ERB
  #
  # Constructs a new ERB object with the template specified in _str_.
  #
  # An ERB object works by building a chunk of Ruby code that will output
  # the completed template when run. If _safe_level_ is set to a non-nil value,
  # ERB code will be run in a separate thread with <b>$SAFE</b> set to the
  # provided level.
  #
  # If _trim_mode_ is passed a String containing one or more of the following
  # modifiers, ERB will adjust its code generation as listed:
  #
  #     %  enables Ruby code processing for lines beginning with %
  #     <> omit newline for lines starting with <% and ending in %>
  #     >  omit newline for lines ending in %>
  #
  # _eoutvar_ can be used to set the name of the variable ERB will build up
  # its output in.  This is useful when you need to run multiple ERB
  # templates through the same binding and/or when you want to control where
  # output ends up.  Pass the name of the variable to be used inside a String.
  #
  # === Example
  #
  #  require "erb"
  #
  #  # build data class
  #  class Listings
  #    PRODUCT = { :name => "Chicken Fried Steak",
  #                :desc => "A well messages pattie, breaded and fried.",
  #                :cost => 9.95 }
  #
  #    attr_reader :product, :price
  #
  #    def initialize( product = "", price = "" )
  #      @product = product
  #      @price = price
  #    end
  #
  #    def build
  #      b = binding
  #      # create and run templates, filling member data variables
  #      ERB.new(<<-'END_PRODUCT'.gsub(/^\s+/, ""), 0, "", "@product").result b
  #        <%= PRODUCT[:name] %>
  #        <%= PRODUCT[:desc] %>
  #      END_PRODUCT
  #      ERB.new(<<-'END_PRICE'.gsub(/^\s+/, ""), 0, "", "@price").result b
  #        <%= PRODUCT[:name] %> -- <%= PRODUCT[:cost] %>
  #        <%= PRODUCT[:desc] %>
  #      END_PRICE
  #    end
  #  end
  #
  #  # setup template data
  #  listings = Listings.new
  #  listings.build
  #
  #  puts listings.product + "\n" + listings.price
  #
  # _Generates_
  #
  #  Chicken Fried Steak
  #  A well messages pattie, breaded and fried.
  #
  #  Chicken Fried Steak -- 9.95
  #  A well messages pattie, breaded and fried.
  #
  def initialize(str, safe_level=nil, trim_mode=nil, eoutvar='_erbout')
    @safe_level = safe_level
    compiler = ERB::Compiler.new(trim_mode)
    set_eoutvar(compiler, eoutvar)
    *@src = *compiler.compile(str)
    @src.push(";" + eoutvar)
    @src = @src.join
    @filename = nil
  end

  # The Ruby code generated by ERB
  attr_reader :src

  # The optional _filename_ argument passed to Kernel#eval when the ERB code
  # is run
  attr_accessor :filename

  #
  # Can be used to set _eoutvar_ as described in ERB#new.  It's probably easier
  # to just use the constructor though, since calling this method requires the
  # setup of an ERB _compiler_ object.
  #
  def set_eoutvar(compiler, eoutvar = '_erbout')
    compiler.put_cmd = "#{eoutvar}.concat"
    compiler.insert_cmd = "#{eoutvar}.concat"

    cmd = []
    cmd.push "#{eoutvar} = ''"

    compiler.pre_cmd = cmd

    cmd = []

    compiler.post_cmd = cmd
  end

  # Generate results and print them. (see ERB#result)
  def run(b=TOPLEVEL_BINDING)
    print self.result(b)
  end

  #
  # Executes the generated ERB code to produce a completed template, returning
  # the results of that code.  (See ERB#new for details on how this process can
  # be affected by _safe_level_.)
  #
  # _b_ accepts a Binding or Proc object which is used to set the context of
  # code evaluation.
  #
  def result(b=TOPLEVEL_BINDING)
    if @safe_level
      proc {
        $SAFE = @safe_level
        eval(@src, b, (@filename || '(erb)'), 0)
      }.call
    else
      eval(@src, b, (@filename || '(erb)'), 0)
    end
  end

  # Define _methodname_ as instance method of _mod_ from compiled ruby source.
  #
  # example:
  #   filename = 'example.rhtml'   # 'arg1' and 'arg2' are used in example.rhtml
  #   erb = ERB.new(File.read(filename))
  #   erb.def_method(MyClass, 'render(arg1, arg2)', filename)
  #   print MyClass.new.render('foo', 123)
  def def_method(mod, methodname, fname='(ERB)')
    src = self.src
    magic_comment = "#coding:#{@enc}\n"
    mod.module_eval do
      eval(magic_comment + "def #{methodname}\n" + src + "\nend\n", binding, fname, -2)
    end
  end

  # Create unnamed module, define _methodname_ as instance method of it, and return it.
  #
  # example:
  #   filename = 'example.rhtml'   # 'arg1' and 'arg2' are used in example.rhtml
  #   erb = ERB.new(File.read(filename))
  #   erb.filename = filename
  #   MyModule = erb.def_module('render(arg1, arg2)')
  #   class MyClass
  #     include MyModule
  #   end
  def def_module(methodname='erb')
    mod = Module.new
    def_method(mod, methodname, @filename || '(ERB)')
    mod
  end

  # Define unnamed class which has _methodname_ as instance method, and return it.
  #
  # example:
  #   class MyClass_
  #     def initialize(arg1, arg2)
  #       @arg1 = arg1;  @arg2 = arg2
  #     end
  #   end
  #   filename = 'example.rhtml'  # @arg1 and @arg2 are used in example.rhtml
  #   erb = ERB.new(File.read(filename))
  #   erb.filename = filename
  #   MyClass = erb.def_class(MyClass_, 'render()')
  #   print MyClass.new('foo', 123).render()
  def def_class(superklass=Object, methodname='result')
    cls = Class.new(superklass)
    def_method(cls, methodname, @filename || '(ERB)')
    cls
  end
end

#--
# ERB::Util
class ERB
  # A utility module for conversion routines, often handy in HTML generation.
  module Util
    public
    #
    # A utility method for escaping HTML tag characters in _s_.
    #
    #   require "erb"
    #   include ERB::Util
    #
    #   puts html_escape("is a > 0 & a < 10?")
    #
    # _Generates_
    #
    #   is a &gt; 0 &amp; a &lt; 10?
    #
    def html_escape(s)
      s.to_s.gsub(/&/, "&amp;").gsub(/\"/, "&quot;").gsub(/>/, "&gt;").gsub(/</, "&lt;")
    end
    alias h html_escape
    module_function :h
    module_function :html_escape

    #
    # A utility method for encoding the String _s_ as a URL.
    #
    #   require "erb"
    #   include ERB::Util
    #
    #   puts url_encode("Programming Ruby:  The Pragmatic Programmer's Guide")
    #
    # _Generates_
    #
    #   Programming%20Ruby%3A%20%20The%20Pragmatic%20Programmer%27s%20Guide
    #
    def url_encode(s)
      s.to_s.dup.force_encoding("ASCII-8BIT").gsub(/[^a-zA-Z0-9_\-.]/n) {
        sprintf("%%%02X", $&.unpack("C")[0])
      }
    end
    alias u url_encode
    module_function :u
    module_function :url_encode
  end
end

#--
# ERB::DefMethod
class ERB
  # Utility module to define eRuby script as instance method.
  #
  # === Example
  #
  # example.rhtml:
  #   <% for item in @items %>
  #   <b><%= item %></b>
  #   <% end %>
  #
  # example.rb:
  #   require 'erb'
  #   class MyClass
  #     extend ERB::DefMethod
  #     def_erb_method('render()', 'example.rhtml')
  #     def initialize(items)
  #       @items = items
  #     end
  #   end
  #   print MyClass.new([10,20,30]).render()
  #
  # result:
  #
  #   <b>10</b>
  #
  #   <b>20</b>
  #
  #   <b>30</b>
  #
  module DefMethod
    public
    # define _methodname_ as instance method of current module, using ERB
    # object or eRuby file
    def def_erb_method(methodname, erb_or_fname)
      if erb_or_fname.kind_of? String
        fname = erb_or_fname
        erb = ERB.new(File.read(fname))
        erb.def_method(self, methodname, fname)
      else
        erb = erb_or_fname
        erb.def_method(self, methodname, erb.filename || '(ERB)')
      end
    end
    module_function :def_erb_method
  end
end
