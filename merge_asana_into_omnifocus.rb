#!/usr/bin/env ruby -E utf-8

# https://gist.github.com/jeffmcfadden/331a889a550e03605c22
# merge_asana_into_omnifocus.rb
# Hilton Lipschitz
# http://www.hiltmon.com
# Use and modify freely, attribution appreciated

# Script to import Asana projects and their tasks into
# OmniFocus and keep them up to date from Asana.

require "rubygems"
require "JSON"
require "date"
require "net/https"

class MergeAsanaIntoOmnifocus

  API_KEY      = '5WKFg5Q.hTRcYQyA2j6vDM4B2FT3KNgf' # Click on your Picture -> My Profile Settings -> Apps -> "API Key..."
  ASIGNEE_NAME = 'Jeff McFadden' # John Smith
  SUBTASKS = true

  def get_json_data(url_string)
    # set up HTTPS connection
    uri = URI.parse(url_string)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    # set up the request
    header = {
      "Content-Type" => "application/json"
    }

    req = Net::HTTP::Get.new(uri, header)
    req.basic_auth(API_KEY, '')

    # issue the request
    res = http.start { |http| http.request(req) }

    # Parse the result
    body = JSON.parse(res.body)

    if body['errors'] then
      puts "Server returned an error: #{body['errors'][0]['message']}"
      return nil
    end

    body
  end

  # -----------------------------------------------------------------------
  # ASANA API Calls
  # -----------------------------------------------------------------------

  def get_projects
    body = get_json_data("https://app.asana.com/api/1.0/projects")
    projects = {}
    body["data"].each do |element|
      projects[element["id"]] = element["name"].gsub("'", '').gsub("\n", '')
    end

    projects
  end

  # NOTE: Assignee = me is ignored in projects filter
  def get_tasks_in_project(project_id)
    body = get_json_data("https://app.asana.com/api/1.0/tasks?project=#{project_id}&assignee=me")
    tasks = {}
    body["data"].each do |element|
      tasks[element["id"]] = element["name"].gsub("'", '').gsub("\n", '')
    end

    tasks
  end

  def get_subtasks_in_task(task_id)
    body = get_json_data("https://app.asana.com/api/1.0/tasks/#{task_id}/subtasks")
    body["data"]
  end

  def get_project_detail(project_id)
    body = get_json_data("https://app.asana.com/api/1.0/projects/#{project_id}")
    body["data"]
  end

  def get_task_detail(task_id)
    body = get_json_data("https://app.asana.com/api/1.0/tasks/#{task_id}")
    body["data"]
  end

  # -----------------------------------------------------------------------
  # AppleScripts
  # -----------------------------------------------------------------------

  def project_exists_osascript(project_name)
    %Q{
      tell application "OmniFocus"
      	tell front document
      		set myFolder to folder "Asana"
      		try
      			set myProject to project "#{project_name}" in folder "Asana"
      		on error
      			-- Project is Missing, return failure code
      			return "Missing"
      		end try
      		return "Found"
      	end tell
      end tell
    }
  end

  # Note the hack to escape the single quote in Applescript's
  def my_tasks_osascript(project_name)
    %Q{
      tell application "OmniFocus"
      	tell front document
      		set myFolder to folder "Asana"

      		set myProject to project "#{project_name}" in folder "Asana"
      		set myRowNames to name of every task of myProject
      		set AppleScript'"'"'s text item delimiters to "|"
      		set retVal to myRowNames as string
      		return retVal
      	end tell
      end tell
    }
  end

  def project_osascript(project_name)
    %Q{
      tell application "OmniFocus"
      	tell front document
      		set myFolder to folder "Asana"
      		try
      			set myProject to project "#{project_name}" in folder "Asana"
      		on error
      			-- Project is Missing, create it
      			set myProject to make new project with properties {name: "#{project_name}"} at end of projects of myFolder
      		end try
      	end tell
      end tell
    }
  end

  def project_task_osascript(project_name, task_name, note, completed, due_date, context)
    if due_date.nil?
      due_date_str = '"none"'
    else
      due_date = Date.parse(due_date).strftime('%A %B %d, %Y at %H:%M:%S')
      due_date_str = "date \"#{due_date}\""
    end
    completed_str = (completed ? 'true' : 'false')
    %Q{
      tell application "OmniFocus"
      	tell front document
      		set myFolder to folder "Asana"
      		set myProject to project "#{project_name}" in folder "Asana"
      		set isCompleted to #{completed_str}
      		set dueDate to #{due_date_str}
      		set newContext to "#{context}"

      		if (newContext ≠ "none") then
      			set parentContext to context "People"
      			try
      				set myContext to first flattened context whose name is newContext
      			on error
      				-- Context is Missing, create it
      				tell parentContext
      					set myContext to make new context with properties {name:newContext}
      				end tell
      			end try
      		end if

      		try
      			set myTask to task "#{task_name}" in myProject
      		on error
      			-- Task is Missing, create it unless completed?
      			if (isCompleted = false) then
      				set myTask to make new task with properties {name:"#{task_name}"} at end of tasks of myProject
      			end if
      		end try

      		-- At this point, myTask exists if not completed
      		-- Since AppleScript has no test of undefined, wrap the next block

      		try
        		if (isCompleted = true) then
        			-- if it exists and is completed
        			tell myTask
        				set its completed to true
        			end tell
        		else
        			-- Update its notes and dates
        			tell myTask
        				set its note to "#{note}"
        				if (newContext ≠ "none") then
        					set its context to myContext
        				end if
        				if (dueDate ≠ "none") then
        					set its due date to dueDate
        				end if
        			end tell
        		end if
      		on error
      			-- No, just the task is complete, no clutter in OmniFocus
      		end try

      	end tell
      end tell
    }
  end

  def my_task_complete_osascript(project_name, task_name)
    %Q{
      tell application "OmniFocus"
      	tell front document
      		set myFolder to folder "Asana"
      		set myProject to project "#{project_name}" in folder "Asana"
      		set isCompleted to true

      		try
      			set myTask to task "#{task_name}" in myProject
      			tell myTask
      				set its completed to true
      			end tell
      		on error
      			-- Task is Missing, ignore it
      		end try
      	end tell
      end tell
    }
  end

  # Note the hack to escape the single quote in Applescript's
  def my_subtasks_osascript(project_name, parent_task_name)
    %Q{
      tell application "OmniFocus"
      	tell front document
      		set myFolder to folder "Asana"

      		set parentTask to task "#{parent_task_name}" in project "#{project_name}" in folder "Asana"
      		set myRowNames to name of every task of parentTask
      		set AppleScript'"'"'s text item delimiters to "|"
      		set retVal to myRowNames as string
      		return retVal
      	end tell
      end tell
    }
  end

  def project_sub_task_osascript(project_name, parent_task_name, task_name, note, completed, due_date, context)
    if due_date.nil?
      due_date_str = '"none"'
    else
      due_date = Date.parse(due_date).strftime('%A %B %d, %Y at %H:%M:%S')
      due_date_str = "date \"#{due_date}\""
    end
    completed_str = (completed ? 'true' : 'false')
    %Q{
      tell application "OmniFocus"
      	tell front document
      		set myFolder to folder "Asana"
      		set parentTask to task "#{parent_task_name}" in project "#{project_name}" in folder "Asana"
      		set isCompleted to #{completed_str}
      		set dueDate to #{due_date_str}
          set newContext to "#{context}"

      		if (newContext ≠ "none") then
      			set parentContext to context "People"
      			try
      				set myContext to first flattened context whose name is newContext
      			on error
      				-- Context is Missing, create it
      				tell parentContext
      					set myContext to make new context with properties {name:newContext}
      				end tell
      			end try
      		end if

      		try
      			set myTask to task "#{task_name}" in parentTask
      		on error
      			-- Task is Missing, create it unless completed?
      			if (isCompleted = false) then
      				set myTask to make new task with properties {name:"#{task_name}"} at end of tasks of parentTask
      			end if
      		end try

      		-- At this point, myTask exists if not completed
      		-- Since AppleScript has no test of undefined, wrap the next block

      		try
        		if (isCompleted = true) then
        			-- if it exists and is completed
        			tell myTask
        				set its completed to true
        			end tell
        		else
        			-- Update its notes and dates
        			tell myTask
        				set its note to "#{note}"
        				if (newContext ≠ "none") then
        					set its context to myContext
        				end if
        				if (dueDate ≠ "none") then
        					set its due date to dueDate
        				end if
        			end tell
        		end if
      		on error
      			-- No, just the task is complete, no clutter in OmniFocus
      		end try

      	end tell
      end tell
    }
  end

  def my_sub_task_complete_osascript(project_name, parent_task_name, sub_task_name)
    %Q{
      tell application "OmniFocus"
      	tell front document
      		set myFolder to folder "Asana"
      		set parentTask to task "#{parent_task_name}" in project "#{project_name}" in folder "Asana"
      		set isCompleted to true

      		try
      			set myTask to task "#{sub_task_name}" in parentTask
      			tell myTask
      				set its completed to true
      			end tell
      		on error
      			-- Task is Missing, ignore it
      		end try
      	end tell
      end tell
    }
  end

  # -----------------------------------------------------------------------
  # MAIN LOOP
  # -----------------------------------------------------------------------

  def run
    projects = get_projects
    projects.each_pair do |project_id, project_name|
      detail = get_project_detail(project_id)

      # Skip archived projects if not in Omnifocus
      if detail['archived'] == true
        result = %x{osascript -e '#{project_exists_osascript(project_name)}'}
        # puts "#{project_name}: [#{result}]"
        if result.rstrip == 'Missing'
          puts "Skipping Archived Project: #{project_name}..."
          next
        end
      end

      # Create or update the project in OmniFocus using AppleScript
      %x{osascript -e '#{project_osascript(project_name)}'}

      # Project / Tasks
      puts "Tasks for #{project_name}..."
      tasks = get_tasks_in_project(project_id)

      # Get my known tasks
      result = %x{osascript -e '#{my_tasks_osascript(project_name)}'}
      my_known_tasks = result.strip.split('|')

      tasks.each_pair do |task_id, task_name|
        next if task_name == "" # We seem to have these!
        detail = get_task_detail(task_id)
        # puts detail if project_name == 'Single cusip view'

        # Create or update a task in a project
        notes = detail['notes'].gsub("'", '').gsub('"', '').gsub('`', '').gsub("\n", '')
        task_name = task_name.gsub("'", '').gsub('"', '').gsub('`', '').gsub("\n", '')

        context = 'none'
        unless detail['assignee'].nil?
          if detail['assignee']['name'] != ASIGNEE_NAME
            context = detail['assignee']['name']
          end
        end

        %x{osascript -e '#{project_task_osascript(project_name, task_name, notes, detail['completed'], detail['due_on'], context)}'}

        # Remove from my known as we see it in Asana
        # puts "///DEL/// [#{task_name}]"
        my_known_tasks.delete(task_name)

        next if detail['completed'] == true # Ignore subtasks

        if SUBTASKS == true
          # Project / Task / SubTask
          puts "  Subtasks for #{task_name}..."
          subtasks = get_subtasks_in_task(task_id)

          # Get my known sub-tasks
          result = %x{osascript -e '#{my_subtasks_osascript(project_name, task_name)}'}
          my_known_sub_tasks = result.strip.split('|')

          if subtasks.length > 0
            subtasks.each do |sub_task|
              next if sub_task["name"] == ""
              sub_detail = get_task_detail(sub_task["id"])

              sub_context = context
              unless detail['assignee'].nil?
                if detail['assignee']['name'] != ASIGNEE_NAME
                  sub_context = detail['assignee']['name']
                end
              end

              # Create or update a subtask in Omnifocus
              sub_notes = sub_detail['notes'].gsub("'", '').gsub('"', '').gsub('`', '').gsub("\n", '')
              sub_task_name = sub_task['name'].gsub("'", '').gsub('"', '').gsub('`', '').gsub("\n", '')
              %x{osascript -e '#{project_sub_task_osascript(project_name, task_name, sub_task_name, sub_notes, sub_detail['completed'], sub_detail['due_on'], sub_context)}'}

              # Remove from my known as we see it in Asana
              # puts "///DEL/// #{task_name}"
              my_known_sub_tasks.delete(sub_task_name)
            end
          end

          my_known_sub_tasks.each do |sub_task_name|
            sub_task_name.strip!
            next if sub_task_name == "" # We seem to have these!
            puts "Missing: #{sub_task_name} under #{task_name} // Marked as completed"
            %x{osascript -e '#{my_sub_task_complete_osascript(project_name, task_name, sub_task_name)}'}
          end

        end
      end

      my_known_tasks.each do |task_name|
        task_name.strip!
        next if task_name == "" # We seem to have these!
        puts "Missing: #{task_name} // Marked as completed"
        %x{osascript -e '#{my_task_complete_osascript(project_name, task_name)}'}
      end
    end
  end

  def test
    project_name = 'Single cusip view'
    result = %x{osascript -e '#{my_tasks_osascript(project_name)}'}
    puts result.split('|')
  end

end

app = MergeAsanaIntoOmnifocus.new()
app.run()
# app.test()
