# frozen_string_literal: true

module RufletStudio
  module SectionsMisc
    def build_minesweeper(page, status)
      rows = 9
      cols = 9
      size = 24
      board_width = cols * size
      board_height = rows * size
      mine_count = 10

      squares = Array.new(rows * cols) do |idx|
        r = idx / cols
        c = idx % cols
        {
          row: r,
          col: c,
          mine: false,
          revealed: false,
          flagged: false,
          adjacent: 0
        }
      end

      Random.new.rand(0..1)
      mines = (0...(rows * cols)).to_a.sample(mine_count)
      mines.each { |idx| squares[idx][:mine] = true }

      squares.each do |sq|
        next if sq[:mine]

        count = 0
        (-1..1).each do |dr|
          (-1..1).each do |dc|
            next if dr.zero? && dc.zero?

            nr = sq[:row] + dr
            nc = sq[:col] + dc
            next unless nr.between?(0, rows - 1) && nc.between?(0, cols - 1)

            nidx = nr * cols + nc
            count += 1 if squares[nidx][:mine]
          end
        end
        sq[:adjacent] = count
      end

      mines_left = mine_count
      mines_text = text(value: format("%03d", mines_left), color: "#ff6b6b", size: 16, weight: "w600")
      face_text = text(value: "🙂", size: 18)
      timer_text = text(value: "000", color: "#ff6b6b", size: 16, weight: "w600")

      cell_texts = []
      cell_containers = []
      squares.each_with_index do |sq, idx|
        number_color =
          case sq[:adjacent]
          when 1 then "#2f6df6"
          when 2 then "#2f9e44"
          when 3 then "#f03e3e"
          when 4 then "#5f3dc4"
          when 5 then "#e8590c"
          when 6 then "#12b886"
          when 7 then "#343a40"
          when 8 then "#212529"
          else "#1f2328"
          end

        label = sq[:flagged] ? "🚩" : ""
        label_text = text(value: label, size: 14, color: number_color)
        cell_texts[idx] = label_text

        cell_containers[idx] = container(
          width: size,
          height: size,
          left: sq[:col] * size,
          top: sq[:row] * size,
          bgcolor: "#c0c0c0",
          border: {
            top: { width: 2, color: "#ffffff" },
            left: { width: 2, color: "#ffffff" },
            bottom: { width: 2, color: "#7b7b7b" },
            right: { width: 2, color: "#7b7b7b" }
          },
          alignment: "center",
          content: label_text
        )
      end

      board = stack(width: board_width, height: board_height, controls: cell_containers)

      safe_update = lambda do |control, props|
        return unless control

        if props.key?(:controls) || props.key?("controls")
          list = props[:controls] || props["controls"]
          control.children.replace(list)
          page.update if control.wire_id
          return
        end

        if control.wire_id
          page.update(control, **props)
        else
          props.each { |k, v| control.props[k.to_s] = v }
        end
      end

      rebuild = lambda do
        squares.each_with_index do |sq, idx|
          number_color =
            case sq[:adjacent]
            when 1 then "#2f6df6"
            when 2 then "#2f9e44"
            when 3 then "#f03e3e"
            when 4 then "#5f3dc4"
            when 5 then "#e8590c"
            when 6 then "#12b886"
            when 7 then "#343a40"
            when 8 then "#212529"
            else "#1f2328"
            end

          label =
            if sq[:flagged]
              "🚩"
            elsif !sq[:revealed]
              ""
            elsif sq[:mine]
              "💥"
            elsif sq[:adjacent].positive?
              sq[:adjacent].to_s
            else
              ""
            end

          container = cell_containers[idx]
          text = cell_texts[idx]
          safe_update.call(container, {
            bgcolor: sq[:revealed] ? "#d0d0d0" : "#c0c0c0",
            border: if sq[:revealed]
              { width: 1, color: "#8d8d8d" }
            else
              {
                top: { width: 2, color: "#ffffff" },
                left: { width: 2, color: "#ffffff" },
                bottom: { width: 2, color: "#7b7b7b" },
                right: { width: 2, color: "#7b7b7b" }
              }
            end
          })
          safe_update.call(text, { value: label, color: number_color })
        end

        safe_update.call(mines_text, { value: format("%03d", mines_left) })
      end

      reveal = lambda do |row, col|
        stack = [[row, col]]
        while (cell = stack.pop)
          r, c = cell
          idx = r * cols + c
          sq = squares[idx]
          next if sq[:revealed] || sq[:flagged]

          sq[:revealed] = true
          next if sq[:adjacent].positive?

          (-1..1).each do |dr|
            (-1..1).each do |dc|
              next if dr.zero? && dc.zero?

              nr = r + dr
              nc = c + dc
              next unless nr.between?(0, rows - 1) && nc.between?(0, cols - 1)

              stack << [nr, nc]
            end
          end
        end
      end

      timer_state = page.instance_variable_get(:@minesweeper_timer_state)
      unless timer_state
        timer_state = {
          running: false,
          value: 0,
          thread: nil,
          token: 0,
          start_time: nil
        }
        page.instance_variable_set(:@minesweeper_timer_state, timer_state)
      end
      timer_state[:token] += 1
      timer_token = timer_state[:token]
      safe_update.call(timer_text, { value: format("%03d", timer_state[:value]) })

      start_timer = lambda do
        return if timer_state[:running]

        timer_state[:running] = true
        timer_state[:start_time] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        timer_state[:thread] = Thread.new do
          last_shown = -1
          loop do
            sleep 0.2
            break unless timer_state[:running]
            break unless timer_state[:token] == timer_token

            elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - timer_state[:start_time]
            seconds = elapsed.floor
            next if seconds == last_shown

            last_shown = seconds
            timer_state[:value] = seconds
            safe_update.call(timer_text, { value: format("%03d", seconds) })
          end
        end
      end

      stop_timer = lambda do
        timer_state[:running] = false
        timer_state[:thread]&.kill
        timer_state[:thread] = nil
      end

      reset_timer = lambda do
        stop_timer.call
        timer_state[:value] = 0
        timer_state[:start_time] = nil
        safe_update.call(timer_text, { value: "000" })
      end

      on_tap = lambda do |e|
        pos = extract_pos(e)
        return unless pos

        start_timer.call
        r = (pos[:y] / size).floor
        c = (pos[:x] / size).floor
        return unless r.between?(0, rows - 1) && c.between?(0, cols - 1)

        sq = squares[r * cols + c]
        return if sq[:flagged] || sq[:revealed]

        if sq[:mine]
          squares.each { |s| s[:revealed] = true if s[:mine] }
          safe_update.call(face_text, { value: "😵" })
          safe_update.call(status, { value: "Game over" })
          stop_timer.call
        else
          reveal.call(r, c)
        end
        rebuild.call
      end

      on_flag = lambda do |e|
        pos = extract_pos(e)
        return unless pos

        start_timer.call
        r = (pos[:y] / size).floor
        c = (pos[:x] / size).floor
        return unless r.between?(0, rows - 1) && c.between?(0, cols - 1)

        sq = squares[r * cols + c]
        return if sq[:revealed]

        sq[:flagged] = !sq[:flagged]
        mines_left += sq[:flagged] ? -1 : 1
        rebuild.call
      end

      board_gesture = gesture_detector(
        on_tap_down: ->(e) {
          pos = extract_pos(e)
          if pos
            # no-op: position captured for debugging if needed
          end
        },
        on_tap: ->(e) {
          on_tap.call(e)
        },
        on_long_press_start: ->(e) {
          on_flag.call(e)
        },
        drag_interval: 5,
        width: board_width,
        height: board_height,
        content: board
      )

      rebuild.call

      bevel = lambda do |content, padding: 6|
        container(
          padding: padding,
          bgcolor: "#bcbcbc",
          border: {
            top: { width: 2, color: "#ffffff" },
            left: { width: 2, color: "#ffffff" },
            bottom: { width: 2, color: "#8d8d8d" },
            right: { width: 2, color: "#8d8d8d" }
          },
          content: content
        )
      end

      counter_box = lambda do |content|
        container(
          width: 70,
          height: 36,
          alignment: "center",
          bgcolor: "#d0d0d0",
          border: {
            top: { width: 2, color: "#8d8d8d" },
            left: { width: 2, color: "#8d8d8d" },
            bottom: { width: 2, color: "#ffffff" },
            right: { width: 2, color: "#ffffff" }
          },
          content: content
        )
      end

      column(
        spacing: 8,
        horizontal_alignment: "center",
        tight: true,
        controls: [
          container(
            padding: 8,
            width: board_width + 16,
            bgcolor: "#c0c0c0",
            border: {
              top: { width: 2, color: "#ffffff" },
              left: { width: 2, color: "#ffffff" },
              bottom: { width: 2, color: "#8d8d8d" },
              right: { width: 2, color: "#8d8d8d" }
            },
            content: row(
              alignment: "spaceBetween",
              controls: [
                counter_box.call(mines_text),
                bevel.call(container(width: 36, height: 36, alignment: "center", bgcolor: "#d0d0d0", content: face_text)),
                counter_box.call(timer_text)
              ]
            )
          ),
          container(
            padding: 8,
            width: board_width + 16,
            height: board_height + 16,
            bgcolor: "#c0c0c0",
            border: {
              top: { width: 2, color: "#ffffff" },
              left: { width: 2, color: "#ffffff" },
              bottom: { width: 2, color: "#8d8d8d" },
              right: { width: 2, color: "#8d8d8d" }
            },
            content: board_gesture
          ),
          status
        ]
      )
    end

    def build_minesweeper_grid(page)
      size = 26
      controls = []
      9.times do |r|
        9.times do |c|
          controls << container(
            width: size,
            height: size,
            left: c * size,
            top: r * size,
            bgcolor: r.even? == c.even? ? "#2a2e36" : "#23272f",
            border: { width: 1, color: "#1c1f26" }
          )
        end
      end
      controls
    end
  end
end
