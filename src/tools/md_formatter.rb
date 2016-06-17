# Copyright (c) [2016] SUSE LLC
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

# simple markdown formatter
class MdFormatter
  RSpec::Core::Formatters.register self,
    :example_group_started, :example_group_finished,
    :example_passed, :example_failed

  def initialize(output)
    @output = output
    @group_level = 0
    @groups = 0
    @output.puts "\n[//]: # (document was automatically created using 'rake doc:bootspecs')\n"
  end

  def example_group_started(notification)
    @output.puts if @group_level == 0
    # print top-level comment only once (this is our headline)
    if @group_level != 0 || @groups == 0
      text = notification.group.description.strip
      text.sub!(/^#/, "")
      text.gsub!(/_/, " ")
      @output.puts "#{current_indentation}#{text}"
    end
    @groups += 1 if @group_level == 0
    @group_level += 1
  end

  def example_group_finished(_notification)
    @group_level -= 1
  end

  def example_passed(passed)
    @output.puts passed_output(passed.example)
  end

  def example_failed(failure)
    @output.puts failure_output(failure.example, failure.example.execution_result.exception)
  end

private

  def passed_output(example)
    "#{current_indentation}**#{example.description.strip}**"
  end

  def failure_output(example, _exception)
    "#{current_indentation}**#{example.description.strip} - FAILED**"
  end

  def current_indentation
    if @group_level == 0
      "# "
    elsif @group_level == 1
      "## "
    else
      "\t" * (@group_level - 2) + "- "
    end
  end
end
