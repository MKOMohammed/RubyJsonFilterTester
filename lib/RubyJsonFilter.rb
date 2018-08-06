require 'yajl'
require 'ostruct'
require 'json'
# Extending String class by adding function to determine if the string
# is numeric or not
class String
  #
  # Check if the strig is numeric or not
  #
  # == Returns:
  # true if the string is numeric, false other wise.
  #
  def numeric?
    Float(self) != nil rescue false
  end
end

#
# Create new traces by removing all unnessesary data from generated
# execution traces and reformat them.
#
class FilteredTraces
  #
  # Initialize the FilteredTraces object
  #
  # @param [List of String] params contains the original trace to be filtered and the student code
  # @option params[0] [String] the original trace to be filtered
  # @option params[1] [String] the Student code
  #
  def initialize(params = {})
    @traces_json_string = ''
    @traces_json_array = []
    @traces = []
    @new_traces = []
    @code = params[1]
    @code << ''
    @code << 'return statement'
    remove_useless_traces_data(params)
  end

  #
  # Removes all unnessesary data from the traces
  #
  # @param (see #initialize)
  #
  def remove_useless_traces_data(params)
    convert_list_of_json_traces_to_objects(params[0])
    create_new_traces
    @traces_json_string = '[' + @traces_json_string[0...-1] + ']'
    puts @traces_json_string
  end

  #
  # Converts a trace string to JSON Object
  #
  # @param [String] trace a string that contains the trace of line of code
  #
  # @return [JSON] the equivalent JSON object for the trace string
  #
  def convert_json_trace_to_object(trace)
    JSON.parse(trace[1...-1].insert(0, '{'), object_class: OpenStruct)
  end

  #
  # Converts all traces strings into JSON objects
  #
  # @param [List of Strings] list_of_traces list of strings that represents traces for all lines of code
  #
  # @return [List of JSON objects] the equivalent JSON objects for each trace string.
  #
  def convert_list_of_json_traces_to_objects(list_of_traces)
    list_of_traces.each do |trace|
      @traces << convert_json_trace_to_object(trace)
    end
  end

  #
  # Generate the traces that will be used in the visualization process. This is done by
  # 1- extract the variables names form the trace
  # 2- extract the encoded locals from the trace
  # 3- extract the heap values form the trace
  # 4- extract the code from the trace
  #
  def create_new_traces
    @traces.each do |trace|
      trace_stack = trace.stack_to_render[0]
      unless(trace_stack.func_name.include? '<init>')
      trace_stack_ordered_variable_names = trace_stack.ordered_varnames
      trace_stack_encoded_locals = trace_stack.encoded_locals
      trace_heap = trace.heap
      trace_code = @code[trace.line]
      filtered_trace = filter_trace([
                                      trace_stack_ordered_variable_names,
                                      trace_stack_encoded_locals,
                                      trace_heap,
                                      trace_code,
                                      trace.line
                                    ])
      @new_traces << filtered_trace
      trace_string = Yajl::Encoder.encode(filtered_trace)
      @traces_json_array << trace_string
      @traces_json_string += trace_string + ','
      end
    end
  end

  #
  # Creates the new filtered trace object.
  #
  # @param [List of Strings] params list of strings that represent the main traces fields
  # @option params[0] [String] trace_stack_ordered_variable_names
  # @option params[1] [String] trace_stack_encoded_locals
  # @option params[2] [String] trace_heap
  # @option params[3] [String] trace_code
  # @option params[4] [String] trace line number
  #
  # @return [Hash] The new filtered trace
  #
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
      trace['heap'][key] = value if value.is_a?(Array) && value.length > 2
    end
    trace['code'] = params[3]
    trace['lineNumber'] = params[4]
    trace
  end

  #
  # getter method to return the new trace as JSON string
  #
  # @return [String] the String of the new traces to be used in Visualization
  #
  def return_json_string
    @traces_json_string
  end
end

#
# Generates the full execution trace for the complete source code by executing
# the command related to Java_Jail
# @param [String] junit_test_file the complete source code
# @param [String] files_path the path for the file that will contains the code
# @param [String] files_path Not used
# @param [String] student_file_name the complete source code file name
# @return [String] The complete execution trace
#
def generate_backend_trace(junit_test_file,
                           files_path,
                           peruser_files_path,
                           student_file_name)
  raw_code = junit_test_file
  raw_code.gsub! "\n", "\\n" + "\n"
  raw_code.gsub! "\t", "\\t"
  lines = raw_code.split("\n")
  jUnit_test = ''
  lines.each { |line| jUnit_test += line}
  jUnit_test.gsub!('\"', "\\" + '\"')
  student_file = File.open(File.join(File.dirname(File.expand_path(__FILE__)),
                                     peruser_files_path,
                                     student_file_name), 'w+')
  full_string = '{' + "\n" + '"' + 'usercode' + '"' + ':' + '"' + jUnit_test +
                '"' + ',' + "\n" + '"' + 'options' + '"' + ':' + '{' + '}' \
                ',' + "\n" + '"' + 'args' + '"' + ':' + '[' + ']' + ',' \
                "\n" + '"' + 'stdin' + '"' + ':' + '"' + '"' + "\n" + '}'
  student_file.puts(full_string)
  student_file.close
  output = `java -cp .:cp:cp/javax.json-1.0.4.jar:java/tools.jar traceprinter.InMemory < cp/traceprinter/output.txt` # the shell command
  output
end

#
# Generates the trace string that will be used in the visualization by 
# generating the full execution trace then filter out all unnessesary traces
# param (see #generate_backend_trace)
# @return the trace string to be used in the visualization
#
def seperate_and_filter_trace(junit_test_file,
                              files_path,
                              peruser_files_path,
                              student_file_name)
  code_and_trace = generate_backend_trace(junit_test_file,
                                          files_path,
                                          peruser_files_path,
                                          student_file_name)
  splitter = '"' + 'trace' + '"' + ':'
  user_code, whole_trace = code_and_trace.split(splitter)

  whole_trace = whole_trace[1..whole_trace.length]

  entire_json_file = code_analyzer(user_code, whole_trace)

  entire_json_file
end

# Event class represents each step in the execution trace.
class Event
  attr_accessor :trace, :line_number

  def initialize
    @trace = ''
    @line_number = 0
  end

  #
  # Sets the line number
  #
  # @param [Numeric] line_number the line number value
  #
  def set_line(line_number)
    @line_number = line_number
  end

  #
  # Sets the trace
  #
  # @param [String] trace trace value
  #
  def set_event(trace)
    @trace = trace
  end
end

# This class will hold a list of all traces.
# This class will filter out all traces that are not related to the
# visualization process
class EventManager
  attr_accessor :list_of_events, :filtered_events

  def initialize
    @list_of_events = []
    @filtered_events = []
  end

  #
  # gets the line number if the trace at the specified index
  #
  # @param [Numeric] index trace index
  #
  # @return [Numeric] the line number fo the trace
  #
  def get_line_number(index)
    if @list_of_events.length.zero?
      puts 'list is empty'
    else
      temp_event = @list_of_events[index]
      temp_event.line_number
    end
  end

  #
  # Sets the event to the Event object
  #
  # @param [<Type>] index the index for the event
  # @param [<Type>] event the value of the Event Object
  #
  def set_event(index, event)
    @filtered_events[index] = event
  end

  #
  # Gets the event Object
  #
  # @param [Numeric] index the index for the event
  #
  # @return [Event] the value of the Event Object
  #
  def get_event(index)
    @filtered_events[index]
  end

  #
  # Adds the event to the list of events
  #
  # @param [Event] event the Event object to be added to the list
  #
  def add_event(event)
    @list_of_events << event
  end

  #
  # Get the list of Events object
  #
  # @return [List of Events] the list of Events object
  #
  def trace_list
    my_list = []
    (0...@list_of_events.length).each do |x|
      temp = @list_of_events[x]
      my_list << temp.trace
    end
    my_list
  end

  #
  # Prints the events one by one
  #
  def print_events
    if @filtered_events.length.zero?
      puts 'List of events is empty'
    else
      (0..@filtered_events.length).each do |x|
        temp_event = @filtered_events[x]
        puts temp_event.trace
      end
    end
  end

  #
  # Correct the line number in each trace. In the begining, the line number value is
  # numbered based on the begining os the complete code. This method re calculates
  # the line number based on the start of the student code.
  #
  def modify_lines (code)
    line_number = 0
    event_number = 0
    initial_line_number = @list_of_events[0].line_number
    @list_of_events.each do |modify|
      temp_string = modify.trace
      temp_line = modify.line_number
      line_number = temp_line % initial_line_number
      if code[line_number] == 'newline' || code[line_number] == '\\t'
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

# This class is responsible for creating the EventManager object to handle the traces.
# It filter the traces by extracting the part of the trace correspond to the student solution
class TraceAnalyzer
  def initialize
    @event_manager = EventManager.new
  end

  #
  # filter the traces by extracting the part of the trace correspond to the
  # student solution
  #
  # @param [String] user_code the student solution
  # @param [String] in_trace the complete execution trace
  #
  # @return [String] the trace string that will be used to visualize the student solution
  #
  def handle_everything(user_code, in_trace)
    exe_Point_Finder(in_trace)
    @event_manager.modify_lines(user_code)
    raw_events = @event_manager.trace_list
    filtered_out_events = FilteredTraces.new([raw_events, user_code])
    filtered_out_events.return_json_string
  end

  def empty?(any_structure)
    any_structure.length.zero?
  end

  #
  # Extracts the code line number form the given trace string
  #
  # @param [String] string trace string
  #
  # @return [Numeric] the line number
  #
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

  #
  # Validate that the trace is for the student code. Requiers reimplementing
  #
  # @param [true or false] on true means that this trace after the stratTraceNow call
  # @param [true or false] off <description>
  # @param [String] in_point the trace of the student code
  #
  # @return [true or false] true means that the trace is for the student code
  #
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

  #
  # Extract the execution trace for the student solution only.
  # THis is done by finding the execution trace for the code that is surrounded
  # by startTraceNow and endTraceNow function calls.
  #
  # @param [String] trace the complete execution trace
  #
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

#
# Extract student code from the complete source code
#
# @param [String] code The complete source code
#
# @return [String] The student code
#
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
    student_code << executed_code_list[x] unless temp.empty?

    x += 1
  end
  student_code
end

#
# Extracts the student code and its trace
#
# @param [String] code The complete code
# @param [String] first_trace The complete execution trace
#
# @return [String] the filtered trace that will be used in the visualization process.
#
def code_analyzer(code, first_trace)
  code_to_viz = code_splitter(code)
  trace_analyzer = TraceAnalyzer.new
  trace_analyzer.handle_everything(code_to_viz, first_trace)
end

#
# The main method that will be called from OpenPOP server to generate the trace
# that will be used for the visualization
#
# @param [String] file_path the name and location of the file that will store the complete source code
# @param [String] student_full_code The complete source code
#
# @return [String] the trace that will be usend in the visualization process
#
def main_method(file_path, student_full_code)
  my_test = seperate_and_filter_trace(student_full_code, file_path,
                                      'cp/traceprinter/', 'output.txt')
  Dir.chdir('/home')
  #puts my_test
  my_test
end

#
# This function is uesd in testing only.
#
# @return [String] the trace that will be usend in the visualization process
#
def create_student_full_code
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

create_student_full_code
