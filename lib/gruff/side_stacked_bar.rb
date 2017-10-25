require File.dirname(__FILE__) + '/base'
require File.dirname(__FILE__) + '/side_bar'
require File.dirname(__FILE__) + '/stacked_mixin'

##
# New gruff graph type added to enable sideways stacking bar charts
# (basically looks like a x/y flip of a standard stacking bar chart)
#
# alun.eyre@googlemail.com

class Gruff::SideStackedBar < Gruff::SideBar
  include StackedMixin

  # Spacing factor applied between bars
  attr_accessor :bar_spacing

  def draw
    @has_left_labels = true
    get_maximum_by_stack
    super
  end

  protected

  def setup_graph_measurements
      @marker_caps_height = @hide_line_markers ? 0 :
          calculate_caps_height(@marker_font_size)
      @title_caps_height = (@hide_title || @title.nil?) ? 0 :
          calculate_caps_height(@title_font_size) * @title.lines.to_a.size
      @legend_caps_height = @hide_legend ? 0 :
          calculate_caps_height(@legend_font_size)

      if @hide_line_markers
        (@graph_left,
            @graph_right_margin,
            @graph_bottom_margin) = [@left_margin, @right_margin, @bottom_margin]
      else
        if @has_left_labels
          longest_left_label_width = calculate_width(@marker_font_size,
                                                     labels.values.inject('') { |value, memo| (value.to_s.length > memo.to_s.length) ? value : memo }) * 1.25
        else
          longest_left_label_width = calculate_width(@marker_font_size,
                                                     label(@maximum_value.to_f, @increment))
        end

        # Shift graph if left line numbers are hidden
        line_number_width = @hide_line_numbers && !@has_left_labels ?
            0.0 :
            (longest_left_label_width + LABEL_MARGIN * 2)

        temp_labels = labels.values

        @graph_left = @left_margin + temp_labels.map(&:length).max * @label_font_size / 3
            # line_number_width +
            # (@y_axis_label.nil? ? 0.0 : @marker_caps_height + LABEL_MARGIN * 2)

        # Make space for half the width of the rightmost column label.
        # Might be greater than the number of columns if between-style bar markers are used.
        last_label = @labels.keys.sort.last.to_i
        extra_room_for_long_label = (last_label >= (@column_count-1) && @center_labels_over_point) ?
            calculate_width(@marker_font_size, @labels[last_label]) / 2.0 :
            0
        @graph_right_margin = @right_margin + extra_room_for_long_label

        @graph_bottom_margin = @bottom_margin +
            @marker_caps_height + LABEL_MARGIN
      end

      @graph_right = @raw_columns - @graph_right_margin
      @graph_width = @raw_columns - @graph_left - @graph_right_margin

      # When @hide title, leave a title_margin space for aesthetics.
      # Same with @hide_legend
      @graph_top = @legend_at_bottom ? @top_margin : (@top_margin +
          (@hide_title ? title_margin : @title_caps_height + title_margin) +
          (@hide_legend ? legend_margin : @legend_caps_height + legend_margin))

      x_axis_label_height = @x_axis_label.nil? ? 0.0 :
          @marker_caps_height + LABEL_MARGIN
      # FIXME: Consider chart types other than bar
      @graph_bottom = @raw_rows - @graph_bottom_margin - x_axis_label_height - @label_stagger_height
      @graph_height = @graph_bottom - @graph_top
    end

  def draw_bars
    # Setup spacing.
    #
    # Columns sit stacked.
    @bar_spacing ||= 0.9

    @bar_width = @graph_height / @column_count.to_f
    @d = @d.stroke_opacity 0.0
    height = Array.new(@column_count, 0)
    length = Array.new(@column_count, @graph_left)
    padding = (@bar_width * (1 - @bar_spacing)) / 2
    if @show_labels_for_bar_values
      label_values = Array.new
      0.upto(@column_count-1) {|i| label_values[i] = {:value => 0, :right_x => 0}}
    end
    @norm_data.each_with_index do |data_row, row_index|
      data_row[DATA_VALUES_INDEX].each_with_index do |data_point, point_index|

    	  ## using the original calcs from the stacked bar chart to get the difference between
    	  ## part of the bart chart we wish to stack.
    	  temp1 = @graph_left + (@graph_width -
                                    data_point * @graph_width -
                                    height[point_index]) + 1
    	  temp2 = @graph_left + @graph_width - height[point_index] - 1
    	  difference = temp2 - temp1

    	  @d = @d.fill data_row[DATA_COLOR_INDEX]

        left_x = length[point_index] #+ 1
              left_y = @graph_top + (@bar_width * point_index) + padding
    	  right_x = left_x + difference
              right_y = left_y + @bar_width * @bar_spacing
    	  length[point_index] += difference
        height[point_index] += (data_point * @graph_width - 2)

        if @show_labels_for_bar_values
          label_values[point_index][:value] += @norm_data[row_index][3][point_index]
          label_values[point_index][:right_x] = right_x
        end

        # if a data point is 0 it can result in weird really thing lines
        # that shouldn't even be there being drawn on top of the existing
        # bar - this is bad
        if data_point != 0
          @d = @d.rectangle(left_x, left_y, right_x, right_y)
          # Calculate center based on bar_width and current row
        end
        # we still need to draw the labels
        # Calculate center based on bar_width and current row
        label_center = @graph_top + (@bar_width * point_index) + (@bar_width * @bar_spacing / 2.0)
        draw_label(label_center, point_index)
      end

    end
    if @show_labels_for_bar_values
      label_values.each_with_index do |data, i|
        val = (@label_formatting || "%.2f") % data[:value]
        draw_value_label(data[:right_x]+40, (@graph_top + (((i+1) * @bar_width) - (@bar_width / 2)))-12, val.commify, true)
      end
    end

    @d.draw(@base_image)
  end

  def larger_than_max?(data_point, index=0)
    max(data_point, index) > @maximum_value
  end

  def max(data_point, index)
    @data.inject(0) {|sum, item| sum + item[DATA_VALUES_INDEX][index]}
  end

end
