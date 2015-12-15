require './forgesana.rb'
require './settings.rb'
require './omnifocus_applescripts.rb'
require 'cgi'





client = Omnisana::Client.new( api_key: ASANA_API_TOKEN )

me = client.me

puts "Me:\n#{me.id}"

SPECIAL_PROJECTS = ['5715300072433', '25678454709539', '10986453131606', '63225893447653', '5715300072419' ]

client.workspaces.each do |workspace|

  puts "#{workspace.name}"

  # next unless workspace.name == "gracechurchaz.org"

  workspace.projects.each do |project|

    # next unless project.name == "Sunday Production"

    next if project.archived?

    puts "\t#{project.id} :: #{project.name}"

    if project_exists_in_of( project )
      puts "\t\t Exists"
    else
      puts "\t\t Does Not Exist. Creating"
      create_project_in_of( project )
    end

    project.tasks.each do |task|
      if task.assignee == me || ( task.assignee.nil? && SPECIAL_PROJECTS.include?(project.id.to_s) )
        puts "\t\t#{task.completed? ? 'X' : ' '} #{task.id} :: #{task.section_and_name}"

        if task.completed?
          if nil != task.completed_at && Date.parse( task.completed_at ).to_time < (Time.now - 86400 * 60)
            puts "\t\t\t Task is more than 2 months old. Skipping"
            next
          end
        else
          puts "\t\t\t Is not yet complete. Re-Fetching details."
          task = client.task( id: task.id ) unless task.completed?
          task.project   = project
          task.workspace = workspace
        end

        if task_exists( task )
          puts "\t\t\t Exists. Updating."
          res = update_task( task )
          #print res
        else
          puts "\t\t\t Does not exist. Creating"
          res = create_task_in_of( task )
          #print res
        end
      else
        puts "\t\t Skipping Task #{task.id} - #{task.section_and_name}"
        # puts "\t\t-- Filtered Not Me --"
        # puts "\t\t   Assigned to: #{task.assignee}"
      end
    end
  end
end

result = %x{osascript -e 'display notification "Syncing complete" with title "Asana -> Omnifocus Complete"'}
