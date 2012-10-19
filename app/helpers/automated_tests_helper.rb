require 'libxml'
require 'open3'

# Helper methods for Testing Framework forms
module AutomatedTestsHelper
  include LibXML

  def enqueue_test()
  end

  # Verify the user has the permission to run the tests - admin
  # and graders always have the permission, while student has to
  # belong to the group and has >0 tokens.
  def has_permission?()
    if @current_user.admin?
      return true
    elsif @current_user.ta?
      return true
    elsif @current_user.student?
      # Make sure student belongs to this group
      if not @current_user.accepted_groupings.include?(@grouping)
        return false
      end
      t = @grouping.token
      if t == nil
        raise I18n.t("automated_tests.missing_tokens")
      end
      if t.tokens > 0
        t.decrease_tokens
        return true
      else
        return false
      end
    end
  end

  # Verify that the system has all the files and information in order to
  # run the test.
  def files_available?()
    #code stub
    return true
  end

  # From a list of test servers, choose the next available server
  # using round-robin. Keep looking for available server until
  # one is found.
  # TODO: set timeout and return error if no server is available
  def choose_test_server()
    # code stub
    return 1
  end

  # Launch the test on the test server by scp files to the server
  # and run the script.
  # This function returns two values: first one is the output from
  # stdout or stderr, depending on whether the execution passed or
  # had error; the second one is a boolean variable, true => execution
  # passeed, false => error occurred.
  def launch_test(server_id, group, assignment)
    # Get src_dir
    src_dir = "${HOME}/workspace_aptana/Markus/data/dev/automated_tests/group_0017/a7"

    # Get test_dir
    test_dir = "${HOME}/workspace_aptana/Markus/data/dev/automated_tests/a7"
    #test_dir = File.join(MarkusConfigurator.markus_config_automated_tests_repository, assignment.short_identifier)

    # Get the account and address of the server
    server_account = "localtest"
    server_address = "scspc328.cs.uwaterloo.ca"

    # Get the directory and name of the script
    script_dir = "/home/#{server_account}/testrunner"
    script_name = "run.sh"

    # Get dest_dir of the files
    dest_dir = "/home/#{server_account}/testrunner/all"

    # Remove everything in dest_dir
    stdout, stderr, status = Open3.capture3("ssh #{server_account}@#{server_address} rm -rf #{dest_dir}")
    if !(status.success?)
      return [stderr, false]
    end

    # Securely copy files to dest_dir
    stdout, stderr, status = Open3.capture3("scp -p -r #{src_dir} #{server_account}@#{server_address}:#{dest_dir}")
    if !(status.success?)
      return [stderr, false]
    end
    stdout, stderr, status = Open3.capture3("scp -p -r #{test_dir} #{server_account}@#{server_address}:#{dest_dir}")
    if !(status.success?)
      return [stderr, false]
    end

    # Run script
    stdout, stderr, status = Open3.capture3("ssh #{server_account}@#{server_address} #{script_dir}/#{script_name}")
    if !(status.success?)
      return [stderr, false]
    else
      return [stdout, true]
    end

  end

  def result_available?()
  end

  def process_result(results_xml)
    test = AutomatedTests.new
    results_xml = results_xml ||
      File.read(RAILS_ROOT + "/automated-tests-files/test.xml")
    parser = XML::Parser.string(results_xml)
    doc = parser.parse

    # get assignment_id
    assignment_node = doc.find_first("/test/assignment_id")
    if not assignment_node or assignment_node.empty?
      raise "Test result does not have assignment id"
    else
      test.assignment_id = assignment_node.content
    end

    # get test_script_id
    test_script_node = doc.find_first("/test/test_script_id")
    if not test_script_node or test_script_node.empty?
      raise "Test result does not have test_script id"
    else
      test.test_script_id = test_script_node.content
    end

    # get group id
    group_id_node = doc.find_first("/test/group_id")
    if not group_id_node or group_id_node.empty?
      raise "Test result has no group id"
    else
      test.group_id = group_id_node.content
    end

    # get result: pass, fail, or error
    result_node = doc.find_first("/test/result")
    if not result_node or result_node.empty?
      raise "Test result has no result"
    else
      if result_node.content != "pass" and result_node.content != "fail" and
         result_node.content != "error"
        raise "invalid value for test result. Should be pass, fail or error"
      else
        test.result = result_node.content
      end
    end

    # get markus earned
    marks_earned_node = doc.find_first("/test/marks_earned")
    if not marks_earned_node or marks_earned_node.empty?
      raise "Test result has no marks earned"
    else
      test.marks_earned = marks_earned_node.content
    end

    # get input
    input_node = doc.find_first("/test/input")
    if not input_node or input_node.empty?
      raise "Test result has no input"
    else
      test.input = input_node.content
    end

    # get expected_output
    expected_output_node = doc.find_first("/test/expected_output")
    if not expected_output_node or expected_output_node.empty?
      raise "Test result has no expected_output"
    else
      test.expected_output = expected_output_node.content
    end

    # get actual_output
    actual_output_node = doc.find_first("/test/actual_output")
    if not actual_output_node or actual_output_node.empty?
      raise "Test result has no actual_output"
    else
      test.actual_output = actual_output_node.content
    end

    test.save
  end

  def add_test_script_link(name, form)
    link_to_function name do |page|
      test_file = render(:partial => 'test_file',
                         :locals => {:form => form,
                                     :test_file => TestFile.new,
                                     :file_type => "testscript"})
      page << %{
        if ($F('is_testing_framework_enabled') != null) {
          var new_test_file_id = new Date().getTime();
          $('script_files').insert({bottom: "#{ escape_javascript test_file }".replace(/(attributes_\\d+|\\[\\d+\\])/g, new_test_file_id) });
          $('assignment_test_files_' + new_test_file_id + '_filename').focus();
        } else {
          alert("#{I18n.t("automated_tests.add_test_file_alert")}");
        }
      }
    end
  end

  def add_test_file_link(name, form)
    link_to_function name do |page|
      test_file = render(:partial => 'test_file',
                         :locals => {:form => form,
                                     :test_file => TestFile.new,
                                     :file_type => "testfile"})
      page << %{
        if ($F('is_testing_framework_enabled') != null) {
          var new_test_file_id = new Date().getTime();
          $('test_files').insert({bottom: "#{ escape_javascript test_file }".replace(/(attributes_\\d+|\\[\\d+\\])/g, new_test_file_id) });
          $('assignment_test_files_' + new_test_file_id + '_filename').focus();
        } else {
          alert("#{I18n.t("automated_tests.add_lib_file_alert")}");
        }
      }
    end
  end

  #need to implement this
  #this is called when a new test script file is added
  def add_test_script_options(form)

    #TODO

  end

  # NEEDS TO BE UPDATES
  # Process Testing Framework form
  # - Process new and updated test files (additional validation to be done at the model level)
  def process_test_form(assignment, params)

    # Hash for storing new and updated test files
    updated_files = {}

    # Retrieve all test file entries
    testfiles = params[:assignment][:test_files_attributes]

    # First check for duplicate filenames:
    filename_array = []
    testfiles.values.each do |tfile|
      if tfile['filename'].respond_to?(:original_filename)
        fname = tfile['filename'].original_filename
        # If this is a duplicate filename, raise error and return
        if !filename_array.include?(fname)
          filename_array << fname
        else
          raise I18n.t("automated_tests.duplicate_filename") + fname
        end
      end
    end

    # Filter out files that need to be created and updated:
    testfiles.each_key do |key|

      tfile = testfiles[key]

      # Check to see if this is an update or a new file:
      # - If 'id' exists, this is an update
      # - If 'id' does not exist, this is a new test file
      tf_id = tfile['id']

      # If only the 'id' exists in the hash, other attributes were not updated so we skip this entry.
      # Otherwise, this test file possibly requires an update
      if tf_id != nil && tfile.size > 1

        # Find existing test file to update
        @existing_testfile = TestFile.find_by_id(tf_id)
        if @existing_testfile
          # Store test file for any possible updating
          updated_files[key] = tfile
        end
      end

      # Test file needs to be created since record doesn't exist yet
      if tf_id.nil? && tfile['filename']
        updated_files[key] = tfile
      end
    end

    # Update test file attributes
    assignment.test_files_attributes = updated_files

    # Update assignment enable_test and tokens_per_day attributes
    assignment.enable_test = params[:assignment][:enable_test]
    num_tokens = params[:assignment][:tokens_per_day]
    if num_tokens
      assignment.tokens_per_day = num_tokens
    end

    return assignment
  end

  # Verify tests can be executed
  def can_run_test?()
    if @current_user.admin?
      return true
    elsif @current_user.ta?
      return true
    elsif @current_user.student?
      # Make sure student belongs to this group
      if not @current_user.accepted_groupings.include?(@grouping)
        return false
      end
      t = @grouping.token
      if t == nil
        raise I18n.t("automated_tests.missing_tokens")
      end
      if t.tokens > 0
        t.decrease_tokens
        return true
      else
        return false
      end
    end
  end

  # Export group repository for testing
  def export_repository(group, repo_dest_dir)
    # Create the test framework repository
    if !(File.exists?(MarkusConfigurator.markus_config_automated_tests_repository))
      FileUtils.mkdir(MarkusConfigurator.markus_config_automated_tests_repository)
    end

    # Delete student's assignment repository if it already exists
    repo_dir = File.join(MarkusConfigurator.markus_config_automated_tests_repository, group.repo_name)
    if (File.exists?(repo_dir))
      FileUtils.rm_rf(repo_dir)
    end

    return group.repo.export(repo_dest_dir)
    rescue Exception => e
      return "#{e.message}"
  end

  # Export configuration files for testing
  def export_configuration_files(assignment, group, repo_dest_dir)
    assignment_dir = File.join(MarkusConfigurator.markus_config_automated_tests_repository, assignment.short_identifier)
    repo_assignment_dir = File.join(repo_dest_dir, assignment.short_identifier)

    # Store the Api key of the grader or the admin in the api.txt file in the exported repository
    FileUtils.touch(File.join(assignment_dir, "api.txt"))
    api_key_file = File.open(File.join(repo_assignment_dir, "api.txt"), "w")
    api_key_file.write(current_user.api_key)
    api_key_file.close

    # Create a file "export.properties" where group_name and assignment name are stored for Ant
    FileUtils.touch(File.join(assignment_dir, "export.properties"))
    api_key_file = File.open(File.join(repo_assignment_dir, "export.properties"), "w")
    api_key_file.write("group_name = " + group.group_name + "\n")
    api_key_file.write("assignment = " + assignment.short_identifier + "\n")
    api_key_file.close
  end

  # Delete test repository directory
  def delete_test_repo(group, repo_dest_dir)
    repo_dir = File.join(MarkusConfigurator.markus_config_automated_tests_repository, group.repo_name)
    # Delete student's assignment repository if it exists
    if (File.exists?(repo_dir))
      FileUtils.rm_rf(repo_dir)
    end
  end

  # Copy files needed for testing
  def copy_ant_files(assignment, repo_dest_dir)
    # Check if the repository where you want to copy Ant files to exists
    if !(File.exists?(repo_dest_dir))
      raise I18n.t("automated_tests.dir_not_exist", {:dir => repo_dest_dir})
    end

    # Create the src repository to put student's files
    assignment_dir = File.join(MarkusConfigurator.markus_config_automated_tests_repository, assignment.short_identifier)
    repo_assignment_dir = File.join(repo_dest_dir, assignment.short_identifier)
    FileUtils.mkdir(File.join(repo_assignment_dir, "src"))

    # Move student's source files to the src repository
    pwd = FileUtils.pwd
    FileUtils.cd(repo_assignment_dir)
    FileUtils.mv(Dir.glob('*'), File.join(repo_assignment_dir, "src"), :force => true )

    # You always have to come back to your former working directory if you want to avoid errors
    FileUtils.cd(pwd)

    # Copy the build.xml, build.properties Ant Files and api_helpers (only one is needed)
    if (File.exists?(assignment_dir))
      FileUtils.cp(File.join(assignment_dir, "build.xml"), repo_assignment_dir)
      FileUtils.cp(File.join(assignment_dir, "build.properties"), repo_assignment_dir)
      FileUtils.cp("lib/tools/api_helper.rb", repo_assignment_dir)
      FileUtils.cp("lib/tools/api_helper.py", repo_assignment_dir)

      # Copy the test folder:
      # If the current user is a student, do not copy tests that are marked 'is_private' over
      # Otherwise, copy all tests over
      if @current_user.student?
        # Create the test folder
        assignment_test_dir = File.join(assignment_dir, "test")
        repo_assignment_test_dir = File.join(repo_assignment_dir, "test")
        FileUtils.mkdir(repo_assignment_test_dir)
        # Copy all non-private tests over
        assignment.test_files.find_all_by_filetype_and_is_private('test', 'false').each do |file|
          FileUtils.cp(File.join(assignment_test_dir, file.filename), repo_assignment_test_dir)
        end
      else
        if (File.exists?(File.join(assignment_dir, "test")))
          FileUtils.cp_r(File.join(assignment_dir, "test"), File.join(repo_assignment_dir, "test"))
        end
      end

      # Copy the lib folder
      if (File.exists?(File.join(assignment_dir, "lib")))
        FileUtils.cp_r(File.join(assignment_dir, "lib"), repo_assignment_dir)
      end

      # Copy the parse folder
      if (File.exists?(File.join(assignment_dir, "parse")))
        FileUtils.cp_r(File.join(assignment_dir, "parse"), repo_assignment_dir)
      end
    else
      raise I18n.t("automated_tests.dir_not_exist", {:dir => assignment_dir})
    end
  end

end
