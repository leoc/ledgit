class Ledgit
  module Handler
    class << self

      ##
      # This list contains the handler modules for each supported
      # banking website.
      def list
        @list ||= {}
      end

      ##
      # Retrieve an array of handlers for a specific account handler.
      def modules_for key
        mod = list[key]
        raise "no such handler for '#{key}'" unless mod
        mod = [ mod ] unless mod.is_a?(Array)
        mod
      end

    end
  end
end

Dir["#{File.dirname(__FILE__)}/handler/**/*.rb"].each { |file| require(file) }
