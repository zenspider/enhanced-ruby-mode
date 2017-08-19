# -*- coding: utf-8 -*-

gem "minitest"
require "minitest/autorun"

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))

require 'ruby/erm_buffer.rb'
require 'test/helper'

class TestErmBuffer < Minitest::Test
  def parse_text(text,buf=ErmBuffer.new)
    buf.add_content(:r,1,text.size,0,text.size,text)
    buf.parse
  end

  def setup
    super
    ErmBuffer.set_extra_keywords({})
  end

  def test_continations
    assert_parse(%q{
«0»
a,
«@c»b
})
  end

  def test_symbols
    assert_parse('«5»:aaa')
    assert_parse('«5»:@aa')
    assert_parse('«5»:@@a')
    assert_parse('«5»:$aa')
    assert_parse('«5»:<=>')
    assert_parse('«5»:aa')
    assert_parse('«5»:==')
    assert_parse('«5»:a')
    assert_parse('«5»:+')
    assert_parse('«5»:=')
  end

  def test_extra_keywords
    ErmBuffer.set_extra_keywords(%w[require])
    assert_parse(%q{
«10»require«0» «7»'«1»abc«7»'«0»
x.require z
x.
«@c»«10»require
})
  end

  def test_buffer_local_extra_keywords
    ErmBuffer.set_extra_keywords(%w[global])
    local_buf=ErmBuffer.new
    local_buf.set_extra_keywords(%w[local])
    assert_parse(%q{«0»global «10»local}, local_buf)
  end

  def test_reset_mode
   assert_parse(%q{
«0»a«12»=«11»<<END«0»
«3»#«@d»{«0»
  «5»:x«0» «12»==«0» d
«@e»«3»}«1»
«11»END
})
  end

  def test_heredoc_multi
    assert_parse(%q{
«0»a«12»=«11»<<E«0»,«11»<<D«0»
«1»e
«11»E
«1»d
«11»D
})
  end

  def test_heredoc_nesting
    assert_parse(%q{
«0»a«12»=«11»<<E«0»
«1»a
«3»#«@d»{«11»<<EE«0»
«11»EE
«@e»«3»}«1»
«11»E
})
  end

  def test_heredoc_nesting_and_quoting
    assert_parse(%q{
«0»a«12»=«0» «11»<<E«0»,«11»<<-'D'«0»,«5»:b«0»
«1»se«3»#«@d»{«0»
«11»<<E«0»
«1»inner E
«11»E
«@e»«3»}«1»ee
«11»E
«1»sd#{md}ed
«11»   D
«0»
p a
})
  end

  def test_class
    assert_parse(%q{
«@b»«10»class«0» «2»Abc«0»
«@e»«10»end
})
  end

  def test_def
    assert_parse(%q{
«@b»«10»def«0» «9»simple«@l»«0»(a,b«@r»)
  «5»:if«0»
«@e»«10»end«0»

«@b»«10»def«0» «2»Const«0».«9»method«0»
  ident
«@e»«10»end«0»

«@b»«10»def«0» «10»self«0».«9»m«@l»«0»(a,
           «12»&«0»block«@r»)
  body
«@e»«10»end«0»

«@b»«10»def«0» «@l»(a «12»+«0» b «@d»«10»{«@l»«3»|«0»a«@r»«3»|«0»
  «@b»«10»def«0» «9»a«0»
  «@e»«10»end«0»
«@e»«10»}«@r»«0»).«9»d«@l»«0»(a«@r»)
  body
«@s»«10»rescue«0» «2»Exception«0» «12»=>«0» e
  raise
«@e»«10»end
})
  end


  def test_heredoc_followed_by_if_arg
    assert_parse(%q{
«0»bob«@l»(«11»<<-END«0», «@b»«10»if«0» a
«1»fdssdfdsf
            dfsdfs"
«11»END
«0»
              fds
            «@s»«10»elsif«0» b
              fds
            «@e»«10»end«0»
«@r»)

a «10»if«0» b
c

a«@l»(sdfdsf«@l»(«@r»),
  «@b»«10»if«0» fds
    dfs
  «@e»«10»end«0»
  «@r»)
})
  end

  def test_if
    assert_parse(%q{
«0»a «10»if«0» dsf
«@b»«10»if«0» a
  b
«@s»«10»else«0»
  c
«@e»«10»end«0»

b«12»=«0»d «10»if«0» sdf

a«10»;«0» «@b»«10»if«0» b
     c
   «@e»«10»end«0»

a«@l»(b,«@b»«10»if«0» c
      d
    «@e»«10»end«0»
  «@r»)

a«@l»(«@b»«10»if«0» c
    d
  «@e»«10»end«0»
  «@r»)

a«12»=«@l»«0»{«5»a:«0» fds,
   «5»:b«0» «12»=>«0» fds
   «@r»}
})
  end

  def test_utf8_here_docs
    assert_parse(%q{
«3»@ü«12»=«11»<<E«0»
«1»á
«11»E
})
  end

  def test_interpolated_string
    assert_parse(%q{«7»"«3»#«@d»{«0»1«@e»«3»}«7»"})

    assert_parse(%q{
«0»puts «7»"«3»#«@d»{«0»
  «@l»[1, 2, 3«@r»].map «@d»«10»do«0» «@l»«3»|«0»i«@r»«3»|«0»
    p «7»"«3»#«@d»{«0»
      i«12»*«0»i
    «@e»«3»}«7»"«0»
  «@e»«10»end«0»
«@e»«3»}«7»"
})
  end

  def test_keyword_do_block
    assert_parse(%q{
«0»each «@d»«10»do«0»
«@e»«10»end
})
  end

  def test_keyword_do_cond
    assert_parse(%q{
«@b»«10»while«0» «10»false«0» «10»do«0»
«@e»«10»end
})

    assert_parse(%q{
«@b»«10»while«0» «@l»(«@b»«10»until«0» «10»false«0» «10»do«0»
       «@e»«10»end«@r»«0») «10»do«0»
«@e»«10»end
})
  end

  def test_percent_literals_w
    assert_parse(%q{
«@l»«0»[
  «7»"«1»one«7»"«0»
«@r»]
«@l»[«7»"«1»one«7»"«@r»«0»]

«@l»%w(
  one
«@r»)
«@l»%W( one «3»#«@d»{«5»:two«@e»«3»}«0» «@r»)

«@b»«10»begin«0»
  a «12»=«0» «@l»[
    «7»"«1»one«7»"«0»
  «@r»]
  a «12»=«0» «@l»%w[
    one
  «@r»]
«@e»«10»end
})
  end

  def test_percent_literals_i
    # %i didn't exist before ruby 2.0
    return if RUBY_VERSION.split(".").first.to_i < 2

    assert_parse(%q{
«@l»«0»%i[one «@r»]

«@l»%I'a \#{a}«@r»'
«@l»%I'a «3»#«@d»{«0»a«@e»«3»}«@r»«0»'
})
  end

  def test_dot_indent
    assert_parse(%q{
«0»a.b

c.
«@c»  d

g
«@c»  .h

i.j
«@c»  .h
})
  end
end
