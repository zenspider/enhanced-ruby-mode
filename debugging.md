# How to Debug Problems in ERM

These are notes to myself because I don't work on this project much.

## 0. Run `rake docker` or `rake dockeri` to run tests in isolation.

Make sure that everything else is currently good before you go
debugging new issues.

## 1. First, get a reproduction in a file named bug###.rb.

This helps you track back to a github issue (create one if necessary).

## 2. Reduce the reproduction to the bare minimum.

Usually, there's little need for "real" code and the submission
contains a lot of sub-expressions that can be removed.

```ruby
renewed_clients = @renewed_clients_ransack
  .result
    .order('due_at desc')
    .page(params[:renewed_clients_page])
```

vs:

```ruby
@b
  .c
    .d
```

There's no need for arguments or the extra calls. Even the assignment
can be removed.

Know what the expected result should be. In the case of the above, the
indentation is off and should be:

```ruby
@b
  .c
  .d
```

## 3. Run `rake debug F=bug###.rb` to get relevant output.

This outputs what it sees, not what it thinks it should be. For the
above, the output looks like (with notes inline):

### 3.1. tools/debug.rb:

```ruby
[:ivar, "@b", 2]
[:sp, "\n", 1]
[:sp, "  ", 2]
[:rem, ".", 1]
[:ident, "c", 1]
[:sp, "\n", 1]
[:sp, "    ", 4]
[:indent, :c, -4]
[:rem, ".", 1]
[:ident, "d", 1]
((15 1 16 c 9)(0 3 16)(3 1 3))
```

This is a raw printing of the tokens as they are lexed in triplets of
token type, token value, and length. It is followed with the data that
actually goes back from the ruby process to emacs. This is what is
used to highlight and/or indent.

TODO: I don't know how to read that sexp yet. But I want to document
all of this output first to see if it knocks something loose.

### 3.2. tools/lexer.rb:

This tool is helpful because it only uses Ripper and knows nothing
about ERM.

This is the raw output from Ripper.lex and is basically the events
that will be triggered in ERM:

```ruby
[[[1, 0], :on_ivar, "@b", EXPR_END],
 [[1, 2], :on_ignored_nl, "\n", EXPR_END],
 [[2, 0], :on_sp, "  ", EXPR_END],
 [[2, 2], :on_period, ".", EXPR_DOT],
 [[2, 3], :on_ident, "c", EXPR_ARG],
 [[2, 4], :on_ignored_nl, "\n", EXPR_ARG],
 [[3, 0], :on_sp, "    ", EXPR_ARG],
 [[3, 4], :on_period, ".", EXPR_DOT],
 [[3, 5], :on_ident, "d", EXPR_ARG],
 [[3, 6], :on_nl, "\n", EXPR_BEG]]
```

This is the raw output from Ripper.sexp_raw:

```ruby
[:program,
 [:stmts_add,
  [:stmts_new],
  [:call,
   [:call, [:var_ref, [:@ivar, "@b", [1, 0]]], :".", [:@ident, "c", [2, 3]]],
   :".",
   [:@ident, "d", [3, 5]]]]]
```

This is the raw output from Ripper.sexp and is basically the same
thing but cleaned up / combined a bit:

```ruby
[:program,
 [[:call,
   [:call, [:var_ref, [:@ivar, "@b", [1, 0]]], :".", [:@ident, "c", [2, 3]]],
   :".",
   [:@ident, "d", [3, 5]]]]]
```

### 3.3. tools/markup.rb

```
((15 1 16 c 9)(0 3 16)(3 1 3))
---
«3»@b«0»
  .c
«@c»    .d
```

The sexp, roughly described is:

```ruby
((code.size, 1, code.size+1, indent_stack.join) result.join)
```

TODO: I'm not sure how to read result yet.

## 4. See if you can find the closest passing version of the repro

In this example, if the receiver is not an ivar, it works fine:

```ruby
b
  .c
  .d
```

## 5. Get both passing and repro into tests

This allows you some freedom. At this point, everything is isolated
and reproducible. You should see that one passes and the other one fails.

```lisp
(ert-deftest enh-ruby-indent-leading-dots-ident ()
  (with-temp-enh-rb-string
   "b\n.c\n.d\n"

   (indent-region (point-min) (point-max))
   (buffer-should-equal "b\n  .c\n  .d\n")))

(ert-deftest enh-ruby-indent-leading-dots-ivar ()
  (with-temp-enh-rb-string
   "@b\n.c\n.d\n"

   (indent-region (point-min) (point-max))
   (buffer-should-equal "@b\n  .c\n  .d\n")))
```

## 6. Try to ferret out the difference.

I was able to do that with:

```
% ruby tools/debug.rb --trace bug128_1.rb | nopwd > 1
% ruby tools/debug.rb --trace bug128_2.rb | nopwd > 2
```

and then using `ediff` to look at the differences in execution paths.

In particular, I could see that a major difference down the line
depended on whether `@ident` was true:

```diff
 #0:./ruby/erm_buffer.rb:19:ErmBuffer::Adder:-:         case sym
-#0:./ruby/erm_buffer.rb:23:ErmBuffer::Adder:-:           @ident = false
+#0:./ruby/erm_buffer.rb:21:ErmBuffer::Adder:-:           @ident = true
 #0:./ruby/erm_buffer.rb:27:ErmBuffer::Adder:-:       @first_token = ft
```

followed by:

```diff
 #0:./ruby/erm_buffer.rb:487:ErmBuffer::Parser:-:       if @ident
+#0:./ruby/erm_buffer.rb:488:ErmBuffer::Parser:-:         line_so_far_str = @line_so_far.map {|a| a[1] }.join
+#0:./ruby/erm_buffer.rb:489:ErmBuffer::Parser:-:         if line_so_far_str.strip == ""
+#0:./ruby/erm_buffer.rb:490:ErmBuffer::Parser:-:           indent :c, (line_so_far_str.length * -1)
+#0:./ruby/erm_buffer.rb:99:ErmBuffer::Parser:>:     def indent type, c = 0
...
```

This was the major difference between the two and made it easy to
reason about.

## 7. Make the test pass

Changing from:

```ruby
  when :ident, :const then
```

to

```ruby
  when :ident, :const, :ivar, :gvar, :cvar then
```

(with 2 extra tests) made the tests pass and things seem happier.
