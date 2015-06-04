require 'ripper'

class ErmBuffer
  module Adder
    def nadd sym, tok, len = tok.size, ft = false, la = nil
      case sym
      when :sp, :comment then
        case parser.mode
        when :predef, :expdef then
        else
          parser.mode = nil
        end
      else
        @statment_start = false

        parser.mode = :def if parser.mode == :predef
        @block = false     if @block == :b4args

        case sym
        when :ident, :const then
          @ident = true
        else
          @ident = false
        end
      end

      @first_token = ft
      @last_add = la

      target = parser.equal?(self) || lineno != parser.lineno ? self : prev
      target.realadd sym, tok, len

      sym
    end
  end

  class Heredoc
    include Adder

    attr_accessor :lineno, :lines, :parser, :prev, :tok

    def initialize parser, prev, tok, lineno
      # TODO: tok?
      @parser = parser
      @prev   = prev
      @lineno = lineno
      @lines  = []
      @block  = nil
    end

    def realadd(*args)
      @lines << args
    end

    def restore
      @lines << [:heredoc_end, nil, nil] if lines.empty?
      if parser.equal? prev then
        for args in lines
          parser.nadd(*args)
        end
        parser.heredoc = nil
      else
        @prev.lines += lines
        parser.heredoc = @prev
      end
    end
  end

  class Parser < ::Ripper   #:nodoc: internal use only
    include Adder

    INDENT_KW          = [:begin, :def, :case, :module, :class, :do, :for]
    BACKDENT_KW        = [:elsif, :else, :when, :rescue, :ensure]
    BEGINDENT_KW       = [:if, :unless, :while, :until]
    POSTCOND_KW        = [:if, :unless, :or, :and]
    PRE_OPTIONAL_DO_KW = [:in, :while, :until]
    DELIM_MAP          = { "(" => ")", "[" => "]", "{" => "}" }

    ESCAPE_LINE_END    = "\\\n"

    attr_accessor :heredoc, :mode
    attr_accessor :indent_stack, :ident_stack, :brace_stack

    def initialize ermbuffer, src, point_min, point_max, first_count
      @ermbuffer     = ermbuffer
      @point_min     = point_min
      @point_max     = point_max
      @src           = src
      @src_size      = src.size
      @file_encoding = @src.encoding
      @first_count   = nil
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
      @count          = 1
      @mode           = nil
      @brace_stack    = []
      @heredoc        = nil
      @first_token    = true
      @last_add       = nil
      @res            = []
      @ident          = false
      @ident_stack    = []
      @block          = false
      @statment_start = true
      @indent_stack   = []
      @list_count     = 0
      @cond_stack     = []
      @plit_stack     = []

      catch :parse_complete do
        super

        realadd :rem, '', @src_size-@count if heredoc
      end

      res = @res.map.with_index { |v, i|
        "(%d %s)" % [i, v.join(" ")] if v
      }

      "((%s %s %s %s)%s)" % [@src_size,
                             @point_min,
                             @point_max,
                             @indent_stack.join(' '),
                             res.join]
    end

    def parser # TODO: remove
      self
    end

    def realadd sym, tok, len
      if sym == :indent
        pos = @count + len
        @indent_stack << tok << pos if pos.between? @point_min, @point_max

        return
      end

      start = @count
      throw :parse_complete if start > @point_max

      len = 2 + @src.index("\n", start) - start unless len

      pos = @count += len
      return if pos < @point_min
      start = @point_min if start < @point_min
      pos = @point_max   if pos   > @point_max

      idx = FONT_LOCK_NAMES[sym]

      if t = @res[idx] then
        if t.last == start then
          t[-1] = pos
        else
          t << start << pos
        end
      else
        @res[idx] = [start, pos]
      end

      throw :parse_complete if pos == @point_max
    end

    def maybe_plit_ending tok
      if tok[-1] == @plit_stack.last
        @plit_stack.pop

        # Token can sometimes have preceding whitespace, which needs to be added
        # as a separate token to work with indents.
        if tok.length > 1
          add :rem, tok[0..-2]
        end
        indent :r
        add :rem, tok[-1]
      end
    end

    ############################################################
    # on_* handlers

    [:CHAR, :__end__, :backtick, :embdoc, :embdoc_beg, :embdoc_end,
     :label, :tlambda, :tstring_beg].each do |event|
      define_method "on_#{event}" do |tok|
        tok.force_encoding @file_encoding if tok.encoding != @file_encoding
        add event, tok
      end
    end

    [:backref, :float, :int].each do |event|
      define_method "on_#{event}" do |tok|
        add :rem, tok
      end
    end

    [:cvar, :gvar, :ivar].each do |event|
      define_method "on_#{event}" do |tok|
        if @mode == :sym then
          add :label, tok
        else
          add event, tok
        end
      end
    end

    def on_comma tok
      @mode = nil
      r = add :rem, tok, tok.size, false, @list_count <= 0
      @statment_start = true
      r
    end

    def on_comment tok
      on_eol :comment, tok
    end

    def on_const tok
      case @mode
      when :sym then
        @mode = nil
        add :label, tok
      when :def, :predef then
        r = add :const, tok # TODO: why this order?
        @mode = :predef
        r
      else
        add :const, tok
      end
    end

    def on_embexpr_beg tok
      len = tok.size
      if len > 2 then
        add :tstring_content, tok, len - 2
        len = 2
      end

      @brace_stack << :embexpr
      @cond_stack << false
      @plit_stack << false

      indent :d, 1
      add :embexpr_beg, tok, len
    end

    def on_embexpr_end tok
      @brace_stack.pop
      @cond_stack.pop
      @plit_stack.pop
      indent :e
      add :embexpr_beg, tok
    end

    def on_embvar tok
      len = tok.size
      if len > 1 then
        add :tstring_content, tok, len - 1
        len = 1
      end

      add :ivar, tok, len
    end

    def on_eol sym, tok
      indent :c, tok.size if @last_add

      r = add sym, tok, tok.size, true

      if heredoc && heredoc.lineno == lineno then
        heredoc.restore
      end

      @cond_stack.pop if @cond_stack.last
      @statment_start = true

      r
    end

    def on_heredoc_beg tok
      r = add :heredoc_beg, tok
      if !heredoc || heredoc.lineno < lineno then
        self.heredoc = Heredoc.new self, heredoc||self, tok, lineno
      end
      r
    end

    def on_heredoc_end tok
      add :heredoc_end, tok
    end

    def on_ident tok
      case @mode
      when :sym then
        add :label, tok
      when :predef, :def then
        add :defname, tok
      when :period then
        add :ident, tok
      else
        if @ermbuffer.extra_keywords.include? tok then
          add :kw, tok
        else
          add :ident, tok
        end
      end
    end

    def on_ignored_nl tok
      unless tok.nil?
        on_nl tok
      end
    end

    def on_kw sym # TODO: break up. 61 lines long
      sym = sym.to_sym
      case @mode
      when :sym then
        add :label, sym
      when :def, :predef then
        if sym != :self then
          add :defname, sym
        else
          r = add :kw, sym
          @mode = :def
          r
        end
      else
        last_add = nil

        case sym
        when :end then
          indent :e
        when :do then
          if @cond_stack.last then
            @cond_stack.pop
            r = add :kw, sym
          else
            # `indent` precedes `add` for the compatibility of parsing result.
            #
            # `add` and `indent` must precede `@block = :b4args`.
            # Otherwise @block is overwritten, and indentation is broken
            # in the following code:
            #  each do |a| # <- `|` for argument list is recognized as operator,
            #      # <- which produces an extra indentation.
            #  end

            indent :d
            r = add :kw, sym
            @block = :b4args
          end

          return r
        when *BEGINDENT_KW then
          if @statment_start then
            indent :b
          elsif POSTCOND_KW.include? sym then
            last_add = :cont
          end
        when *POSTCOND_KW then
          last_add = :cont
        when *INDENT_KW then
          indent :b
        when *BACKDENT_KW then
          indent :s if @statment_start
        end

        @cond_stack << true if PRE_OPTIONAL_DO_KW.include? sym

        r = add :kw, sym, sym.size, false, last_add
        @mode = :predef if [:def, :alias].include? sym
        r
      end
    end

    def on_lbrace tok
      @cond_stack << false
      if @ident then
        @brace_stack << :block
        indent :d
        r = add :block, tok
        @block = :b4args
        r
      else
        @brace_stack << :brace
        @list_count += 1
        indent :l
        add :rem, tok
      end
    end

    def on_lparen tok
      mode = case @mode
             when :def then
               @mode = nil
             when :predef then
               @mode = :expdef
               :predef
             else
               @mode
             end

      @ident_stack << [@ident, mode]
      @cond_stack << false
      indent :l
      @list_count += 1
      r = add :rem, tok
      @statment_start = true
      r
    end

    def on_nl tok
      on_eol :sp, tok
    end

    def on_op tok
      if @mode == :sym then
         add :label, tok
      else
        @mode = nil
        r = if @block && tok == '|'
            case @block
            when :b4args then
              indent :l
              @list_count += 1
              @block = :arglist
            else
              indent :r
              @list_count -= 1
              @block = false
            end
            add :arglist, tok, 1
          else
            add :op, tok, tok.size, false, :cont
          end
        @statment_start = true
        r
      end
    end

    def on_period tok
      @mode ||= :period
      indent :c, tok.size if tok == "\n"
      add :rem, tok, tok.size, false, :cont
    end

    def on_rbrace tok
      @cond_stack.pop
      type = case @brace_stack.pop
             when :embexpr then
               indent :e
               if @plit_stack.last == false
                 @plit_stack.pop
               end
               :embexpr_beg
             when :block then
               indent :e
               :block
             when :brace then
               indent :r
               @list_count -= 1
               :rem
             else
               :rem
             end

      add type, tok
    end

    def on_regexp_beg tok
      tok.force_encoding @file_encoding if tok.encoding != @file_encoding
      @mode = :regexp
      add :regexp_beg, tok
    end

    def on_regexp_end tok
      @mode = nil
      add :regexp_end, tok
    end

    def on_rparen tok
      indent :r
      r = add :rem, tok

      @list_count -= 1
      @ident, @mode = @ident_stack.pop
      @cond_stack.pop

      r
    end

    def on_semicolon tok
      r = add :kw, :semicolon, 1, true
      @cond_stack.pop if @cond_stack.last
      @statment_start = true
      r
    end

    def on_sp tok
      if tok == ESCAPE_LINE_END then
        indent :c, 2
      end
      add :sp, tok, tok.size, @first_token, @last_add
    end

    def on_symbeg tok
      r = add :label, tok
      @mode = :sym
      r
    end

    def on_tlambeg tok
      @brace_stack << :block
      indent :d
      add :block, tok
    end

    def on_tstring_content tok
      tok.force_encoding @file_encoding if tok.encoding != @file_encoding
      if @mode == :regexp
        add :regexp_string, tok
      elsif @plit_stack.last # `tstring_content` is ignored by indent in emacs.
        add :rem, tok
      else
        add :tstring_content, tok
      end
    end

    def on_tstring_end tok
      return if maybe_plit_ending(tok)

      if @mode == :sym then
        add :label, tok
      else
        add :tstring_beg, tok
      end
    end

    def on_words_beg tok
      delimiter = tok.strip[-1]  # ie. "%w(\n" => "("
      @plit_stack << (DELIM_MAP[delimiter] || delimiter)

      indent :l
      add :rem, tok
    end

    def on_words_sep tok
      return if maybe_plit_ending(tok)

      add :rem, tok
    end

    alias on_lbracket     on_lparen
    alias on_qsymbols_beg on_words_beg
    alias on_qwords_beg   on_words_beg
    alias on_rbracket     on_rparen
    alias on_symbols_beg  on_words_beg
  end

  FONT_LOCK_NAMES= {
    rem:             0,  # 'remove' TODO: make this more debuggable
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

  @@extra_keywords = {}

  attr_reader :buffer

  def initialize
    @extra_keywords = nil
    @first_count    = nil
    @buffer         = ''
  end

  def add_content cmd, point_min, point_max, pbeg, len, content
    @point_min = point_min.to_i
    @point_max = point_max.to_i

    pbeg = pbeg.to_i

    @first_count = pbeg if !@first_count || pbeg < @first_count

    if cmd == :r || @buffer.empty? then
      @buffer = content
    else
      len = pbeg + len.to_i - 2
      if pbeg == 1 && len < 0 then
        @buffer[0..0] = content << @buffer[0]
      else
        @buffer[pbeg - 1..len] = content
      end
    end
  end

  # verify that this is used in erm.rb. I don't know how to trigger it. & args??
  def check_syntax fname = '', code = @buffer
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
    parser = ErmBuffer::Parser.new(self, @buffer,
                                   @point_min, @point_max,
                                   @first_count||0)
    @first_count = nil
    parser.parse
  end

  def self.set_extra_keywords keywords
    @@extra_keywords = Hash[keywords.map { |o| [o, true] }]
  end

  def set_extra_keywords keywords
    @extra_keywords = Hash[keywords.map { |o| [o, true] }]
  end

  def extra_keywords
    @extra_keywords || @@extra_keywords
  end
end
