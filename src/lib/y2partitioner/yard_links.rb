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

module Y2Storage
  # See http://www.rubydoc.info/github/yast/yast-storage-ng/Y2Storage/Devicegraph
  class Devicegraph
  end

  # See http://www.rubydoc.info/github/yast/yast-storage-ng/Y2Storage/BlkDevice
  class BlkDevice
  end

  # See http://www.rubydoc.info/github/yast/yast-storage-ng/Y2Storage/Region
  class Region
  end
end
