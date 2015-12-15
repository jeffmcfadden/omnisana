# Get all the tasks from a custom perspective
# tell application "OmniFocus"
#   tell default document
#     tell first document window
#       set perspective name to "Asana Tasks"
#
#       set theTasks to tree of content
#       set taskData to ""
#
#
#       set oTrees to trees of content
#       set n to count of oTrees
#       repeat with i from 1 to count of oTrees
#         set t to value of (item i of oTrees)
#         set taskData to taskData & (due date of t as string) & "||" & (completed of t as string) & "||" & (note of t) & "$$"
#       end repeat
#
#       return taskData
#     end tell
#   end tell
# end tell




# def workspace_exists ( workspace )
#   script = %Q{
#     tell application "OmniFocus"
#       tell front document
#         try
#           set myFolder to folder "#{workspace.name}" in folder "Asana"
#         on error
#           set myFolder to false
#         end try
#       end tell
#     end tell
#     }
#
#   exists = %x{osascript -e '#{script}'}.strip != 'false'
# end
#
# def create_workspace( workspace )
#   puts "create_workspace #{workspace.name}"
#
#   script = %Q{
#     tell application "OmniFocus"
#       tell front document
#         make new folder with properties { name: "#{workspace.name}" } in folder "Asana"
#       end tell
#     end tell
#   }
#
#   result = %x{osascript -e '#{script}'}.strip
#
#   puts "\t#{result}"
#
#   result
# end

def project_exists_in_of(project)
  script = %Q{
    tell application "OmniFocus"
      tell front document
    		set myFolder to folder "#{project.workspace.name}" in folder "Asana"

        set myProject to ""

    		repeat with p in projects of myFolder
    			if note of p contains "Asana Project #{project.id}" then
    				set myProject to id of p
    			end if
    		end repeat

        return myProject
      end tell
    end tell
    }

  exists = %x{osascript -e '#{script}'}

  # puts "response: #{exists}"

  exists.strip.length > 0
end

def create_project_in_of(project)
  script = %Q{
    tell application "OmniFocus"
      tell front document
    		set myFolder to folder "#{project.workspace.name}" in folder "Asana"

  			set myProject to make new project with properties {name: "#{project.name}", note: "Asana Project #{project.id}\n\n#{project.notes}"} at end of projects of myFolder

      end tell
    end tell
    }

  result = %x{osascript -e '#{script}'}
end

def task_exists_in_of(task)
  script = %Q{
    tell application "OmniFocus"
      tell front document
    		set myFolder to folder "#{task.project.workspace.name}" in folder "Asana"

    		repeat with p in projects of myFolder
    			if note of p contains "Asana Project #{task.project.id}" then
    				set myProject to p
    			end if
    		end repeat

        set myTask to ""

        repeat with t in tasks of myProject
    			if note of t contains "Asana Task #{task.id}" then
    				set myTask to t
    			end if
        end repeat

        return myTask
      end tell
    end tell
    }

  exists = %x{osascript -e '#{script}'}.strip.length > 0
end

# This checks my custom perspective to see if the task exists at all, anywhere.
def task_exists(task)
  script = %Q{
    tell application "OmniFocus"
    	tell default document
    		tell first document window
    			set perspective name to "Asana Tasks"

    			set theTasks to tree of content
    			set myTask to ""


    			set oTrees to trees of content
    			set n to count of oTrees
    			repeat with i from 1 to count of oTrees
    				set t to value of (item i of oTrees)
    				if note of t contains "Asana Task #{task.id}" then
    					set myTask to t
    				end if
    			end repeat

    			return myTask
    		end tell
    	end tell
    end tell
  }

  exists = %x{osascript -e '#{script}'}.strip.length > 0
end

def create_task_in_of( task )
  if task.due_date.nil?
    due_date_str = 'missing value'
  else
    due_date_str = task.due_date.strftime('%A %B %d, %Y at %H:%M:%S')
    due_date_str = "date \"#{due_date_str}\""
  end

  script = %Q{
    tell application "OmniFocus"
      tell front document
    		set myFolder to folder "#{task.project.workspace.name}" in folder "Asana"

    		repeat with p in projects of myFolder
    			if note of p contains "Asana Project #{task.project.id}" then
    				set myProject to p
    			end if
    		end repeat

  			set myTask to make new task with properties {name: "#{task.section_and_name.gsub( "\"", "" )}", note: "Asana Task #{task.id}\n\n#{CGI::escape(task.notes)}", completed: #{task.completed? ? 'true' : 'false'}, due date: #{due_date_str} } at end of tasks of myProject

      end tell
    end tell
    }

  result = %x{osascript -e '#{script}'}
end

def update_task_in_of( task )

  if task.due_date.nil?
    due_date_str = 'missing value'
  else
    due_date_str = task.due_date.strftime('%A %B %d, %Y at %H:%M:%S')
    due_date_str = "date \"#{due_date_str}\""
  end


  script = %Q{
    tell application "OmniFocus"
      tell front document
    		set myFolder to folder "#{task.project.workspace.name}" in folder "Asana"

    		repeat with p in projects of myFolder
    			if note of p contains "Asana Project #{task.project.id}" then
    				set myProject to p
    			end if
    		end repeat

        repeat with t in tasks of myProject
    			if note of t contains "Asana Task #{task.id}" then
    				set myTask to t

      			tell myTask
      				set its completed to #{task.completed?}
              set its name to "#{task.section_and_name.gsub( "\"", "" )}"
              set its note to "Asana Task #{task.id}\n\n#{CGI::escape(task.notes)}"
              set its due date to #{due_date_str}
      			end tell
    			end if
        end repeat

        return myTask
      end tell
    end tell
    }

  result = %x{osascript -e '#{script}'}
end

# This one doesn't touch my projects or anything.
def update_task(task)

  if task.due_date.nil?
    due_date_str = 'missing value'
  else
    due_date_str = task.due_date.strftime('%A %B %d, %Y at %H:%M:%S')
    due_date_str = "date \"#{due_date_str}\""
  end


  script = %Q{
    tell application "OmniFocus"
    	tell default document
    		tell first document window
    			set perspective name to "Asana Tasks"

    			set theTasks to tree of content
    			set myTask to ""


    			set oTrees to trees of content
    			set n to count of oTrees
    			repeat with i from 1 to count of oTrees
    				set t to value of (item i of oTrees)
      			if note of t contains "Asana Task #{task.id}" then
      				set myTask to t

        			tell myTask
        				set its completed to #{task.completed?}
                set its name to "#{task.section_and_name.gsub( "\"", "" )}"
                set its note to "Asana Task #{task.id}\n\n#{CGI::escape(task.notes)}"
                set its due date to #{due_date_str}
        			end tell
      			end if
    			end repeat

    			return myTask
    		end tell
    	end tell
    end tell
    }

  result = %x{osascript -e '#{script}'}
end