class ProgPassFailDocFormatter < RSpec::Core::Formatters::DocumentationFormatter
  RSpec::Core::Formatters.register self, :example_group_started, :example_group_finished,
                            :example_passed, :example_pending, :example_failed

  def initialize(output)
    super
    @fail_preamble_cache = [""]
  end

  def example_group_started(notification)
    @group_level += 1
    @fail_preamble_cache[@group_level] = "#{current_indentation}#{notification.group.description.strip}"
  end

  def example_passed(_notification)
    output.print RSpec::Core::Formatters::ConsoleCodes.wrap('.', :success)
  end

  def example_pending(_notification)
    output.print RSpec::Core::Formatters::ConsoleCodes.wrap('*', :pending)
  end

  def example_failed(failure)
    @fail_preamble_cache.take(@group_level).each {|txt| output.puts(txt)}
    super
  end
end
