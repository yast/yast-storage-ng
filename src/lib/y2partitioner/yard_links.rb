# The documentatin tool YARD has no mechanism
# for linking to separately generated YARD documentation.
# So we use this file to help YARD.
# Other code does not use (or even `require`) this.

require "yast"

module CWM
  # See http://www.rubydoc.info/github/yast/yast-yast2/CWM/WidgetTerm
  class WidgetTerm < Yast::Term
  end
end
