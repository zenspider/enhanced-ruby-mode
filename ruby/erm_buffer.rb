require 'ripper'

class ErmBuffer
  FONT_LOCK_NAMES = {
    rem:             0,  # remove/ignore
    sp:              0,
    ident:           0,
    tstring_content: 1,  # font-lock-string-face
    const:           2,  # font-lock-type-face
    ivar:            3,  # font-lock-variable-name-face
    arglist:         3,
    cvar:            3,
    gvar:            3,
    embexpr_beg:     3,
    embexpr_end:     3,
    comment:         4,  # font-lock-comment-face
    embdoc:          4,
    label:           5,  # font-lock-constant-face
    CHAR:            6,  # font-lock-string-face
    backtick:        7,  # ruby-string-delimiter-face
    __end__:         7,
    embdoc_beg:      7,
    embdoc_end:      7,
    tstring_beg:     7,
    tstring_end:     7,
    words_beg:       7,
    regexp_beg:      8,  # ruby-regexp-delimiter-face
    regexp_end:      8,
    tlambda:         9,  # font-lock-function-name-face
    defname:         9,
    kw:              10, # font-lock-keyword-face
    block:           10,
    heredoc_beg:     11,
    heredoc_end:     11,
    op:              12, # ruby-op-face
    regexp_string:   13, # ruby-regexp-face
  }

  module Adder
    attr_accessor :statement_start
    attr_accessor :ident
    attr_accessor :first_token
    attr_accessor :last_add

    def nadd sym, tok, len = tok.size, ft = false, la = nil
      d :nadd => [sym, tok, len, ft, la]
      case sym
      when :sp, :comment then
        case parser.mode
        when :predef, :expdef then
          # do nothing
        else
          parser.mode = nil
        end
      else
        self.statement_start = false

        parser.mode = :def if parser.mode == :predef
        self.block = false if block == :b4args

        case sym
        when :ident, :const, :ivar, :gvar, :cvar then
          self.ident = true
        when :rem_rparen, :indent then
          # leave alone?
        else
          d "self.ident = false"
          self.ident = false
        end
      end

      self.first_token = ft
      self.last_add = la

      target = parser.equal?(self) || lineno != parser.lineno ? self : prev
      target.realadd sym, tok, len

      sym
    end
  end # module Adder

  class Heredoc
    include Adder

    attr_accessor :lineno, :lines, :parser, :prev, :tok
    attr_accessor :block

    def initialize parser, prev, tok, lineno
      # TODO: tok?
      self.parser = parser
      self.prev   = prev
      self.lineno = lineno
      self.lines  = []
      self.block  = nil
    end

    def d o
      parser.d o
    end

    def realadd(*args)
      lines << args
    end

    def restore
      lines << [:heredoc_end, nil, nil] if lines.empty?
      if parser.equal? prev then
        for args in lines
          parser.nadd(*args)
        end
        parser.heredoc = nil
      else
        prev.lines += lines
        parser.heredoc = prev
      end
    end
  end # class Heredoc

  class Parser < ::Ripper   #:nodoc: internal use only
    include Adder

    # TODO: add prev_line and copy it when we clear line_so_far
    # TODO: use this to calculate hanging indent for parenless args

    # Indents:
    #
    # l - [, (, {, %w/%i open  or | goalpost open
    # r - ], ), }, %w/%i close or | goalpost close
    # b - begin/def/case/if
    # e - end / embexpr (interpolation) end / close block }
    # d - do / {
    # s - statement start on BACKDENT_KW else/when/rescue etc
    # c - continue - period followed by return (or other way around?)

    INDENT_KW          = [:begin, :def, :case, :module, :class, :do, :for]
    BACKDENT_KW        = [:elsif, :else, :when, :rescue, :ensure]
    BEGINDENT_KW       = [:if, :unless, :while, :until]
    POSTCOND_KW        = [:if, :unless, :or, :and]
    PRE_OPTIONAL_DO_KW = [:in, :while, :until]
    DELIM_MAP          = { "(" => ")", "[" => "]", "{" => "}" }

    ESCAPE_LINE_END    = "\\\n"

    attr_accessor :heredoc, :mode
    attr_accessor :indent_stack, :ident_stack, :brace_stack
    attr_accessor :parser
    attr_accessor :file_encoding
    attr_accessor :ermbuffer
    attr_accessor :point_min
    attr_accessor :point_max
    attr_accessor :src
    attr_accessor :src_size
    attr_accessor :first_count
    attr_accessor :count
    attr_accessor :res
    attr_accessor :block
    attr_accessor :list_count
    attr_accessor :cond_stack
    attr_accessor :plit_stack
    attr_accessor :line_so_far

    def initialize ermbuffer, src, point_min, point_max, first_count
      self.ermbuffer     = ermbuffer
      self.point_min     = point_min
      self.point_max     = point_max
      self.src           = src
      self.src_size      = src.size
      self.file_encoding = src.encoding
      self.first_count   = nil
      self.parser        = self # stupid hack for Adder module above
      super src
    end

    def add(*args)
      (heredoc || self).nadd(*args)
    end

    def indent type, c = 0
      add :indent, type, c
    end

    # Bugs in Ripper:
    # empty here doc fails to fire on_heredoc_end
    def parse
      self.count          = 1
      self.mode           = nil
      self.brace_stack    = []
      self.heredoc        = nil
      self.first_token    = true
      self.last_add       = nil
      self.res            = []
      self.ident          = false
      self.ident_stack    = []
      self.block          = false
      self.statement_start = true
      self.indent_stack   = []
      self.list_count     = 0
      self.cond_stack     = []
      self.plit_stack     = []
      self.line_so_far    = []

      catch :parse_complete do
        super

        realadd :rem_heredoc, '', src_size-count if heredoc
      end

      self.res = res.map.with_index { |v, i|
        "(%d %s)" % [i, v.join(" ")] if v
      }

      "((%s %s %s %s)%s)" % [src_size,
                             point_min,
                             point_max,
                             indent_stack.join(' '),
                             res.join]
    end

    def realadd sym, tok, len
      if sym == :indent
        pos = count + len
        indent_stack << tok << pos if pos.between? point_min, point_max

        return
      end

      start = count
      throw :parse_complete if start > point_max

      len = 2 + src.index("\n", start) - start unless len

      pos = self.count += len
      return if pos < point_min
      start = point_min if start < point_min
      pos = point_max   if pos   > point_max

      sym = :rem if sym =~ /^rem_/
      idx = FONT_LOCK_NAMES[sym]

      if t = res[idx] then
        if t.last == start then
          t[-1] = pos
        else
          t << start << pos
        end
      else
        res[idx] = [start, pos]
      end

      if (sym == :sp && tok == "\n") || (sym == :comment && tok.end_with?("\n"))
        line_so_far.clear
      else
        line_so_far << [sym, tok, len]
      end

      throw :parse_complete if pos == point_max
    end

    def maybe_plit_ending tok
      if tok[-1] == plit_stack.last
        plit_stack.pop

        # Token can sometimes have preceding whitespace, which needs to be added
        # as a separate token to work with indents.
        if tok.length > 1
          add :rem_end_ws, tok[0..-2]
        end
        indent :r
        add :tstring_end, tok[-1]
      end
    end

    ############################################################
    # on_* handlers
    # TODO: I don't like these generated methods. Harder to trace/debug.

    def d o
      ermbuffer.d o
    end

    def debug_on tok
      return unless ermbuffer.debug
      loc  = caller_locations.first.label.to_sym
      rest = line_so_far.map {|a| a[1] }.join
      d "%-10s %p %p %p" % [loc, tok, ident, rest]
    end

    [:CHAR, :__end__, :backtick, :embdoc, :embdoc_beg, :embdoc_end,
     :label, :tlambda, :tstring_beg].each do |event|
      define_method "on_#{event}" do |tok|
        tok.force_encoding file_encoding if tok.encoding != file_encoding
        debug_on tok
        add event, tok
      end
    end

    [:backref, :float, :int].each do |event|
      define_method "on_#{event}" do |tok|
        debug_on tok
        add :"rem_#{event}", tok
      end
    end

    [:cvar, :gvar, :ivar].each do |event|
      define_method "on_#{event}" do |tok|
        if mode == :sym then
          debug_on [tok, :sym]
          add :label, tok
        else
          debug_on [tok, :not_sym]
          add event, tok
        end
      end
    end

    def on_comma tok
      debug_on tok
      self.mode = nil
      r = add :rem_comma, tok, tok.size, false, list_count <= 0
      self.statement_start = true
      r
    end

    def on_comment tok
      debug_on tok
      on_eol :comment, tok
    end

    def on_const tok
      debug_on [tok, mode]
      case mode
      when :sym then
        self.mode = nil
        add :label, tok
      when :def, :predef then
        r = add :const, tok
        self.mode = :predef
        r
      else
        add :const, tok
      end
    end

    def on_embexpr_beg tok
      debug_on tok
      len = tok.size
      if len > 2 then
        add :tstring_content, tok, len - 2
        len = 2
      end

      brace_stack << :embexpr
      cond_stack << false
      plit_stack << false

      indent :d, 1
      add :embexpr_beg, tok, len
    end

    def on_embexpr_end tok
      debug_on tok
      brace_stack.pop
      cond_stack.pop
      plit_stack.pop
      indent :e
      add :embexpr_beg, tok
    end

    def on_embvar tok
      debug_on tok
      len = tok.size
      if len > 1 then
        add :tstring_content, tok, len - 1
        len = 1
      end

      add :ivar, tok, len
    end

    def on_eol sym, tok
      debug_on tok
      indent :c, tok.size if last_add

      r = add sym, tok, tok.size, true

      if heredoc && heredoc.lineno == lineno then
        heredoc.restore
      end

      cond_stack.pop if cond_stack.last
      self.statement_start = true

      r
    end

    def on_heredoc_beg tok
      debug_on tok
      r = add :heredoc_beg, tok
      if !heredoc || heredoc.lineno < lineno then
        self.heredoc = Heredoc.new self, heredoc||self, tok, lineno
      end
      r
    end

    def on_heredoc_end tok
      debug_on tok
      add :heredoc_end, tok
    end

    def on_ident tok
      debug_on [tok, mode]
      case mode
      when :sym then
        add :label, tok
      when :predef, :def then
        add :defname, tok
      when :period then
        add :ident, tok
      else
        if ermbuffer.extra_keywords.include? tok then
          add :kw, tok
        else
          add :ident, tok
        end
      end
    end

    def on_ignored_nl tok
      debug_on tok
      if tok then
        on_nl tok
      end
    end

    def on_kw sym # TODO: break up. 61 lines long
      sym = sym.to_sym
      debug_on [sym, mode]
      case mode
      when :sym then
        add :label, sym
      when :def, :predef then
        if sym != :self then
          add :defname, sym
        else
          r = add :kw, sym
          self.mode = :def
          r
        end
      else
        last_add = nil

        case sym
        when :end then
          indent :e
        when :do then
          if cond_stack.last then
            cond_stack.pop
            r = add :kw, sym
          else
            # `indent` precedes `add` for the compatibility of parsing result.
            #
            # `add` and `indent` must precede `self.block = :b4args`.
            # Otherwise block is overwritten, and indentation is broken
            # in the following code:
            #  each do |a| # <- `|` for argument list is recognized as operator,
            #      # <- which produces an extra indentation.
            #  end

            indent :d
            r = add :kw, sym
            self.block = :b4args
          end

          return r
        when *BEGINDENT_KW then
          if statement_start then
            indent :b
          elsif POSTCOND_KW.include? sym then
            last_add = :cont
          end
        when *POSTCOND_KW then
          last_add = :cont
        when *INDENT_KW then
          indent :b
        when *BACKDENT_KW then
          indent :s if statement_start
        end

        cond_stack << true if PRE_OPTIONAL_DO_KW.include? sym

        r = add :kw, sym, sym.size, false, last_add
        self.mode = :predef if [:def, :alias].include? sym
        r
      end
    end

    def on_lbrace tok
      cond_stack << false
      ident_stack << [ident, mode]

      is_start_of_line = line_so_far.all? {|a| a[0] == :sp }
      if ident && !is_start_of_line then
        brace_stack << :block
        indent :d
        r = add :block, tok
        self.block = :b4args
        r
      else
        brace_stack << :brace
        self.list_count += 1
        indent :l
        add :rem_lbrace, tok
      end
    end

    def on_lparen tok
      newmode = case mode
                when :def then
                  self.mode = nil
                when :predef then
                  self.mode = :expdef
                  :predef
                else
                  mode
                end

      ident_stack << [ident, newmode]
      cond_stack << false
      indent :l
      self.list_count += 1
      r = add :rem_lparen, tok
      self.statement_start = true
      r
    end

    def on_nl tok
      on_eol :sp, tok
    end

    def on_op tok
      if mode == :sym then
         add :label, tok
      else
        r = if block && tok == '|'
            case block
            when :b4args then
              indent :l
              self.list_count += 1
              self.block = :arglist
            else
              indent :r
              self.list_count -= 1
              self.block = false
            end
            add :arglist, tok, 1
          else
            case mode
            when :def, :predef then
              add :ident, tok
            else
              add :op, tok, tok.size, false, :cont
            end
          end
        self.statement_start = true
        r
      end
    end

    def on_period tok
      self.mode ||= :period

      debug_on tok

      indent :c, tok.size if tok == "\n"
      d :ident => ident
      d :lsf => line_so_far

      line_so_far_str = line_so_far.map {|a| a[1] }.join
      if line_so_far_str.strip == ""
        indent :c, -line_so_far_str.length
      end

      add :rem_period, tok, tok.size, false, :cont
    end

    def on_rbrace tok
      debug_on tok
      cond_stack.pop
      type = case brace_stack.pop
             when :embexpr then
               indent :e
               if plit_stack.last == false
                 plit_stack.pop
               end
               :embexpr_beg
             when :block then
               indent :e
               :block
             when :brace then
               indent :r
               self.list_count -= 1
               :rem_brace
             else
               :rem_other
             end

      add(type, tok).tap do
        self.ident, self.mode = ident_stack.pop
      end
    end

    def on_regexp_beg tok
      tok.force_encoding file_encoding if tok.encoding != file_encoding
      self.mode = :regexp
      debug_on tok
      add :regexp_beg, tok
    end

    def on_regexp_end tok
      self.mode = nil
      debug_on tok
      add :regexp_end, tok
    end

    def on_rparen tok
      debug_on tok
      indent :r
      r = add :rem_rparen, tok

      self.list_count -= 1
      self.ident, self.mode = ident_stack.pop
      cond_stack.pop

      r
    end

    def on_semicolon tok
      debug_on tok
      r = add :kw, :semicolon, 1, true
      cond_stack.pop if cond_stack.last
      self.statement_start = true
      r
    end

    def on_sp tok
      debug_on tok
      if tok == ESCAPE_LINE_END then
        indent :c, 2
      end
      add :sp, tok, tok.size, first_token, last_add
    end

    def on_symbeg tok
      debug_on tok
      r = add :label, tok
      self.mode = :sym
      r
    end

    def on_tlambeg tok
      debug_on tok
      brace_stack << :block
      indent :d
      add :block, tok
    end

    def on_tstring_content tok
      debug_on tok
      tok.force_encoding file_encoding if tok.encoding != file_encoding
      if mode == :regexp
        add :regexp_string, tok
      elsif plit_stack.last # `tstring_content` is ignored by indent in emacs.
        add :rem_tstring_content, tok # TODO: figure out this context? or collapse?
      else
        add :tstring_content, tok
      end
    end

    def on_tstring_end tok
      debug_on [tok, mode]

      return if maybe_plit_ending(tok)

      if mode == :sym then
        add :label, tok
      else
        add :tstring_end, tok
      end
    end

    def on_label_end tok
      debug_on tok
      add :tstring_beg, tok[0]
      add :label, tok[1]
    end

    def on_words_beg tok
      debug_on tok
      delimiter = tok.strip[-1]  # ie. "%w(\n" => "("
      plit_stack << (DELIM_MAP[delimiter] || delimiter)

      indent :l
      add :words_beg, tok
    end

    def on_words_sep tok
      debug_on tok
      return if maybe_plit_ending(tok)

      add :rem_words_sep, tok
    end

    alias on_lbracket     on_lparen
    alias on_qsymbols_beg on_words_beg
    alias on_qwords_beg   on_words_beg
    alias on_rbracket     on_rparen
    alias on_symbols_beg  on_words_beg
  end # class Parser

  @@extra_keywords = {}

  attr_writer :extra_keywords
  attr_accessor :point_min
  attr_accessor :point_max
  attr_accessor :first_count
  attr_accessor :buffer
  attr_accessor :debug

  def initialize
    self.extra_keywords = nil
    self.first_count    = nil
    self.buffer         = ''
    self.debug          = false
  end

  def d o
    return unless debug
    require "pp"
    o = o.pretty_inspect unless String === o
    puts o.gsub(/^/, "     # ")
  end

  def add_content cmd, point_min, point_max, pbeg, len, content
    self.point_min = point_min.to_i
    self.point_max = point_max.to_i

    pbeg = pbeg.to_i

    self.first_count = pbeg if !first_count || pbeg < first_count

    if cmd == :r || buffer.empty? then
      self.buffer = content
    else
      len = pbeg + len.to_i - 2
      if pbeg == 1 && len < 0 then
        buffer[0..0] = content << buffer[0]
      else
        buffer[pbeg - 1..len] = content
      end
    end
  end

  # verify that this is used in erm.rb. I don't know how to trigger it. & args??
  def check_syntax fname = '', code = buffer
    $VERBOSE = true
    # eval but do not run code
    eval "BEGIN{return}\n#{code}", nil, fname, 0
  rescue SyntaxError
    $!.message
  rescue
    # do nothing
  ensure
    $VERBOSE = nil
  end

  def parse
    parser = ErmBuffer::Parser.new(self, buffer,
                                   point_min, point_max,
                                   first_count||0)
    self.first_count = nil
    parser.parse
  end

  def self.set_extra_keywords keywords
    @@extra_keywords = Hash[keywords.map { |o| [o, true] }]
  end

  def set_extra_keywords keywords
    self.extra_keywords = Hash[keywords.map { |o| [o, true] }]
  end

  def extra_keywords
    @extra_keywords || @@extra_keywords
  end
end # class ErmBuffer
