
require "yast"

Yast.import "UI"


include Yast::UIShortcuts

module Yast

  module UIShortcuts

    def LeftRadioButton(*opts)
      Left(RadioButton(*opts))
    end

  end

end
