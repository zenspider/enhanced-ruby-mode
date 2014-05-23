require_relative './markup'

module ErmTestHelper
  module_function

  # workaround for Minitest::Assertions.assert_parse
  # to remove surrounding `"` from markup diff
  def override_inspect(obj)
    def obj.inspect
      self
    end
    obj
  end
end

module Minitest::Assertions
  module_function

  def assert_parse(markedup_code, buf = ErmBuffer.new, msg = nil)
    markedup_code.gsub!(/\A\n|\n\z/, "")

    expected_sexp, code = Markup.parse_markup(markedup_code)
    actual_sexp = Markup.parse_code(code, buf)

    msg = message(msg, "") do
      expected_markup = markedup_code
      actual_markup   = Markup.markup(code, Markup.parse_sexp(actual_sexp))

      diff_markup = diff(ErmTestHelper.override_inspect(expected_markup),
                         ErmTestHelper.override_inspect(actual_markup))
      diff_sexp   = diff(expected_sexp, actual_sexp)

      diff_markup + "\n" + diff_sexp
    end

    assert(expected_sexp == actual_sexp, msg)
  end
end

