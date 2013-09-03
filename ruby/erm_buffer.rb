require 'ripper'

class ErmBuffer
  module Adder
    def nadd(sym,tok,len=tok.size,ft=false,la=nil)
      case sym
      when :sp, :comment
        case parser.mode
        when :predef, :expdef
        else
          parser.mode=nil
        end
      else
        @statment_start=false
        parser.mode=:def if parser.mode==:predef
        @block=false if @block==:b4args
        case sym
        when :ident, :const
          @ident=true
        else
          @ident=false
        end
      end

      @first_token=ft
      @last_add=la

      target = parser.equal?(self) || lineno != parser.lineno() ? self : prev
      target.realadd(sym, tok, len)

      sym
    end
  end

  class Parser < ::Ripper   #:nodoc: internal use only
    include Adder

    attr_accessor :heredoc, :mode

    def parser
      self
    end

    def add(*args)
      (heredoc || self).nadd(*args)
    end

    def realadd(sym,tok,len)
      if sym == :indent
        pos = @count + len
        @indent_stack << tok << pos if pos.between? @point_min, @point_max

        return
      end


      if (start=@count) > @point_max
        throw :parse_complete
      end

      unless len
        len=2+@src.index("\n",start)-start
      end
      return if (pos=@count+=len) < @point_min
      start=@point_min if start < @point_min
      pos= @point_max if pos > @point_max

      idx=FONT_LOCK_NAMES[sym]
      if t=@res[idx]
        if t.last == start
          t[-1]=pos
        else
          t << start << pos
        end
      else
        @res[idx]= [start, pos]
      end
      if pos == @point_max
        throw :parse_complete
      end
    end

    class Heredoc
      include Adder

      attr_accessor :tok, :lineno, :prev, :lines, :parser

      def initialize(parser,prev,tok,lineno)
        @parser=parser
        @lineno=lineno
        @prev=prev
        @lines=[]
      end

      def restore
        @lines << [:heredoc_end,nil,nil] if lines.empty?
        if parser.equal?(prev)
          for args in lines
            parser.nadd(*args)
          end
          parser.heredoc=nil
        else
          @prev.lines+=lines
          parser.heredoc=@prev
        end
      end

      def realadd(*args)
        @lines << args
      end
    end

    def initialize(ermbuffer,src,point_min,point_max,first_count)
      @ermbuffer=ermbuffer
      @point_min=point_min
      @point_max=point_max
      @src=src
      super(src)
      @src_size=src.size
      @file_encoding=@src.encoding
      @first_count = 0
      # @first_count=first_count > 5 ? (src[0..first_count].rindex("\n")||0) : 0  # FIXME
    end

    def on_backref(tok)
      add(:rem,tok)
    end

    for sym in [:float, :int, :qwords_beg, :words_beg, :words_sep]
      alias_method "on_#{sym}", :on_backref
    end

    [:CHAR, :__end__, :label, :tstring_content, :regexp_beg,
     :backtick, :tstring_beg, :tlambda,
     :embdoc_beg, :embdoc, :embdoc_end].each do |event|
      module_eval(<<-End, __FILE__, __LINE__ + 1)
        def on_#{event}(tok)
          tok.force_encoding(@file_encoding) unless tok.encoding.equal?(@file_encoding)
          add(:#{event},tok)
        end
      End
    end

    def on_ivar(tok);_on_var(tok,:ivar);end
    def on_cvar(tok);_on_var(tok,:cvar);end
    def on_gvar(tok);_on_var(tok,:gvar);end

    def _on_var(tok,sym)
      if @mode == :sym
        add(:label,tok)
      else
        add(sym,tok)
      end
    end

    def self.make_hash(list)
      list.inject({}){|h,k| h[k]=true; h}
    end

    INDENT_KW    = make_hash [:begin, :def, :case, :module, :class, :do]
    BACKDENT_KW  = make_hash [:elsif, :else, :when, :rescue, :ensure]
    BEGINDENT_KW = make_hash [:if, :unless, :while, :until]
    POSTCOND_KW  = make_hash [:if, :unless, :or, :and]

    def on_op(tok)
      if @mode == :sym
         add(:label,tok)
      else
        @mode=nil
        r=if @block && tok == '|'
            case @block
            when :b4args
              indent(:l)
              @list_count+=1
              @block=:arglist
            else
              indent(:r)
              @list_count-=1
              @block=false
            end
            add(:arglist, tok, 1)
          else
            add(:op, tok, tok.size, false, :cont)
          end
        @statment_start=true
        r
      end
    end

    def on_period(tok)
      @mode||=:period
      add(:rem, tok, tok.size, false, :cont)
    end

    def on_eol(sym,tok)
      if @last_add
        indent(:c,tok.size)
      end
      r=add(sym,tok,tok.size,true)
      if heredoc && heredoc.lineno == lineno()
        heredoc.restore
      end
      @statment_start=true
      r
    end

    def on_nl(tok)
      on_eol(:sp,tok)
    end
    alias on_ignored_nl on_nl

    def on_comment(tok)
      on_eol(:comment,tok)
    end

    def on_semicolon(tok)
      r=add(:kw,:semicolon,1,true)
      @statment_start=true
      r
    end

    def on_comma(tok)
      @mode=nil
      r=add(:rem,tok, tok.size, false, @list_count <= 0)
      @statment_start=true
      r
    end

    ESCAPE_LINE_END="\\\n"

    def on_sp(tok)
      if tok == ESCAPE_LINE_END
        indent(:c,2)
      end
      add(:sp,tok,tok.size,@first_token,@last_add)
    end

    def on_heredoc_beg(tok)
      r=add(:heredoc_beg,tok)
      if !heredoc || heredoc.lineno < lineno
        self.heredoc=Heredoc.new(self,heredoc||self,tok,lineno())
      end
      r
    end

    def on_heredoc_end(tok)
      add(:heredoc_end,tok)
    end

    def on_tstring_end(tok)
      if @mode == :sym
        add(:label,tok)
      else
        add(:tstring_beg,tok)
      end
    end

    def on_regexp_end(tok)
      add(:regexp_end,tok)
    end

    def on_embvar(tok)
      if (len=tok.size) > 1
        add(:tstring_content,tok,len-1)
        len=1
      end
      add(:ivar,tok,len)
    end

    def on_embexpr_beg(tok)
      if (len=tok.size) > 2
        add(:tstring_content,tok,len-2)
        len=2
      end
      @brace_stack << :embexpr
      indent(:d,1)
      add(:embexpr_beg,tok,len)
    end

    def on_embexpr_end(tok)
      @brace_stack.pop
      indent(:e)
      add(:embexpr_beg,tok)
    end

    def on_tlambeg(tok)
      @brace_stack << :block
      indent(:d)
      add(:block,tok)
    end

    def on_lbrace(tok)
      if @ident
        @brace_stack << :block
        indent(:d)
        r=add(:block,tok)
        @block=:b4args
        r
      else
        @brace_stack << :brace
        @list_count+=1
        indent(:l)
        add(:rem,tok)
      end
    end

    def on_lparen(tok)
      @ident_stack << [@ident, case @mode
                               when :def
                                 @mode=nil
                               when :predef
                                 @mode=:expdef
                                 :predef
                               else
                                 @mode
                               end]
      indent(:l)
      @list_count+=1
      r=add(:rem,tok)
      @statment_start=true
      r
    end

    alias on_lbracket on_lparen

    def on_rparen(tok)
      indent(:r)
      r=add(:rem,tok)
      @list_count-=1
      @ident,@mode=@ident_stack.pop
      r
    end

    alias on_rbracket on_rparen

    def on_rbrace(tok)
      add(case @brace_stack.pop
          when :embexpr
            indent(:e)
            :embexpr_beg
          when :block
            indent(:e)
            :block
          when :brace
            indent(:r)
            @list_count-=1
            :rem
          else
            :rem
          end,tok)
    end

    def on_ident(tok)
      r=case @mode
        when :sym
          add(:label,tok)
        when :predef, :def
          add(:defname,tok)
        when :period
          add(:ident, tok)
        else
          if @ermbuffer.extra_keywords.include? tok
            add(:kw, tok)
          else
            add(:ident, tok)
          end
        end
      r
    end

    def on_symbeg(tok)
      r=add(:label,tok)
      @mode=:sym
      r
    end

    def on_kw(sym)
      sym=sym.to_sym
      case @mode
      when :sym
        add(:label,sym)
      when :def, :predef
        if sym != :self
          add(:defname,sym)
        else
          r=add(:kw,sym)
          @mode=:def
          r
        end
      else
        last_add = nil
        if sym == :end
          indent(:e)
        elsif sym == :do
          indent(:d)
          r=add(:kw,sym)
          @block=:b4args
          return r
        elsif BEGINDENT_KW.include? sym
          if @statment_start
            indent(:b)
          elsif POSTCOND_KW.include? sym
            last_add = :cont
          end
        elsif POSTCOND_KW.include? sym
          last_add = :cont
        elsif INDENT_KW.include? sym
          indent(:b)
        elsif BACKDENT_KW.include? sym
          indent(:s) if @statment_start
        end
        r=add(:kw,sym,sym.size,false,last_add)
        @mode= (sym==:def || sym==:alias) && :predef
        r
      end
    end

    def indent(type,c=0)
      add(:indent,type,c)
    end

    def on_const(tok)
      case @mode
      when :sym
        @mode=nil
        add(:label,tok)
      when :def, :predef
        r=add(:const,tok)
        @mode=:predef
        r
      else
        add(:const, tok)
      end
    end


    # Bugs in Ripper:
    # empty here doc fails to fire on_heredoc_end
    def parse
      @count=1
      @mode=nil
      @brace_stack=[]
      @heredoc=nil
      @first_token=true
      @last_add=nil
      @res=[]
      @ident=false
      @ident_stack=[]
      @block=false
      @statment_start=true
      @indent_stack=[]
      @list_count=0
      catch :parse_complete do
        super
        realadd(:rem,'',@src_size-@count) if heredoc

        # @count+=1
        # while heredoc
        #   heredoc.restore
        # end
      end
      res=@res.map.with_index{|v,i| v ? "(#{i} #{v.join(' ')})" : nil}.flatten.join
      "((#{@src_size} #{@point_min} #{@point_max} #{@indent_stack.join(' ')})#{res})"
    end
  end

  FONT_LOCK_NAMES= {
    rem:             0,  # 'remove'
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
    }

  def initialize
    @extra_keywords = nil
    @first_count = nil
    @buffer=''
  end

  # not used
  def check_syntax(fname='',code=@buffer)
    $VERBOSE=true
    # eval but do not run code
    eval("BEGIN{return}\n#{code}", nil, fname, 0)

  rescue SyntaxError
    $!.message
  rescue
  ensure
    $VERBOSE=nil
  end

  attr_reader :buffer

  def add_content(cmd, point_min, point_max, pbeg, len, content)
    @point_min=point_min.to_i
    @point_max=point_max.to_i
    pbeg=pbeg.to_i
    if !@first_count || pbeg < @first_count
      @first_count=pbeg
    end

    if cmd == :r || @buffer.empty?
      @buffer=content
    else
      len=pbeg+len.to_i-2
      if pbeg==1 && len < 0
        @buffer[0..0]=content << @buffer[0]
      else
        @buffer[pbeg-1..len]=content
      end
    end
  end

  def parse
    parser=ErmBuffer::Parser.new(self,@buffer,@point_min,@point_max,@first_count||0)
    @first_count=nil
    parser.parse
  end

  @@extra_keywords={}
  def self.set_extra_keywords(keywords)
    @@extra_keywords=keywords.each.with_object({}) {|o,h| h[o]=true}
  end

  def set_extra_keywords(keywords)
    @extra_keywords=keywords.each.with_object({}) {|o,h| h[o]=true}
  end

  def extra_keywords
    @extra_keywords || @@extra_keywords
  end
end
