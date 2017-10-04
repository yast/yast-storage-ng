require "yast"
require "cwm/tabs"
require "y2partitioner/ui_state"

Yast.import "UI"

module Y2Partitioner
  module Widgets
    # Mixin for the different Tab subclasses to interact with {UIState}
    module TabsWithState
      # Overrides default behavior of tabs to register the new state before
      # doing the real switch
      def switch_page(page)
        UIState.instance.switch_to_tab(page)
        super
      end

      # Ensures tabs are properly initialized after a redraw according to
      # {UIState}.
      def initial_page
        UIState.instance.find_tab(@pages) || super
      end
    end

    # Specialized class of the Tabs widget implementing partitioner-specific
    # behavior, like interacting with {UIState} to provide a consistent user
    # experience.
    class Tabs < CWM::Tabs
      # Follow the same (very surprising) behavior of CWM::Tabs of redefining
      # self.new to call {DumbTabPager}.new or {PushButtonTabPager}.new.
      def self.new(*args)
        if Yast::UI.HasSpecialWidget(:DumbTab)
          DumbTabPager.new(*args)
        else
          PushButtonTabPager.new(*args)
        end
      end
    end

    # @see Tabs
    class DumbTabPager < CWM::DumbTabPager
      include TabsWithState
    end

    # @see Tabs
    class PushButtonTabPager < CWM::PushButtonTabPager
      include TabsWithState
    end
  end
end
