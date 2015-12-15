module Omnisana
  class Syncer

    attr_accessor :debug
    attr_accessor :verbose
    attr_accessor :asana_api_key
    attr_accessor :sync_in
    attr_accessor :sync_out
    attr_accessor :config_file
    attr_accessor :client

    def initialize( options: {} )
      # Defaults:
      self.verbose       = false
      self.debug         = false
      self.asana_api_key = ''
      self.config_file   = ''
      self.sync_in       = false
      self.sync_out      = false

      if self.config_file.present?
        puts "TODO: implement config file"

        options = YAML.load_file( self.config_file ).symbolize_keys
      end

      self.verbose       = options[:verbose] if options[:verbose].present?
      self.debug         = options[:debug] if options[:debug].present?
      self.asana_api_key = options[:asana_api_key] if options[:asana_api_key].present?
      self.sync_in       = options[:sync_in] if options[:sync_in].present?
      self.sync_out      = options[:sync_out] if options[:sync_out].present?

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
      puts "sync_asana_to_omnifocus"
    end

    def sync_omnifocus_to_asana
      puts "sync_omnifocus_to_asana"
    end

  end
end