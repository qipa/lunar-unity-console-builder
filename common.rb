require_relative 'tools/copyrighter/copyright'

require 'colorize'

module Builder

  # prints header
  def print_header(message)
    puts message.blue
  end

  def print_progress(message)
    puts message
  end

  ############################################################

  # check condition and raise exception
  def fail_script(message)
    raise "Build failed! #{message}"
  end

  ############################################################

  # check condition and raise exception
  def fail_script_if(condition, message)
    fail_script message if condition
  end

  ############################################################

  # check condition and raise exception
  def fail_script_unless(condition, message)
    fail_script message unless condition
  end

  ############################################################

  # check if file exists and raise exception
  def fail_script_unless_file_exists(path)
    fail_script_unless path != nil && (File.directory?(path) || File.exists?(path)), "File doesn't exist: '#{path}'"
  end

  ############################################################

  def not_nil(value)
    fail_script_unless value != nil, 'Value is nil'
    return value
  end

  ############################################################

  def extract_regex(text, pattern)
    text =~ pattern
    return $1
  end

  ############################################################

  # checks if path exists and returns it
  def resolve_path(path)
    fail_script_unless_file_exists path
    return path
  end

  ############################################################

  def build_ios_app(proj_dir, proj_name, configuration, target, export_path = nil)
    fail_script_unless_file_exists proj_dir

    Dir.chdir(proj_dir) do
      dir_build = 'build'
      sdk_name = 'iphoneos'

      # cleanup
      FileUtils.rm_rf(dir_build)

      # build
      cmd = %(xcodebuild -project "#{proj_name}.xcodeproj" -configuration "#{configuration}" -target "#{target}" -sdk #{sdk_name})
      exec_shell(cmd, "Can't build ios app")

      # result file
      export_path = "build/#{configuration}-#{sdk_name}" if export_path.nil?

      Dir.chdir export_path do
        app_files = Dir['*.app']
        fail_script_unless app_files.length == 1, "Unexpected apps count: #{app_files.join(',')}"
        app_file = app_files.first

        return File.expand_path app_file
      end

    end
  end

  ############################################################

  # execute shell command and raise exception if fails
  def exec_shell(command, error_message, options = {})
    puts "Running command: #{command}" unless options[:silent] == true
    result = `#{command}`
    if options[:dont_fail_on_error] == true
      puts error_message unless $?.success?
    else
      fail_script_unless($?.success?, "#{error_message}\nShell failed: #{command}\n#{result}")
    end

    return result
  end

  def delete_file(path)
    if Dir.exist? path
      FileUtils.rm_rf path
    elsif File.exist? path
      FileUtils.rm_f path
    end
  end

  def list_files(dir, options = {})

    files = []

    ignored_files = options[:ignored_files] || []
    types = options[:types]
    list_directories = options[:list_directories]

    Dir["#{dir}/*"].each {|file|

      next if ignored_files.include?(File.basename file)

      if File.directory? file
        files.push file if list_directories
        files.push *(list_files file, options)
      else
        next if types && !types.include?(File.extname file)
        files.push file
      end
    }

    return files

  end

  def fix_copyrights(dir_project, dir_headers, options = {})

    print_header 'Fixing copyright...'

    file_header = resolve_path "#{dir_headers}/copyright.txt"
    copyright_header = File.read file_header

    files = list_files dir_project, options

    modified_files = []

    files.each {|file|
      modified_files.push file if fix_copyright(file, copyright_header)
    }

    return modified_files

  end

  def fix_copyright(file, header)

    old_source = File.read file

    source_no_header = Copyright.remove_header_comment old_source

    copyright = Copyright.new header
    copyright.set_param 'date.year', Time.now.year.to_s
    copyright.set_param 'file.name.ext', File.basename(file)
    copyright.set_param 'file.name', File.basename(file, '.*')

    new_source = copyright.process
    new_source << "\n\n"
    new_source << source_no_header

    if new_source != old_source

      File.open(file, 'w') { |f|
        f.write new_source
      }
      return true
    end

    return false
  end

  def get_release_notes(dir_repo, version)

    header = "## v.#{version}"

    file_release_notes = resolve_path "#{dir_repo}/CHANGELOG.md"

    lines = File.readlines file_release_notes

    start_index = -1
    end_index = -1

    (0 .. lines.length - 1).each do |index|
      line = lines[index]
      if line.include? header
        start_index = index + 1
        break
      end
    end

    (start_index + 1 .. lines.length - 1).each do |index|
      line = lines[index]
      if line =~ /## v\.\d+\.\d+\.\d+/
        end_index = index - 1
        break
      end
    end


    fail_script_unless start_index != -1 && end_index != -1, "Can't extract release notes"

    notes = lines[start_index..end_index].join
    notes.strip!
    notes.gsub! '"', '\\"'
    notes.gsub! '``', '\\`'

    return notes

  end

end