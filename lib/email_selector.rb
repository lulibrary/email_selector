require 'email_selector/version'

module EmailSelector
  # Selects the primary email address for a user based on rules read from a
  # configuration file
  class Selector
    # @!attribute [rw] config
    #   @return [Hash] the configuration parameter hash
    attr_accessor :config

    # @!attribute [rw] map
    #   @return [Hash<String, String>] a map of email addresses to the canonical
    #     (institutional) email address
    attr_accessor :store

    # Initialises a new EmailSelector instance
    # @param config [String] the configuration file name
    # @param map [String] the email address file name
    # @param store [Object] any hash-like object storing the mapping between
    #   primary and secondary emails
    # @return [void]
    def initialize(config: nil, map: nil, store: nil)
      self.store = store || {}
      load_config(config)
      load_map(map)
    end

    # Clears the email map
    # @return [void]
    def clear
      store.clear
    end

    # Returns the primary email address from a list of addresses based on the
    # configuration rules.
    # The email addresses are first matched as provided. If no matches are
    # found, the substitution rules from the configuration are applied and the
    # matching process is repeated on the substituted values. If no matches are
    # found after substitution, the first email in the list is returned.
    # @param emails [Array<String>] the list of email addresses
    # @param use_map [Boolean] if true, use the email map to resolve addresses
    # @return [String] the preferred email address
    def email(emails = nil, use_map: true)
      return nil if emails.nil? || emails.empty?
      # Check the emails as supplied
      result = map(emails, use_map) || domain(emails)
      return result unless result.nil?
      # Check the emails after substitutions.
      # Return the first email in the list if mo domain or map match is found.
      emails = substitutions(emails)
      map(emails, use_map) || domain(emails) || emails[0]
    end

    # Loads the configuration from the specified file
    # @param filename [String] the name of the configuration file
    # @return [void]
    def load_config(filename = nil)
      return if filename.nil? || filename.empty?
      self.config = { domain: [], sub: [] }
      File.foreach(filename) do |line|
        action, params = config_parse(line)
        if action == :domain
          config_domain(*params)
        elsif action == :substitution
          config_substitution(*params)
        end
      end
    end

    # Loads email mappings from the specified file
    # @param filename [String] the map file name
    # @return [void]
    def load_map(filename = nil)
      return if filename.nil? || filename.empty?
      delim = /\s*;\s*/
      File.foreach(filename) do |line|
        # Get the emails from the rule
        primary, emails = load_map_rule(line, delim)
        next if emails.nil?
        # Map all emails to the primary email
        emails.each { |e| store[e] = primary unless e == primary }
      end
    end

    # Returns the primary email and list of alternatives from the mapping file.
    # The file format is:
    #   primary, email1; email2; email3...
    # @param line [String] the mapping file rule
    # @param delim [Regexp, String] the delimiter for the list of emails
    # @return [String, Array<String>] the primary email and list of emails
    def load_map_rule(line, delim)
      # Strip redundant space
      line.strip!
      # Parse into primary and email list fields
      primary, _sep, emails = line.rpartition(',')
      return primary, nil if emails.nil? || emails.empty?
      # Split the email list on the delimiter
      emails = emails.split(delim)
      # Avoid mapping single email addresses to themselves
      return emails[0], nil if emails.length < 2
      # Get the primary (institutional) email if not present
      primary = email(emails, use_map: false) if primary.nil? || primary.empty?
      # Return the addresses
      [primary, emails]
    end

    # Writes the email map to the specified file
    # @param filename [String] the filename to write to
    # @return [void]
    def save_map(filename = nil)
      File.open(filename, 'w') do |file|
        store.each do |primary, emails|
          file.puts("#{primary},#{emails.join(';')}")
        end
      end
    end

    private

    # Adds a domain rule to the configuration
    # @param domain [String] the email domain
    # @return [void]
    def config_domain(domain, *_args)
      domain ||= ''
      domain.downcase!
      config[:domain].push(domain) unless domain.nil? || domain.empty?
    end

    # Parses a configuration file line
    def config_parse(line)
      line.strip!
      return nil if line.nil? || line.empty? || line[0] == '#'
      action, line = line.split(' ', 2)
      return :domain, [line] if action == 'domain'
      return :substitution, line.split(' ', 2) if action.start_with?('sub')
      nil
    end

    # Adds a substitution rule to the configuration
    # @param regexp [String] the regular expression to match
    # @param replacement [String] the replacement string
    # @return [void]
    def config_substitution(regexp, replacement = nil, *_args)
      return if regexp.nil? || regexp.empty?
      config[:sub].push([Regexp.new(regexp), replacement || ''])
    rescue ArgumentError, RegexpError
      nil
    end

    # Returns the first email address in the list with a domain matching one of
    # the preferred domains from the configuration. The preferred domains are
    # searched in the order they appear in the configuration file, so they
    # should appear in the file in order of preference.
    # @param emails [Array<String>] the list of email addresses
    # @return [String] the preferred email address
    def domain(emails)
      config[:domain].each do |domain|
        matches = emails.select { |email| email.end_with?(domain) }
        return matches[0] unless matches.empty?
      end
      nil
    end

    # Returns the canonical (institutional) email address for the first address
    # which exists in the email map
    # @param emails [Array<String>] the list of email addresses
    # @param use_map [Boolean] if true, use the email map, otherwise return nil
    # @return [String] the canonical email address
    def map(emails, use_map)
      return nil unless use_map
      emails.each do |e|
        result = store[e]
        return result unless result.nil? || result.empty?
      end
      nil
    end

    # Returns a copy of the email list parameter with substitutions applied to
    # each email
    # @param emails [Array<String>] the list of email addresses
    # @return [Array<String>] the list of modified email addresses
    def substitutions(emails)
      # Stop now if no substitutions are defined
      subs = config[:sub]
      return emails if subs.nil? || subs.empty?
      emails.map do |email|
        # Apply substitutions to and return a copy of the email
        email_sub = email.slice(0..-1)
        subs.each { |sub| email_sub.gsub!(sub[0], sub[1]) }
        email_sub
      end
    end
  end
end