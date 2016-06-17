# simple markdown formatter
class MdFormatter
  RSpec::Core::Formatters.register self,
    :example_group_started, :example_group_finished,
    :example_passed, :example_failed

  def initialize(output)
    @output = output
    @group_level = 0
  end

  def example_group_started(notification)
    @output.puts if @group_level == 0
    @output.puts "#{current_indentation}#{notification.group.description.strip.sub(/^#/,'')}"
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
      "## "
    elsif @group_level == 1
      "### "
    else
      "\t" * (@group_level - 2) + "- "
    end
  end
end
