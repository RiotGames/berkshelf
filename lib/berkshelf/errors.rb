module Berkshelf
  class BerkshelfError < StandardError
    class << self
      # @param [Integer] code
      def status_code(code)
        define_method(:status_code) { code }
        define_singleton_method(:status_code) { code }
      end
    end

    alias_method :message, :to_s
  end

  class InternalError < BerkshelfError; status_code(99); end
  class ArgumentError < InternalError; end
  class AbstractFunction < InternalError
    def to_s
      "Function must be implemented on includer"
    end
  end

  class BerksfileNotFound < BerkshelfError; status_code(100); end
  class NoVersionForConstraints < BerkshelfError; status_code(101); end
  class DuplicateLocationDefined < BerkshelfError; status_code(102); end
  class CookbookNotFound < BerkshelfError; status_code(103); end
  class GitError < BerkshelfError
    status_code(104)
    attr_reader :stderr

    def initialize(stderr)
      @stderr = stderr
    end

    def to_s
      out = "An error occured during Git execution:\n"
      out << stderr.prepend_each("\n", "\t")
    end
  end
  class PrivateGitRepo < GitError; end
  class AmbiguousGitRef < GitError
    attr_reader :ref

    def initialize(ref)
      @ref = ref
    end

    def to_s
      out = "An error occurred during Git execution:\n"
      out << "Ambiguous Git ref: #{ref}"
    end
  end
  class InvalidGitRef < GitError
    attr_reader :ref

    def initialize(ref)
      @ref = ref
    end

    def to_s
      out = "An error occurred during Git execution:\n"
      out << "Invalid Git ref: #{ref}"
    end
  end

  class DuplicateSourceDefined < BerkshelfError; status_code(105); end
  class NoSolution < BerkshelfError; status_code(106); end
  class CookbookSyntaxError < BerkshelfError; status_code(107); end
  class BerksConfigNotFound < BerkshelfError; status_code(109); end

  class InvalidGitURI < BerkshelfError
    status_code(110)
    attr_reader :uri

    # @param [String] uri
    def initialize(uri)
      @uri = uri
    end

    def to_s
      "'#{uri}' is not a valid Git URI."
    end
  end

  class UnknownGitHubProtocol < BerkshelfError
    status_code(110)
    attr_reader :protocol

    # @param [String] protocol
    def initialize(protocol)
      @protocol = protocol
    end

    def to_s
      "'#{self.protocol}' is not a supported Git protocol for the 'github' location key. Please use 'git' instead."
    end
  end

  class GitNotFound < BerkshelfError
    status_code(110)

    def to_s
      "Could not find a Git executable in your path. Please add it and try again."
    end
  end

  class ConstraintNotSatisfied < BerkshelfError; status_code(111); end
  class InvalidChefAPILocation < BerkshelfError; status_code(112); end
  class BerksfileReadError < BerkshelfError
    def initialize(original_error)
      @original_error = original_error
    end

    status_code(113)

    def status_code
      @original_error.respond_to?(:status_code) ? @original_error.status_code : 113
    end
  end

  class AmbiguousCookbookName < BerkshelfError; status_code(114); end

  class InvalidConfiguration < BerkshelfError
    status_code(115)

    def initialize(errors)
      @errors = errors
    end

    def to_s
      strings = ["Invalid configuration:"]

      @errors.each do |key, errors|
        errors.each do |error|
          strings << "  #{key} #{error}"
        end
      end

      strings.join "\n"
    end
  end

  class ConfigExists < BerkshelfError; status_code(116); end
  class ConfigurationError < BerkshelfError; status_code(117); end
  class CommandUnsuccessful < BerkshelfError; status_code(118); end
  class InsufficientPrivledges < BerkshelfError; status_code(119); end
  class ExplicitCookbookNotFound < BerkshelfError; status_code(120); end
  class ValidationFailed < BerkshelfError; status_code(121); end
  class InvalidVersionConstraint < BerkshelfError; status_code(122); end
  class CommunitySiteError < BerkshelfError; status_code(123); end
  class CookbookValidationFailure < BerkshelfError; status_code(124); end
  class ClientKeyFileNotFound < BerkshelfError; status_code(125); end

  class UploadFailure < BerkshelfError; end
  class FrozenCookbook < UploadFailure; status_code(126); end
  class InvalidSiteShortnameError < BerkshelfError
    status_code(127)

    def initialize(shortname)
      @shortname = shortname
    end

    def to_s
      "Unknown site shortname: #{@shortname.inspect}. Supported shortnames are: #{SiteLocation::SHORTNAMES.keys.map(&:inspect).join(',')}"
    end
  end

  class OutdatedCookbookSource < BerkshelfError
    status_code(128)

    # @return [Berkshelf::CookbookSource]
    attr_reader :locked_source, :source

    # @param [Berkshelf::CookbookSource] source
    #   the cookbook source that is outdated
    def initialize(locked_source, source)
      @locked_source = locked_source
      @source = source
    end

    def to_s
      [
        "Berkshelf could not find compatible versions for cookbook '#{source.name}':",
        "  In Berksfile:",
        "    #{locked_source.name} (#{locked_source.locked_version})",
        "",
        "  In Berksfile.lock:",
        "    #{source.name} (#{source.version_constraint})",
        "",
        "Try running `berks update #{source.name}, which will try to find  '#{source.name}' matching '#{source.version_constraint}'."
      ].join("\n")
    end
  end

  class EnvironmentNotFound < BerkshelfError
    status_code(129)

    def initialize(environment_name)
      @environment_name = environment_name
    end

    def to_s
      %Q[The environment "#{@environment_name}" does not exist.]
    end
  end

  class ChefConnectionError < BerkshelfError
    status_code(130)

    def to_s
      "There was an error connecting to the chef server."
    end
  end

  # @author Seth Vargo <sethvargo@gmail.com>
  class UnknownCompressionType < BerkshelfError
    status_code(131)

    def initialize(destination)
      @destination = destination
    end

    def to_s
      "The file at '#{@destination}' is not a known compression type!"
    end
  end

  # @author Seth Vargo <sethvargo@gmail.com>
  #
  # Raised when a cookbook or its recipes contain a space or invalid
  # character in the path.
  #
  # @param [Berkshelf::CachedCookbook] cookbook
  #   the cookbook that failed validation
  # @param [Array<#to_s>] files
  #   the list of files that were not valid
  class InvalidCookbookFiles < BerkshelfError
    status_code(132)

    def initialize(cookbook, files)
      @cookbook = cookbook
      @files = files
    end

    def to_s
      [
        "The cookbook '#{@cookbook.cookbook_name}' has invalid filenames:",
        "",
        "  " + @files.map(&:to_s).join("\n  "),
        "",
        "Please note, spaces are not a valid character in filenames."
      ].join("\n")
    end
  end
end
