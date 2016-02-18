require 'net/http'
require 'json'
require 'date'
require 'time'

module Omnisana

  class Client

    attr_accessor :api_key

    def initialize( api_key: "" )
      puts "API Key: #{api_key}"

      self.api_key = api_key
    end

    def query_api( uri )
      uri = URI('https://app.asana.com/api/1.0' + uri)

      # puts "query_api #{uri}"

      req = Net::HTTP::Get.new(uri)
      req.basic_auth self.api_key, ''

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true ) {|http|
        http.request(req)
      }

      res.body
    end

    def workspaces
      data = JSON.parse( self.query_api( '/workspaces' ) )
      workspaces = []
      data['data'].each do |ws_json_data|
        workspaces.push( Workspace.new( ws_json_data, client: self ) )
      end

      workspaces
    end

    def me
      data = JSON.parse( self.query_api( '/users/me' ) )

      User.new(data['data'], client: self)
    end

    def tasks( workspace: nil, assignee: nil, project: nil, modified_since: nil )
      qs = "?1=1"

      if modified_since.nil?
        qs += "&modified_since=#{(Time.now-86400).utc.iso8601}"
      else
        qs += "&modified_since=#{modified_since.utc.iso8601}"
      end

      qs += "&workspace=#{workspace.id}" unless workspace.nil?
      qs += "&assignee=#{assignee.id}" unless assignee.nil?
      qs += "&project=#{project.id}" unless project.nil?
      qs += "&opt_fields=assignee,created_at,completed,completed_at,due_on,due_at,name,notes,memberships"

      data = JSON.parse( self.query_api( '/tasks' + qs ) )

      #puts "JSON Data: #{data}"

      tasks = []
      data['data'].each do |task_json_data|

        if task_json_data['assignee'] != nil
          task_json_data['assignee'] = User.new( task_json_data['assignee'] )
        end

        if project != nil
          task_json_data['project'] = project
        end

        task_json_data['name'] = task_json_data['name'].gsub( "'", "" )

        tasks.push( Task.new( task_json_data, client: self ) )
      end

      tasks
    end

    def task( id: "" )
      data = JSON.parse( self.query_api( "/tasks/#{id}" ) )

      #puts "Data: #{data}"

      task_json_data = data['data']
      task_json_data['name'] = task_json_data['name'].gsub( "'", "" )
      Task.new( task_json_data, client: self )
    end

    def update_task( task )
      uri = URI("https://app.asana.com/api/1.0/tasks/#{task.id}")

      req = Net::HTTP::Put.new(uri)
      req.basic_auth self.api_key, ''

      post_data = { completed: (task.completed ? "true" : "false") }

      if task.completed
        print "  X"
      end

      if task.due_date.present?
        post_data[:due_at] = task.due_date.utc.iso8601
      end

      req.set_form_data( post_data )

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true ) {|http|
        http.request(req)
      }

      # puts res.body

      res.body
    end

    def projects( workspace: nil )
      qs = "?1=1"

      qs += "&workspace=#{workspace.id}" unless workspace.nil?
      qs += "&opt_fields=name,archived,created_at,notes"

      data = JSON.parse( self.query_api( '/projects' + qs ) )

      projects = []
      data['data'].each do |project_json_data|

        if workspace != nil
          project_json_data['workspace'] = workspace
        else
          project_json_data['workspace'] = Workspace.new( { 'id' => project_json_data['workspace'] } )
        end

        project_json_data['name'] = project_json_data['name'].gsub( "'", "" )
        projects.push( Project.new( project_json_data, client: self ) )
      end

      projects
    end


  end

  class User
    attr_accessor :client

    attr_accessor :id
    attr_accessor :name
    attr_accessor :email

    def initialize(params, client: nil)
      params.each do |k,v|
        if self.respond_to?( "#{k}=".to_sym )
          self.send( "#{k}=".to_sym, v )
        end
      end

      self.client = client
    end

    def ==(u)
      puts "u: #{u}, self: #{self}"

      u.id.to_s == self.id.to_s
    end
  end

  class Workspace
    attr_accessor :client

    attr_accessor :id
    attr_accessor :name
    attr_accessor :tasks
    attr_accessor :projects

    def initialize( params, client: nil )
      params.each do |k,v|
        if self.respond_to?( "#{k}=".to_sym )
          self.send( "#{k}=".to_sym, v )
        end
      end

      self.client = client
    end

    def tasks( assignee: nil, project: nil )
      self.tasks = self.client.tasks( workspace: self, assignee: assignee, project: project )
    end

    def projects
      self.projects = self.client.projects( workspace: self )
    end
  end

  class Task
    attr_accessor :client

    attr_accessor :id
    attr_accessor :assignee
    attr_accessor :created_at
    attr_accessor :completed
    attr_accessor :completed_at
    attr_accessor :due_on
    attr_accessor :due_at
    attr_accessor :name
    attr_accessor :notes
    attr_accessor :memberships

    attr_accessor :project
    attr_accessor :workspace

    def initialize( params, client: nil )
      params.each do |k,v|
        if self.respond_to?( "#{k}=".to_sym )

          if v.class == String
            if v === "false"
              v = false
            elsif v === "true"
              v = true
            end
          end

          self.send( "#{k}=".to_sym, v )
        end
      end

      self.client = client
    end

    def section_names
      self.memberships.each do |m|
        if m['section'] != nil
          return m['section']['name']
        end
      end

      nil
    end

    def section_and_name
      if self.section_names != nil
        "#{self.section_names}: #{self.name}"
      else
        self.name
      end
    end

    def completed?
      !!completed
    end

    def due_date
      if self.due_on != nil && self.due_on != ""
        return Date.parse( self.due_on ).to_time rescue nil
      elsif self.due_at != nil && self.due_at != ""
        return Date.parse( self.due_at ).to_time rescue nil
      else
        return nil
      end
    end
  end

  class Project
    attr_accessor :client

    attr_accessor :id
    attr_accessor :archived
    attr_accessor :created_at
    attr_accessor :name
    attr_accessor :notes
    attr_accessor :workspace
    attr_accessor :tasks

    def initialize( params, client: nil )
      params.each do |k,v|
        if self.respond_to?( "#{k}=".to_sym )
          self.send( "#{k}=".to_sym, v )
        end
      end

      self.client = client
    end

    def archived?
      !!archived
    end

    def tasks( assignee: nil )
      self.tasks = self.client.tasks( workspace: self.workspace, assignee: assignee, project: self )
    end
  end

end