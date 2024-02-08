# ------------------------------------------------------------------------------
# Copyright (c) 2021 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "yast"

require "cwm"
require "installation/console/menu_plugin"
require "y2storage/storage_env"

module Installation
  module Console
    module Plugins
      # define a checkbox for enabling the experimental LUKS2 support in the installer
      class LUKS2CheckBox < CWM::CheckBox
        include Yast::Logger

        def initialize
          super
          textdomain "storage"
        end

        # set the initial status
        def init
          check if Y2Storage::StorageEnv.instance.luks2_available?
        end

        def label
          # TRANSLATORS: check box label
          _("Enable LUKS2 Encryption Support")
        end

        def store
          # the evaluated env variables are cached, we need to drop the cache
          # when doing any change
          Y2Storage::StorageEnv.instance.reset_cache

          if checked?
            ENV["YAST_LUKS2_AVAILABLE"] = "1"
          else
            ENV.delete("YAST_LUKS2_AVAILABLE")
          end
        end

        def help
          # TRANSLATORS: help text for the checkbox enabling LUKS2 support
          _("<p>You can enable experimental LUKS2 encryption support in "\
            "the YaST partitioner. It is not supported and is designed as a " \
            "technology preview only.</p>")
        end
      end

      # define the plugin
      class LUKS2CheckBoxPlugin < MenuPlugin
        def widget
          LUKS2CheckBox.new
        end

        # at the end
        def order
          2000
        end
      end
    end
  end
end
