# -*- coding: utf-8 -*-

gem "minitest"
require "minitest/autorun"

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))

require 'ruby/erm_buffer.rb'

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
    assert_equal "((11 1 11 c 5)(0 1 7))",
    parse_text(%q{
a,
b
     })
  end

  def test_symbols
    exp="((4 1 4 )(5 1 4))"
    assert_equal(exp, parse_text(':aaa'))
    assert_equal(exp, parse_text(':@aa'))
    assert_equal(exp, parse_text(':@@a'))
    assert_equal(exp, parse_text(':$aa'))
    assert_equal(exp, parse_text(':<=>'))
    exp="((3 1 3 )(5 1 3))"
    assert_equal(exp, parse_text(':aa'))
    assert_equal(exp, parse_text(':=='))
    exp="((2 1 2 )(5 1 2))"
    assert_equal(exp, parse_text(':a'))
    assert_equal(exp, parse_text(':+'))
    assert_equal(exp, parse_text(':='))
  end

  def test_extra_keywords
    ErmBuffer.set_extra_keywords(%w[require])
    assert_equal "((43 1 43 c 31)(0 1 2 9 10 15 31 38 39)(1 11 14)(7 10 11 14 15)(10 2 9 31 38))",
    parse_text(%q{
require 'abc'
x.require z
x.
require
     })
  end

  def test_buffer_local_extra_keywords
    ErmBuffer.set_extra_keywords(%w[global])
    local_buf=ErmBuffer.new
    local_buf.set_extra_keywords %w[local]
    assert_equal "((19 1 19 )(0 1 9 14 15)(10 9 14))",
    parse_text(%q{
global local
     },local_buf)
  end

  def test_reset_mode
    assert_equal "((32 1 32 d 10 e 22)(0 1 2 8 9 11 14 16 17 19 22)(1 23 24)(3 9 11 22 23)(5 14 16)(11 3 8 24 28)(12 2 3 17 19))",
     parse_text(%q{a=<<END
#{
  :x == d
}
END
     }
                )
  end

  def test_heredoc_multi
    assert_equal "((23 1 23 )(0 1 2 6 7 10 11)(1 11 13 15 17)(11 3 6 7 10 13 15 17 19)(12 2 3))",
     parse_text(%q{a=<<E,<<D
e
E
d
D
     }
                )
  end

  def test_heredoc_nesting
    assert_equal "((27 1 27 d 10 e 19)(0 1 2 6 7 15 16)(1 7 9 20 21)(3 9 11 19 20)(11 3 6 11 15 16 19 21 23)(12 2 3))",
     parse_text(%q{a=<<E
a
#{<<EE
EE
}
E
     }
                )
  end

  def test_heredoc_nesting_and_quoting
    assert_equal "((62 1 62 d 22 e 38)(0 1 3 4 5 8 9 15 16 18 19 23 24 27 28 59 62)(1 19 21 28 36 39 42 44 54)(3 21 23 38 39)(5 16 18)(11 5 8 9 15 24 27 36 38 42 44 54 59)(12 3 4))",
     parse_text(%q{
a= <<E,<<-'D',:b
se#{
<<E
inner E
E
}ee
E
sd#{md}ed
   D

p a}
                )
  end

  def test_class
    assert_equal "((14 1 14 b 2 e 12)(0 1 2 7 8 11 12)(2 8 11)(10 2 7 12 14))",
     parse_text(%q{
class Abc
end}
                )
  end

  def test_def
    assert_equal "((180 1 180 b 1 l 11 r 15 e 23 b 28 e 53 b 58 l 68 r 89 e 98 b 103 l 107 d 114 l 115 r 117 b 121 e 129 e 133 r 134 l 137 r 139 s 148 e 178)(0 4 5 11 19 22 23 26 28 31 32 37 38 44 53 56 58 61 62 66 67 68 83 84 98 101 103 106 110 111 114 116 117 118 121 124 125 126 129 132 133 134 136 137 148 154 155 164 165 167 178)(2 32 37 155 164)(3 115 116 117 118)(5 19 22)(9 5 11 38 44 67 68 125 126 136 137)(10 1 4 23 26 28 31 53 56 58 61 62 66 98 101 103 106 114 115 121 124 129 132 133 134 148 154 178 180)(12 83 84 110 111 165 167))",
     parse_text(%q{def simple(a,b)
  :if
end

def Const.method
  ident
end

def self.m(a,
           &block)
  body
end

def (a + b {|a|
  def a
  end
}).d(a)
  body
rescue Exception => e
  raise
end}
                )
  end


  def test_heredoc_followed_by_if_arg
    assert_equal "((182 1 182 l 5 b 14 s 84 e 122 r 126 l 140 l 147 r 148 b 153 e 170 r 176)(0 1 6 12 14 16 19 53 84 89 122 125 131 133 153 155 170 173 178)(1 19 49)(10 14 16 84 89 122 125 131 133 153 155 170 173)(11 6 12 49 53))",
     parse_text(%q{
bob(<<-END, if a
fdssdfdsf
            dfsdfs"
END

              fds
            elsif b
              fds
            end
)

a if b
c

a(sdfdsf(),
  if fds
    dfs
  end
  )
     }
                )
  end

  def test_if
    assert_equal "((156 1 156 b 11 s 20 e 29 b 49 e 64 l 70 b 73 e 90 r 96 l 100 b 101 e 114 r 120 l 125 r 150)(0 1 4 6 11 13 20 24 29 32 35 36 38 40 47 48 49 51 64 67 73 75 90 93 101 103 114 117 124 125 126 128 137 139 140 142 152)(5 126 128 137 139)(10 4 6 11 13 20 24 29 32 38 40 47 48 49 51 64 67 73 75 90 93 101 103 114 117)(12 35 36 124 125 140 142))",
     parse_text(%q{
a if dsf
if a
  b
else
  c
end

b=d if sdf

a; if b
     c
   end

a(b,if c
      d
    end
  )

a(if c
    d
  end
  )

a={a: fds,
   :b => fds
   }
     }
                )
  end

  def test_utf8_here_docs
    assert_equal "((11 1 11 )(0 7 8)(1 8 10)(3 1 3)(11 4 7 10 11)(12 3 4))",
     parse_text(%q{@ü=<<E
á
E
}
                )
  end

  def test_interpolated_string
    assert_equal "((6 1 6 d 3 e 5)(0 4 5)(3 2 4 5 6)(7 1 2))",
      parse_text(%q{"#{1}"})

    assert_equal "((75 1 75 d 9 l 13 r 21 d 27 l 30 r 32 d 42 e 58 e 63 e 67)(0 1 7 10 27 29 30 31 32 33 40 43 51 52 58 60 63 66 67 69 70)(3 8 10 30 31 32 33 41 43 58 59 67 68)(7 7 8 40 41 59 60 68 69)(10 27 29 63 66)(12 51 52))",
      parse_text(%q{
puts "#{
  [1, 2, 3].map do |i|
    p "#{
      i*i
    }"
  end
}"
      }
                )
  end
end
