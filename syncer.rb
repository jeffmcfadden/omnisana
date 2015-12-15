require 'yaml'

module Omnisana
  class Syncer

    attr_accessor :debug
    attr_accessor :verbose
    attr_accessor :asana_api_key
    attr_accessor :sync_in
    attr_accessor :sync_out
    attr_accessor :config_file
    attr_accessor :client
    attr_accessor :special_projects

    def initialize( options: {} )
      # Defaults:
      self.verbose          = false
      self.debug            = false
      self.asana_api_key    = ''
      self.config_file      = ''
      self.sync_in          = false
      self.sync_out         = false
      self.special_projects = []

      self.debug            = options[:debug] if options[:debug].present?
      options[:verbose]     = true if self.debug

      self.config_file   = options[:config_file] if options[:config_file].present?

      if self.config_file.present?
        config_options = YAML.load_file( self.config_file ).symbolize_keys
        options = config_options.merge( options.to_h ){ |k, old, new| new.present? ? new : old }
      end

      puts options if self.debug

      self.verbose          = options[:verbose] if options[:verbose].present?
      self.asana_api_key    = options[:api_key] if options[:api_key].present?
      self.sync_in          = options[:sync_in] if options[:sync_in].present?
      self.sync_out         = options[:sync_out] if options[:sync_out].present?
      self.special_projects = options[:special_projects] if options[:special_projects].present?

      self.client = Omnisana::Client.new( api_key: self.asana_api_key )
    end

    def execute!
      puts "execute!"

      if self.sync_in
        sync_asana_to_omnifocus
      end

      if self.sync_out
        sync_omnifocus_to_asana
      end
    end

    def sync_asana_to_omnifocus
      if self.debug
        puts "sync_asana_to_omnifocus"
      end

      me = client.me

      puts "Me:\n#{me.id}" if self.debug

      client.workspaces.each do |workspace|

        puts "#{workspace.name}" if self.verbose
        workspace.projects.each do |project|
          next if project.archived?

          puts "\t#{project.id} :: #{project.name}"  if self.verbose

          if project_exists_in_of( project )
            puts "\t\t Exists"  if self.verbose
          else
            puts "\t\t Does Not Exist. Creating"  if self.verbose
            create_project_in_of( project )
          end

          project.tasks.each do |task|
            if task.assignee == me || ( task.assignee.nil? && self.special_projects.include?(project.id.to_s) )
              puts "\t\t#{task.completed? ? 'X' : ' '} #{task.id} :: #{task.section_and_name}"  if self.verbose

              if task.completed?
                if nil != task.completed_at && Date.parse( task.completed_at ).to_time < (Time.now - 86400 * 60)
                  puts "\t\t\t Task is more than 2 months old. Skipping"  if self.verbose
                  next
                end
              else
                puts "\t\t\t Is not yet complete. Re-Fetching details."  if self.verbose
                task = client.task( id: task.id ) unless task.completed?
                task.project   = project
                task.workspace = workspace
              end

              if task_exists( task )
                puts "\t\t\t Exists. Updating."  if self.verbose
                res = update_task( task )
                #print res
              else
                puts "\t\t\t Does not exist. Creating"  if self.verbose
                res = create_task_in_of( task )
                #print res
              end
            else
              puts "\t\t Skipping Task #{task.id} - #{task.section_and_name}"  if self.verbose
              # puts "\t\t-- Filtered Not Me --"
              # puts "\t\t   Assigned to: #{task.assignee}"
            end
          end
        end
      end
    end

    def sync_omnifocus_to_asana
      puts "sync_omnifocus_to_asana"
    end

  end
end