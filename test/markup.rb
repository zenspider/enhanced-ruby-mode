# -*- coding: utf-8 -*-
require 'strscan'
require_relative '../ruby/erm_buffer'

module Markup
  module_function

  def parse_code(code, erm_buffer = ErmBuffer.new)
    erm_buffer.add_content(:r, 1, code.size + 1, 0, code.size, code)
    erm_buffer.parse
  end

  # Parses marked-up code and returns [raw_sexp, code]
  # raw_sexp follows the same format as the return value of ErmBuffer::Parser#parse.
  def parse_markup(str)
    code = ""
    indent_stack = []
    result = Hash.new { |h, k| h[k] = [] }
    last_tag = nil

    ss = StringScanner.new(str)
    loop do
      case
      when ss.scan(/«@(.)»/)
        indent_stack << ss[1] << code.size + 1
      when ss.scan(/«(\w+)»/)
        last_tag << code.size + 1 if last_tag && last_tag.size.odd? # close last_tag
        last_tag = (result[ss[1]] << code.size + 1)
      when ss.scan(%r|«/\w*»|)
        last_tag << code.size + 1
      when ss.scan(/[^«]+/), ss.scan(/«[^@\w]/)
        code << ss[0]
      when ss.eos?
        last_tag << code.size + 1 if last_tag && last_tag.size.odd? # close last_tag
        break
      else
        raise "Failed at #{ss.charpos}"
      end
    end

    result = result.sort_by { |k, v| k.to_i }.map { |k, v|
      "(%d %s)" % [k, v.join(" ")] if v
    }

    sexp = "((%s %s %s %s)%s)" % [code.size,
                                  1,
                                  code.size + 1,
                                  indent_stack.join(' '),
                                  result.join]
    [sexp, code]
  end

  # Parses the return value of ErmBuffer::Parser#parse into Array
  def parse_sexp(str)
    paren_stack = []
    result = []

    ss = StringScanner.new(str)
    until ss.eos?
      case
      when ss.scan(/\(/)
        if paren_stack.empty?
          paren_stack.push(result)
        else
          paren_stack.push([])
        end
      when ss.scan(/\)/)
        if paren_stack != [result]
          result.push(paren_stack.pop)
        end
      when ss.scan(/\s+/)
        # skip spaces
      when ss.scan(/([^\s()]+)/)
        paren_stack.last.push(ss[1])
      else
        raise "Failed at #{ss.charpos}."
      end
    end

    result
  end

  def markup(code, parsed_sexp, options = {})
    options = {
      :indent    => true,
      :highlight => true,
      :close_tag  => false,
    }.merge(options)

    indents, highlights = parsed_sexp[0][3..-1], parsed_sexp[1..-1]
    tags = [] # [["«tag»", insert_position], ... ]

    if options[:indent]
      indents.each_slice(2).each do |symbol, index|
        tags << ["«@#{symbol}»", index.to_i]
      end
    end

    if options[:highlight]
      highlights.map do |(id, *ranges)|
        ranges.each_slice(2) do |open, close|
          tags << ["«#{id}»", open.to_i]
          tags << ["«/#{id}»", close.to_i] if options[:close_tag]
        end
      end
    end

    markup = code.dup
    offset = 0
    tags.sort_by { |(tag, index)|
      # Sort tags like «/close»«@indent»«open» for human-readability.
      type = case tag[1]
             when "/" # close tag
               0
             when "@" # indent tag
               1
             else     # open tag
               2
             end
      [index, type]
    }.each do |(tag, index)|
      markup.insert(index - 1 + offset, tag)
      offset += tag.size
    end

    markup
  end
end
