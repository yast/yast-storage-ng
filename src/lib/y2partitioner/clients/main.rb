require "cwm/tree_pager"
require "y2partitioner/device_graphs"
require "y2partitioner/dialogs/main"
require "y2storage"

Yast.import "Popup"

# Work around YARD inability to link across repos/gems:
# (declaring macros here works because YARD sorts by filename size(!))

# @!macro [new] seeAbstractWidget
#   @see http://www.rubydoc.info/github/yast/yast-yast2/CWM%2FAbstractWidget:${0}
# @!macro [new] seeCustomWidget
#   @see http://www.rubydoc.info/github/yast/yast-yast2/CWM%2FCustomWidget:${0}
# @!macro [new] seeDialog
#   @see http://www.rubydoc.info/github/yast/yast-yast2/CWM%2FDialog:${0}

module Y2Partitioner
  # YaST "clients" are the CLI entry points
  module Clients
    # The entry point for starting partitioner on its own. Use probed and staging device graphs.
    class Main
      extend Yast::I18n
      extend Yast::Logger

      # Run the client
      # @param allow_commit [Boolean] can we pass the point of no return
      def self.run(allow_commit: true)
        textdomain "storage"

        smanager = Y2Storage::StorageManager.instance
        dialog = Dialogs::Main.new
        res = dialog.run(smanager.probed, smanager.staging)

        # Running system: presenting "Expert Partitioner: Summary" step now
        # ep-main.rb SummaryDialog
        if res == :next && should_commit?(allow_commit)
          smanager.staging = dialog.device_graph
          smanager.commit
        end
      end

      # Ask whether to proceed with changing the disks;
      # or inform that we will not do it.
      # @return [Boolean] proceed
      def self.should_commit?(allow_commit)
        if allow_commit
          q = "Modify the disks and potentially destroy your data?"
          Yast::Popup.ContinueCancel(q)
        else
          m = "Nothing gets written, because the device graph is fake."
          Yast::Popup.Message(m)
          false
        end
      end
    end
  end
end
