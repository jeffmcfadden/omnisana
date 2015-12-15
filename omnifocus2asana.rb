require './forgesana.rb'
require './settings.rb'

client = Forgesana::Client.new( api_key: ASANA_API_TOKEN )

def get_all_task_data_from_of
  script = %Q{
    tell application "OmniFocus"
    	tell default document
  		  set taskData to ""

    		tell first document window
    			set perspective name to "Asana Tasks"

    			set theTasks to tree of content
    			set oTrees to trees of content
    			set n to count of oTrees
    			repeat with i from 1 to count of oTrees
    				set t to value of (item i of oTrees)
  					set taskData to taskData & (due date of t as string) & "||" & (completed of t as string) & "||" & (note of t) & "$$"
    			end repeat
    		end tell
    		return taskData
    	end tell
    end tell
    }

  exists = %x{osascript -e '#{script}'}
end

data = get_all_task_data_from_of

# puts data

data.split( "$$" ).each do |record|
  fields = record.split( "||" )

  match = /Asana Task (\d+)/.match( fields.last )

  if match.nil?
  else
    id  = match[1]
  end

  completed = fields[1]

  if id.to_i != 0
    puts "Updating #{id}"
    task = Forgesana::Task.new( { id: id, completed: completed } )
    client.update_task( task )
  end

end
