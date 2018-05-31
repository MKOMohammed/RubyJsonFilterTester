require 'yajl'
require 'ostruct'
require 'json'
# class to extend String class by adding function to determine if the string is numeric or not
class String
  def numeric?
    Float(self) != nil rescue false
  end
end

# class to create new traces by removing all unnessesary data from generated traces
class FilteredTraces
  def initialize(params = {})
    @traces_json_string = ''
    @traces = []
    @new_traces = []
    @code = params[1]
    @code << ''
    @code << 'return statement'
    remove_useless_traces_data(params)
  end

  def remove_useless_traces_data(params)
    convert_list_of_json_traces_to_objects(params[0])
    create_new_traces()
    @traces_json_string = '[' + @traces_json_string[0...-1] + ']'
    puts @traces_json_string
  end

  def convert_json_trace_to_object(trace)
    JSON.parse(trace[1...-1].insert(0, '{'), object_class: OpenStruct)
  end

  def convert_list_of_json_traces_to_objects(list_of_traces)
    list_of_traces.each do |trace|
      @traces << convert_json_trace_to_object(trace)
    end
  end

  def create_new_traces
    @traces.each do |trace|
      trace_stack = trace.stack_to_render[0]
      trace_stack_ordered_variable_names = trace_stack.ordered_varnames
      trace_stack_encoded_locals = trace_stack.encoded_locals
      trace_heap = trace.heap
      trace_code = @code[trace.line]
      filtered_trace = filter_trace([
                                      trace_stack_ordered_variable_names,
                                      trace_stack_encoded_locals,
                                      trace_heap,
                                      trace_code
                                    ])
      @new_traces << filtered_trace
      @traces_json_string += Yajl::Encoder.encode(filtered_trace) + ','
    end
  end

  def filter_trace(params)
    trace = {}
    trace['stack'] = {}
    trace['stack']['ordered_variable_names'] = params[0]
    trace['stack']['encoded_locals'] = {}
    params[1].each_pair do |key, value|
      trace['stack']['encoded_locals'][key] = value
    end
    trace['heap'] = {}
    params[2].each_pair do |key, value|
      trace['heap'][key] = value if value.length > 2
    end
    trace['code'] = params[3]
    trace
  end
end

def generate_backend_trace(junit_test_file, files_path, peruser_files_path, student_file_name)
  raw_code = junit_test_file
  raw_code.gsub! "\n", "\\n" + "\n"
  raw_code.gsub! "\t", "\\t"
  lines = raw_code.split("\n")
  jUnit_test = ""
  lines.each {|line| jUnit_test = jUnit_test + line}
  jUnit_test.gsub!('\"', "\\" + '\"')
  student_file = File.open(File.join(File.dirname(File.expand_path( __FILE__)),peruser_files_path, student_file_name), "w+")
  #puts "file path #{student_file.path}"
  fullString = '{' + "\n" + '"' + "usercode" + '"' + ':' + '"' + jUnit_test + '"' +
      ',' + "\n" + '"' + "options" + '"' + ':' + '{' + '}' + ',' +
      "\n" + '"' + "args" + '"' + ':' + '[' + ']' + ',' + "\n" + '"' +
      "stdin" + '"' + ':' + '"' + '"' + "\n" + '}'
  student_file.puts(fullString)
  student_file.close
  #puts "student file #{fullString}"
  #Dir.chdir "/home/mdn/Research/OpenDSA-DevStack/OpenPOP/Java-Visualizer/frontAndBackendFiles/backendFiles"
  #output = `./java/bin/java -cp .:cp:cp/javax.json-1.0.jar:java/lib/tools.jar traceprinter.InMemory < cp/traceprinter/output.txt` # the shell command
  output = `java -cp .:cp:cp/javax.json-1.0.4.jar:java/tools.jar traceprinter.InMemory < cp/traceprinter/output.txt` # the shell command
  #puts output
  return output

end

def seperate_and_filter_trace(junit_test_file, files_path, peruser_files_path, student_file_name)
  code_and_trace = generate_backend_trace(junit_test_file, files_path, peruser_files_path,
                                          student_file_name)
  splitter = '"' + "trace" + '"' + ':'
  user_code, whole_trace = code_and_trace.split(splitter)

  whole_trace = whole_trace[1..whole_trace.length]

  entire_json_file = code_analyzer(user_code, whole_trace)

  return entire_json_file
end

class Event
  attr_accessor :trace, :line_number

  def initialize()
    @trace = ""
    @line_number = 0
  end

  def set_line(line_number)
    @line_number = line_number
  end

  def set_event(trace)
    @trace = trace
  end
end

class EventManager
  attr_accessor :list_of_events, :filtered_events

  def initialize
    @list_of_events = []
    @filtered_events = []
  end

  def get_line_number(index)
    if @list_of_events.length == 0
      puts "list is empty"
    else
      temp_event = @list_of_events[index]
      return temp_event.line_number
    end
  end

  def set_event (index, event)
    @filtered_events[index] = event
  end

  def get_event(index)
    return @filtered_events[index]
  end

  def add_event(event)
    @list_of_events << event
  end

  def trace_list
    my_list = []
    (0...@list_of_events.length).each do |x|#@filtered_events.length).each do |x|
      #temp = Event.new
      temp = @list_of_events[x]#@filtered_events[x]
      my_list<<temp.trace
    end
    return my_list
  end

  def print_events
    if @filtered_events.length == 0
      puts 'List of events is empty'
    else
      (0..@filtered_events.length).each do |x|
        temp_event = @filtered_events[x]
        puts temp_event.trace
      end
    end
  end

  def modify_lines (code)
    line_number = 0
    event_number = 0
    initial_line_number = @list_of_events[0].line_number
    @list_of_events.each do |modify|
      temp_string = modify.trace
      temp_line = modify.line_number
      line_number = temp_line % initial_line_number
      if code[line_number] == 'newline'
        line_number += 1
      elsif code[line_number] == '\\t'
        line_number += 1
      else
        original_line = temp_line.to_s
        new_line = line_number.to_s
        temp_string.gsub! original_line, new_line
        modified_event = Event.new
        modified_event.set_event(temp_string)
        modified_event.set_line(line_number)
        @list_of_events[event_number] = modified_event

        event_number += 1
      end
    end
  end
end
# HERERERERERERER
def modify_stack (my_list)
  old_stack = []
  curly_stack = []
  list_of_stack_points = []

  (0...my_list.length).each do |x|
    cur_event = my_list[x].split("stack_to_render\":[")
    stacks = cur_event[1].split("],\"globals\"")

    stack_to_render = stacks[0]
    old_stac << stacks[0]

    stack_point = ''

    stack_to_render.split('').each do |i|
      stack_point += i
      if i == '{'
        curly_stack << i
      elsif i == '}'
        curly_stack.pop
        if curly_stack.length.zero?
          list_of_stack_points << stack_point
          stack_point = ''
        else
          next
        end
      end
    end
  end

  main = 'main:'

  new_stack = []

  (0...list_of_stack_points.length).each do |x|
    if list_of_stack_points[x].include? main
      # Do nothing
      next
    else
      new_stack << list_of_stack_points[x]
    end
  end

  (0...my_list.length).each do |x|
    my_list[x].gsub!(old_stack[x], new_stack[x])
  end
  my_list
end

# no comment
class TraceAnalyzer
  def initialize
    @event_manager = EventManager.new
  end

  def handle_everything(user_code, in_trace)
    exe_Point_Finder(in_trace)
    @event_manager.modify_lines(user_code)
    raw_events = @event_manager.trace_list
    filtered_out_events = FilteredTraces.new([raw_events, user_code])
    modify_stack(raw_events)
  end

  def empty?(any_structure)
    any_structure.length.zero?
  end

  def extract_line_num(string)
    line = string.tr '"', ' '
    line.tr! '{', ' '
    line.tr! ':', ' '
    line.tr! ',', ' '
    line.tr! '[', ' '
    line.tr! '(', ' '
    line.tr! ']', ' '
    line.tr! '}', ' '
    line.tr! ')', ' '
    new_line = []
    line.split.each do |s|
      new_line << s.to_i if s.numeric?
    end
    new_line[0]
  end

  def verify_exe_point(on, off, in_point)
    add_exe_point = false
    exe_trace = Event.new
    if on == true && off == false
      exe_trace.set_event(in_point)
      exe_trace.set_line(extract_line_num(in_point))
      @event_manager.add_event(exe_trace)
      add_exe_point = true
    elsif on == false && off == false
      add_exe_point = false
    else
      add_exe_point = false
    end
    add_exe_point
  end

  def exe_Point_Finder(trace)
    symbol_stack = []
    other_list = []
    top_symbol = ''
    exe = ''
    exe_point = ' '
    on = false
    off = false
    trace.split('').each do |i|
      current_symbol = i
      exe_point += current_symbol
      if i == '{' or i == '[' or i == '('
        symbol_stack << i
      elsif i == '}' or i == ')' or i == ']'
        if empty?(symbol_stack) == false
          top_symbol = symbol_stack.pop
          if i == '}' and top_symbol != '{'
            next
          end
        end
      elsif i == ','
        other_list << exe_point
        if symbol_stack.length.zero?
          other_list.each do |thing|
            exe += thing
          end
          if exe.include? 'startTraceNow'
            on = true
            exe = ''
            exe_point = ''
            other_list = []
          elsif exe.include? 'endTraceNow'
            off = true
            return
          else
            flag = verify_exe_point(on, off, exe)
            on = false if flag == false
            exe = ''
            exe_point = ''
            other_list = []
          end
        else
          exe_point = ''
        end

      else
        next
      end
    end
  end
end

def empty?(structure)
  structure.length.zero?
end

def code_splitter(code)
  student_code = []
  code = code.split('startTraceNow();')
  new_code = code[1].split('endTraceNow();')
  executed_code = new_code[0]
  executed_code_list = executed_code.split('\\n')
  flag = false
  counter = 0
  until flag
    if executed_code_list[counter] == '' || executed_code_list[counter] == ' '
      flag = false
      counter += 1
    elsif executed_code_list[counter] != ''
      flag = true
    end
  end
  x = counter
  while x < executed_code_list.length
    temp = executed_code_list[x]
    temp = temp.strip
    student_code << if temp.empty?
                      'newline'
                    else
                      executed_code_list[x]
                    end
    x += 1
  end
  student_code
end

def code_analyzer(code, first_trace)
  code_to_viz = code_splitter(code)
  trace_analyzer = TraceAnalyzer.new
  trace_analyzer.handle_everything(code_to_viz, first_trace)
end

def main_method (file_path, student_full_code)
  my_test = seperate_and_filter_trace(student_full_code, file_path,
                                      'cp/traceprinter/', 'output.txt')
  Dir.chdir('/home')
  my_test
end

def create_student_full_code()
  puts Dir.pwd
  @student_code = ''
  File.open('code.txt', 'rb') do |code_file|
    code = code_file.read()
    code = code.split("\n")
    code.each { |line| @student_code += line + "\n" unless line.empty? }
  end
  File.open('part1.txt', 'rb') do |part1file|
    @part1 = part1file.read
  end
  File.open('part2.txt', 'rb') do |part2file|
    @part2 = part2file.read
  end
  full_student_code = @part1 + @student_code + "\n" + @part2

  main_method('', full_student_code)
end

student_code = create_student_full_code()