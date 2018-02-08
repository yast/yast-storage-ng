# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"

module Y2Partitioner
  module Widgets
    # Class to handle filesystem formatting (mkfs and tune2fs, atm) options.
    #
    # Options can be read from resp. stored in
    # {Y2Storage::Filesystems::BlkFilesystem#mkfs_options} and
    # {Y2Storage::Filesystems::BlkFilesystem#tune_options} directly.
    #
    # rubocop:disable Metrics/ClassLength
    class MkfsOptiondata
      include Yast::I18n
      extend Yast::I18n

      # List of all options.
      #
      # @note
      #   - :widget must correspond to a valid class name
      #   - :validate can be missing, then no validation is done
      #   - :error can be missing, then no validation is done
      #   - there must be exactly one of :mkfs_option or :tune_option
      #   - :help texts automatically get the :label text prepended as a title
      #   - options will only appear in the final command line if the selected value
      #     is different from the default value
      #
      ALL_OPTIONS = [
        {
          fs:          %i(ext2 ext3 ext4),
          widget:      :MkfsComboBox,
          label:       N_("Block &Size in Bytes"),
          values:      %w(auto 1024 2048 4096),
          default:     "auto",
          mkfs_option: "-b",
          # help text, richtext format
          help:        N_(
            "Specify the block size in bytes. " \
            "If 'auto' is selected the block size is determined by the file system size " \
            "and the expected use of the file system."
          )
        },

        {
          fs:          %i(ext3 ext4),
          widget:      :MkfsComboBox,
          label:       N_("&Inode Size in Bytes"),
          values:      %w(auto 128 256 512 1024),
          default:     "auto",
          mkfs_option: "-I",
          # help text, richtext format
          help:        N_(
            "Specify the inode size in bytes." \
            "If 'auto' is selected the inode size is determined by the file system size " \
            "and will typically be 256."
          )
        },

        {
          fs:          %i(ext2 ext3 ext4),
          widget:      :MkfsComboBox,
          label:       N_("Bytes to &Inode Ratio"),
          values:      %w(auto 1024 2048 4096 8192 16384 32768),
          default:     "auto",
          mkfs_option: "-i",
          # help text, richtext format
          help:        N_(
            "Specify the bytes to inode ratio. YaST creates an inode for every " \
            "bytes-per-inode bytes of space on the disk. The larger the " \
            "bytes-per-inode ratio, the fewer inodes will be created. Generally, this " \
            "value should not be smaller than the block size of the file system, " \
            "since in that case more inodes would be made than can ever be used. " \
            "Note that this is not the size of the inode itself."
          )
        },

        {
          fs:          %i(ext2 ext3 ext4),
          widget:      :MkfsInputField,
          label:       N_("Percentage of Blocks &Reserved for root"),
          default:     "auto",
          validate:    lambda do |x|
            (x.match?(/^\d+(\.\d*)?$/) && x.to_f >= 0 && x.to_f <= 50) || x == "auto"
          end,
          mkfs_option: "-m",
          error:       N_(
            "Allowed are float numbers between 0 and 50."
          ),
          # help text, richtext format
          help:        N_(
            "Specify the percentage of blocks reserved for the super user. " \
            "Typically 5% are reserved."
          )
        },

        {
          fs:          %i(ext2 ext3 ext4),
          widget:      :MkfsInputField,
          label:       N_("Stride &Length in Blocks"),
          default:     "none",
          validate:    lambda do |x|
            (x.match?(/^\d+$/) && x.to_i >= 1) || x == "none"
          end,
          mkfs_option: "-Estride=",
          error:       N_(
            "Enter a number that is at least 1 or 'none'."
          ),
          # help text, richtext format
          help:        N_(
            "Set the the number of blocks in a RAID stripe. " \
            "This is the number of blocks read or written to disk " \
            "before moving to the next disk (also referred to as the chunk size). " \
            "Valid values are numbers greater than 0, or 'none'."
          )
        },

        {
          fs:          %i(ext2 ext3 ext4),
          widget:      :MkfsCheckBox,
          label:       N_("Enable Regular &Checks"),
          default:     false,
          # Note: the default is 'off', so we have to come up with some values.
          # 30/180 is more or less what mke2fs would use on its own.
          # Remember to adjust the help text if you change this.
          tune_option: "-c 30 -i 180",
          # help text, richtext format
          help:        N_(
            "Enable regular file system checks at booting. " \
            "This option forces a file system check after 30 system starts or 180 days, " \
            "whichever comes first."
          )
        },

        {
          fs:          %i(ext3 ext4),
          widget:      :MkfsCheckBox,
          label:       N_("&Directory Index Feature"),
          default:     true,
          mkfs_option: "-O ^dir_index",
          # help text, richtext format
          help:        N_(
            "Enables use of hashed b-trees to speed up lookups in large directories."
          )
        },

        {
          fs:          %i(ext3 ext4),
          widget:      :MkfsCheckBox,
          label:       N_("&Use Journal"),
          default:     true,
          mkfs_option: "-O ^has_journal",
          # help text, richtext format
          help:        N_(
            "Use journaling on filesystem (strongly advised). " \
            "Only deactivate this when you really know what you are doing."
          )
        },

        {
          fs:          %i(xfs),
          widget:      :MkfsComboBox,
          label:       N_("Block &Size in Bytes"),
          values:      %w(auto 512 1024 2048 4096 8192 16384),
          default:     "auto",
          mkfs_option: "-bsize=",
          # help text, richtext format
          help:        N_(
            "Specify the block size in bytes. " \
            "If auto is selected, the standard block size of 4096 is used."
          )
        },

        {
          fs:          %i(xfs),
          widget:      :MkfsComboBox,
          label:       N_("&Inode Size in Bytes"),
          values:      %w(auto 256 512 1024 2048),
          default:     "auto",
          mkfs_option: "-isize=",
          # help text, richtext format
          help:        N_(
            "Specify the inode size in bytes. " \
            "If 'auto' is selected the inode size will typically be 512."
          )
        },

        {
          fs:          %i(xfs),
          widget:      :MkfsInputField,
          label:       N_("&Percentage of Inode Space"),
          default:     "auto",
          validate:    lambda do |x|
            (x.match?(/^\d+$/) && x.to_i <= 100) || x == "auto"
          end,
          mkfs_option: "-imaxpct=",
          error:       N_(
            "Choose a value between 0 and 100, or 'auto'."
          ),
          # help text, richtext format
          help:        N_(
            "This option specifies the maximum percentage " \
            "of space in the file system that can be allocated to inodes. " \
            "Choose a value between 0 and 100, or 'auto'. " \
            "A value of 0 means that there are no restrictions on inode space."
          )
        },

        {
          fs:          %i(xfs),
          widget:      :MkfsCheckBox,
          label:       N_("Inodes &Aligned"),
          default:     true,
          mkfs_option: "-ialign=0",
          # help text, richtext format
          help:        N_(
            "This option is used to specify whether inode allocation is aligned. " \
            "By default inodes are aligned as this is more efficient than unaligned access. " \
            "But this option can be used to turn off inode alignment when the filesystem " \
            "needs to be mountable by an old version of IRIX that does not have the " \
            "inode alignment feature."
          )
        },

        {
          fs:          %i(vfat),
          widget:      :MkfsComboBox,
          label:       N_("FAT &Size"),
          values:      %w(auto 12 16 32),
          default:     "auto",
          mkfs_option: "-F",
          # help text, richtext format
          help:        N_(
            "Specify the size of the file allocation tables entries (12, 16, or 32 bit). " \
            "If 'auto' is specified, a suitable value is chosen dependng on the file system size. " \
            "Note that choosing an unsuitable FAT size might result " \
            "in an error when creating the file system."
          )
        },

        {
          fs:          %i(vfat),
          widget:      :MkfsComboBox,
          label:       N_("Number of &FATs"),
          values:      %w(auto 1 2),
          default:     "auto",
          mkfs_option: "-f",
          # help text, richtext format
          help:        N_(
            "Specify the number of file allocation tables. " \
            "The default is 2."
          )
        },

        {
          fs:          %i(vfat),
          widget:      :MkfsInputField,
          label:       N_("Root &Dir Entries"),
          default:     "auto",
          validate:    lambda do |x|
            (x.match?(/^\d+$/) && x.to_i >= 16) || x == "auto"
          end,
          mkfs_option: "-r",
          error:       N_(
            "The minimum number of entries is 16."
          ),
          # help text, richtext format
          help:        N_(
            "Select the number of entries available in the root directory. " \
            "Choose a value that is at least 16, or 'auto'. " \
            "Note that the value is a lower limit and the actual root directory may be larger."
          )
        }
      ]

      # Remember option data.
      #
      # @param option [Hash]
      #
      def initialize(option)
        @value = option
        textdomain "storage"
      end

      # Read current option value from file system class.
      #
      # @param filesystem [Y2Storage::Filesystems]
      #
      # @return [String, Boolean]
      #
      def get(filesystem)
        # current filesystem settings
        fs_str = filesystem.send(program + "_options")

        value = default

        # find option args in current settings; if it's a non-boolean
        # option get the value from the match
        m = fs_str.match(/(^|\s)#{Regexp.escape(option_str)}(\S*)/)
        value = boolean? ? !default : m[2] if m

        value
      end

      # Set new option value in file system class.
      #
      # @param filesystem [Y2Storage::Filesystems]
      # @param val [String, Boolean]
      #
      # @return [nil]
      #
      def set(filesystem, val)
        # current filesystem settings
        fs_str = filesystem.send(program + "_options")

        # remove the currently set option value
        fs_str.gsub!(/(^|\s+)#{Regexp.escape(option_str)}[^-]*/, "")

        # if it's not the default value, add option string
        if val != default
          fs_str << " #{option_str}"
          fs_str << val if !boolean?
        end

        # beautify
        fs_str.strip!

        # store new option args
        filesystem.send(program + "_options=", fs_str)
      end

      # Validate option value.
      #
      # This calls the validation function if there is one defined _and_ an
      # error message exists. Else it just returns true.
      #
      # @param val [String, Boolean]
      #
      # @return [Boolean]
      #
      def validate?(val)
        return true unless validate && @value[:error]
        validate[val]
      end

      # Translated label.
      #
      # @return [String]
      #
      def label
        _(@value[:label])
      end

      # Translated help text.
      #
      # The label string is prepended and formatted as title for the help text.
      #
      # @return [String]
      #
      def help
        help = _(@value[:help])
        label = _(@value[:label])
        "<p><b>#{label.delete("&")}</b><br/>#{help}</p>"
      end

      # Translated error message.
      #
      # The label string is prepended to the error message.
      #
      # @return [String]
      #
      def error
        error = _(@value[:error])
        label = _(@value[:label])
        "#{label.delete("&")}\n\n#{error}"
      end

    private

      # Make option hash entries readable via methods.
      #
      # Note this intentionally returns nil if there's neither a method nor
      # a hash key.
      #
      # @param foo [Symbol]
      #
      # @return [Object]
      #
      def method_missing(foo)
        @value[foo]
      end

      # Make class interface consistent.
      #
      # @param foo [Symbol]
      # @param _all [Boolean]
      #
      # @return [Boolean]
      #
      def respond_to_missing?(foo, _all)
        @value.key?(foo)
      end

      # Return true if option value is a boolean value.
      #
      # @return [Boolean]
      #
      def boolean?
        default == true || default == false
      end

      # Return option string.
      #
      # This can be either an mkfs or tune2fs option. Only either one is
      # defined.
      #
      # @return [String]
      #
      def option_str
        mkfs_option || tune_option
      end

      # The program the options is intended for.
      #
      # This can be either mkfs or tune2fs.
      #
      # @return [String]
      #
      def program
        mkfs_option ? "mkfs" : "tune"
      end

      class << self
        # Get list of options suitable for a specific file system.
        #
        # The list can be empty.
        #
        # @param filesystem [Y2Storage::Filesystems]
        #
        # @return [Array<MkfsOptiondata>]
        #
        def options_for(filesystem)
          fs = filesystem.type.to_sym
          all_options.find_all { |x| x[:fs].include?(fs) }.map { |x| MkfsOptiondata.new(x) }
        end

      private

        # Get list of all options.
        #
        # @return [Array<Hash>]
        #
        def all_options
          ALL_OPTIONS
        end
      end
    end
    # rubocop:enable all
  end
end
