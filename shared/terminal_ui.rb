# terminal_ui.rb - Simple terminal UI helpers without external dependencies
#
# Provides a multi-select interface using ANSI escape codes

require 'io/console'
require 'io/wait'

# Force unbuffered output for interactive UI
$stdout.sync = true

module TerminalUI
  # ANSI escape codes
  CLEAR_LINE = "\e[2K"
  CURSOR_UP = "\e[A"
  CURSOR_DOWN = "\e[B"
  CURSOR_HIDE = "\e[?25l"
  CURSOR_SHOW = "\e[?25h"

  # Colors
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  CYAN = "\e[36m"
  DIM = "\e[2m"
  RESET = "\e[0m"

  # Multi-select interface
  #
  # @param title [String] Title to display above the list
  # @param items [Array<Hash>] Array of { label:, value:, selected:, hint: }
  # @return [Array] Selected values
  #
  # Example:
  #   items = [
  #     { label: "Option 1", value: "opt1", selected: true, hint: "(recommended)" },
  #     { label: "Option 2", value: "opt2", selected: false, hint: "(3 files)" },
  #   ]
  #   selected = TerminalUI.multi_select("Choose options:", items)
  #
  def self.multi_select(title, items)
    return [] if items.empty?

    cursor = 0
    selected = items.map { |item| item[:selected] || false }

    # Use IO.console for direct terminal I/O
    console = IO.console
    out = console || $stderr

    # Hide cursor and render initial state
    out.print CURSOR_HIDE
    out.flush
    out.puts title
    out.puts "#{DIM}(↑/↓ navigate, space toggle, enter confirm, q quit)#{RESET}"
    out.puts
    out.flush
    render_items(items, selected, cursor, out)
    out.flush

    begin
      loop do
        key = read_key

        case key
        when :up
          cursor = (cursor - 1) % items.length
        when :down
          cursor = (cursor + 1) % items.length
        when :space
          selected[cursor] = !selected[cursor]
        when :enter
          break
        when :quit
          selected = items.map { false }  # Deselect all
          break
        when :select_all
          selected = items.map { true }
        when :select_none
          selected = items.map { false }
        end

        # Move cursor up to redraw
        move_up(items.length, out)
        render_items(items, selected, cursor, out)
      end
    ensure
      out.print CURSOR_SHOW
      out.puts  # Add newline after selection
    end

    # Return selected values
    items.each_with_index
         .select { |_, i| selected[i] }
         .map { |item, _| item[:value] }
  end

  private

  def self.render_items(items, selected, cursor, out)
    items.each_with_index do |item, i|
      prefix = i == cursor ? "#{CYAN}❯#{RESET}" : " "
      checkbox = selected[i] ? "#{GREEN}◉#{RESET}" : "○"
      label = item[:label]
      hint = item[:hint] ? " #{DIM}#{item[:hint]}#{RESET}" : ""

      # Highlight current row
      if i == cursor
        label = "#{CYAN}#{label}#{RESET}"
      end

      out.print "#{CLEAR_LINE}#{prefix} #{checkbox} #{label}#{hint}\n"
    end
  end

  def self.move_up(lines, out)
    lines.times { out.print CURSOR_UP }
    out.print "\r"  # Move to start of line
  end

  def self.read_key
    input = $stdin.getch

    case input
    when " "
      :space
    when "\r", "\n"
      :enter
    when "q", "Q", "\u0003"  # q or Ctrl+C
      :quit
    when "a", "A"
      :select_all
    when "n", "N"
      :select_none
    when "\e"  # Escape sequence (arrow keys)
      # Read the rest of the escape sequence with timeout
      seq = ""
      2.times do
        break unless $stdin.wait_readable(0.1)
        seq << $stdin.getch
      end

      case seq
      when "[A", "OA"
        :up
      when "[B", "OB"
        :down
      else
        :quit  # Plain escape key = quit
      end
    when "k"
      :up
    when "j"
      :down
    else
      :unknown
    end
  end
end
