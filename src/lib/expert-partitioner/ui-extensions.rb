
require "yast"

Yast.import "UI"
Yast.import "Directory"


include Yast::UIShortcuts

module Yast

  module UIShortcuts

    def LeftRadioButton(*opts)
      Left(RadioButton(*opts))
    end

    def IconAndHeading(heading, icon)
      HBox(Image("#{Yast::Directory.icondir}/22x22/apps/#{icon}", ""), Heading(heading))
    end

  end

end
