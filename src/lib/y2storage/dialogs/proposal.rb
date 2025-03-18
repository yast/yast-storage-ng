# Copyright (c) [2016-2022] SUSE LLC
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
require "yast2/popup"
require "ui/installation_dialog"
require "y2storage"
require "y2storage/actions_presenter"
require "y2storage/dump_manager"
require "y2storage/setup_checker"
require "y2storage/setup_errors_presenter"

Yast.import "HTML"
Yast.import "Arch"

module Y2Storage
  module Dialogs
    # Calculates the storage proposal during installation and provides
    # the user a summary of the storage proposal
    class Proposal < ::UI::InstallationDialog # rubocop:disable Metrics/ClassLength
      attr_reader :proposal
      attr_reader :devicegraph

      # Constructor
      #
      # @param proposal [GuidedProposal]
      # @param devicegraph [Devicegraph]
      # @param excluded_buttons [Array<Symbol>] id of buttons that should not be shown
      def initialize(proposal, devicegraph, excluded_buttons: [])
        log.info "Proposal dialog: start with #{proposal.inspect}"

        super()
        textdomain "storage"

        @proposal = proposal
        @devicegraph = devicegraph
        @excluded_buttons = excluded_buttons

        propose! if proposal && !proposal.proposed?
        @actions_presenter = ActionsPresenter.new(actiongraph)

        DumpManager.dump(@actions_presenter)
      end

      def next_handler
        if devicegraph
          log.info "Proposal dialog: return :next with #{proposal} and #{devicegraph}"
          super
        else
          msg = _("Cannot continue without a valid storage setup.") + "\n"
          msg += _("Please use \"Guided Setup\" or \"Expert Partitioner\".")
          Yast::Report.Error(msg)
        end
      end

      def guided_handler
        finish_dialog(:guided)
      end

      def expert_from_proposal_handler
        finish_dialog(:expert_from_proposal)
      end

      def expert_from_probed_handler
        finish_dialog(:expert_from_probed)
      end

      def handle_event(input)
        if ["disable_tpm2", "enable_tpm2"].include?(input)
          init_tpm(input)
        elsif @actions_presenter.can_handle?(input)
          @actions_presenter.update_status(input)
        end

        Yast::UI.ChangeWidget(Id(:summary), :Value, actions_html)
      end

      protected

      # @return [GuidedProposal]
      attr_writer :proposal

      # @return [Devicegraph] Desired devicegraph
      attr_writer :devicegraph

      # @return [Array<Symbol>] id of buttons that should not be shown
      attr_reader :excluded_buttons

      # @return StorageManager
      def storage_manager
        StorageManager.instance
      end

      # Calculates the desired devicegraph using the storage proposal.
      # Sets the devicegraph to nil if something went wrong
      def propose!
        return if proposal.nil? || proposal.proposed?

        proposal.propose
        self.devicegraph = proposal.devices
        storage_manager.encryption_use_tpm2 = nil # reset
      rescue Y2Storage::Error
        log.error("generating proposal failed")
        self.devicegraph = nil
      end

      # HTML-formatted text to display in the dialog
      #
      # If there is a successful proposal, it returns a text representation of
      # the proposal with links to modify the settings.
      #
      # If the devicegraph has been set manually, it shows the actions to
      # perform.
      #
      # If there was an error calculating the proposal, it returns an error
      # message.
      #
      # @return [String]
      def summary
        # TODO: if there is a proposal, use the meaningful description with
        # hyperlinks instead of just delegating the summary to libstorage
        content = devicegraph ? actions_html : failure_html

        RichText(Id(:summary), content)
      end

      # Text for the summary in cases in which a devicegraph was properly
      # calculated
      #
      # @see #summary
      #
      # @return [String] HTML-formatted text
      def actions_html
        actions_source_html +
          boss_html +
          setup_errors_html +
          # Reuse the exact string "Changes to partitioning" from the partitioner
          _("<p>Changes to partitioning:</p>") +
          @actions_presenter.to_html +
          tpm_html
      end

      def init_tpm(value)
        case value
        when "disable_tpm2"
          if proposal
            proposal.settings.encryption_use_tpm2 = false
          else
            storage_manager.encryption_use_tpm2 = false
          end
        when "enable_tpm2"
          if proposal
            proposal.settings.encryption_use_tpm2 = true
          else
            storage_manager.encryption_use_tpm2 = true
          end
        end
      end

      # Checking if there is at least one partition which will be encrypted with LUKS2
      # All encrypted partitions has to be encrypted with LUKS2 with the same password.
      def correct_luks2_encryption?
        found = false
        last_password = ""
        devicegraph.encryptions&.each do |d|
          if d.type == EncryptionType::LUKS2
            found = true
          else
            log.info("Wrong encryption for TPM2 in device: #{d.inspect}")
            return false
          end
          last_password = d.password if last_password.empty?
          if last_password != d.password
            log.info("Passwords of encrypted devices using TPM2 have the be the same")
            return false
          end
        end
        found
      end

      def proposal_has_correct_encryption
        proposal.settings.use_encryption &&
          proposal.settings.encryption_method == EncryptionMethod::LUKS2
      end

      # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
      def tpm_html
        return "" unless Yast::Arch.has_tpm2

        use_tpm2 = nil
        if proposal # selected via proposal (guided proposal)
          if proposal_has_correct_encryption
            use_tpm2 = if proposal.settings.encryption_use_tpm2
              true
            else
              false
            end
          end
        elsif correct_luks2_encryption? # user defined partitions
          use_tpm2 = storage_manager.encryption_use_tpm2
          use_tpm2 = false if use_tpm2.nil?
        end

        if use_tpm2
          storage_manager.encryption_tpm2_password = devicegraph.encryptions&.password
        else
          storage_manager.encryption_use_tpm2 = nil
          storage_manager.encryption_tpm2_password = ""
        end

        return "" if use_tpm2.nil?

        if use_tpm2
          "<p>#{_("Using TPM2 device for encryption.")}"\
            " <a href=\"disable_tpm2\">(#{_("disable")})</a></p>"
        else
          "<p>#{_("Do not use TPM2 device for encryption.")}"\
            "  <a href=\"enable_tpm2\">(#{_("enable")})</a></p>"
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

      def boss_html
        return "" if boss_devices.empty?

        # TRANSLATORS: %s is a linux device name (eg. /dev/sda) (singular),
        #  or a list of comma-separated device names (eg. "/dev/sda, /dev/sdb") (plural)
        n_(
          "<p>The device %s is a Dell BOSS drive.</p>",
          "<p>The following devices are Dell BOSS drives: %s.</p>",
          boss_devices.size
        ) % boss_devices.map(&:name).join(", ")
      end

      def boss_devices
        @boss_devices ||= devicegraph.blk_devices.select(&:boss?)
      end

      # @see #actions_html
      def actions_source_html
        return actions_source_for_partitioner unless proposal
        return actions_source_for_guided_setup unless settings_adjustment
        return actions_source_for_default_settings if settings_adjustment.empty?

        para(_("Initial layout proposed after adjusting the Guided Setup settings:")) +
          list(settings_adjustment.descriptions)
      end

      # @see #actions_source_html
      def actions_source_for_partitioner
        para(_("Layout configured manually using the Expert Partitioner."))
      end

      # @see #actions_source_html
      def actions_source_for_guided_setup
        para(_("Layout proposed by the Guided Setup with the settings provided by the user."))
      end

      # @see #actions_source_html
      def actions_source_for_default_settings
        para(_("Initial layout proposed with the default Guided Setup settings."))
      end

      # Setup errors
      #
      # @return [String] HTML-formatted text
      def setup_errors_html
        setup_checker = Y2Storage::SetupChecker.new(devicegraph)
        return "" if setup_checker.valid?

        Y2Storage::SetupErrorsPresenter.new(setup_checker).to_html
      end

      # Text for the summary in cases in which it was not possible to propose
      # a devicegraph
      #
      # @see #summary
      #
      # @return [String] HTML-formatted text
      def failure_html
        failure_source_html + para(
          _(
            "Please, use \"Guided Setup\" to adjust the proposal settings or " \
            "\"Expert Partitioner\" to create a custom layout."
          )
        )
      end

      # @see #failure_html
      def failure_source_html
        if settings_adjustment
          # Just in case the initial proposal is configured to never adjust any
          # setting automatically
          if settings_adjustment.empty?
            para(
              _(
                "It was not possible to propose an initial partitioning layout " \
                "based on the default Guided Setup settings."
              )
            )
          else
            para(
              _(
                "It was not possible to propose an initial partitioning layout " \
                "even after adjusting the Guided Setup settings:"
              )
            ) + list(settings_adjustment.descriptions)
          end
        else
          para(
            _(
              "The Guided Setup was not able to propose a layout using the " \
              "provided settings."
            )
          )
        end
      end

      def dialog_title
        _("Suggested Partitioning")
      end

      # Button to open the Guided Setup
      #
      # @note This button might not be shown (see {#excluded_buttons}).
      #
      # @return [Yast::UI::Term]
      def guided_setup_button
        return Empty() if excluded_buttons.include?(:guided)

        PushButton(Id(:guided), _("&Guided Setup"))
      end

      # Button to open the Partitioner
      #
      # @note This button might not be shown (see {#excluded_buttons}).
      #
      # @return [Yast::UI::Term]
      def expert_partitioner_button
        items = []

        if !excluded_buttons.include?(:expert_from_proposal) && devicegraph
          items << Item(Id(:expert_from_proposal), _("Start with &Current Proposal"))
        end

        if !excluded_buttons.include?(:expert_from_probed)
          items << Item(Id(:expert_from_probed), _("Start with Existing &Partitions"))
        end

        return Empty() if items.empty?

        MenuButton(_("&Expert Partitioner"), items)
      end

      def dialog_content
        MarginBox(
          2, 1,
          VBox(
            MinHeight(8, summary),
            guided_setup_button,
            expert_partitioner_button
          )
        )
      end

      def help_text
        _(
          "<p>\n" \
          "Your hard disks have been checked. The partition setup\n" \
          "displayed is proposed for your hard drive.</p>"
        )
      end

      def settings_adjustment
        proposal ? proposal.auto_settings_adjustment : nil
      end

      # Shortcut for Yast::HTML.Para
      def para(string)
        Yast::HTML.Para(string)
      end

      # Shortcut for Yast::HTML.List
      def list(items)
        Yast::HTML.List(items)
      end

      # Actions needed to reach the desired devicegraph
      #
      # If a libstorage-ng exception is raised while calculating the
      # actiongraph, it is rescued and a pop-up is presented to the user.
      #
      # @return [Actiongraph, nil] nil if it's not possible to calculate the actions
      def actiongraph
        @devicegraph ? @devicegraph.actiongraph : nil
      rescue ::Storage::Exception => e
        # TODO: the code capturing the exception and displaying the error pop-up
        # should not be directly in this dialog. It should be in some common
        # place ensuring we also catch the exception in other places where we
        # calculate/display the actiongraph (like the Expert Partitioner).
        # That should be part of a bigger effort in reporting invalid devicegraphs.
        # See https://trello.com/c/iMoOGVxg/
        msg = _(
          "An error was found in one of the devices in the system.\n" \
          "The information displayed may not be accurate and the\n" \
          "installation may fail if you continue."
        )
        hint = _("Click below to see more details (English only).")

        Yast2::Popup.show("#{msg}\n\n#{hint}", details: e.what)
        nil
      end
    end
  end
end
