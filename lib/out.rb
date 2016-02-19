#!/usr/bin/env ruby

class NotAGitRepository < Exception
end

# ResourceOut is a no-op
class ResourceOut
  include Utils

  def params
    @params ||= config.fetch 'params', {}
  end

  def context
    @context ||= params.fetch 'context', 'concourse'
  end

  def description
    @description ||= params.fetch 'description', ''
  end

  def state
    @state ||= params.fetch 'state'
  rescue KeyError
    puts 'Params is missing state'
    abort
  end

  def path
    @path ||= params.fetch 'path'
  rescue KeyError
    puts 'Params is missing path'
    abort
  end

  def source
    @source ||= config.fetch 'source', {}
  end

  def uri
    @uri ||= source.fetch 'uri'
  rescue KeyError
    puts 'Source is missing uri'
    abort
  end

  def repo
    @repo ||= get_repo_name uri
  end

  def base_url
    @base_url ||= ENV.fetch 'ATC_EXTERNAL_URL'
  rescue KeyError
    puts 'WTF? Environment is missing ATC_EXTERNAL_URL'
    abort
  end

  def build_id
    @build_id ||= ENV.fetch 'BUILD_ID'
  rescue KeyError
    puts 'WTF? Environment is missing BUILD_ID'
    abort
  end

  def target_url
    @target_url ||= "#{base_url}/builds/#{build_id}"
  end

  def options
    @options ||= {
      context: context,
      target_url: target_url,
      description: description
    }
  end

  def sha
    @sha ||= Dir.chdir path do
      `git rev-parse HEAD`.tap do |string|
        fail NotAGitRepository if string.empty?
      end
    end
  rescue NotAGitRepository
    puts "Either #{path} is not a git repository, or it has no HEAD."
    abort
  end

  def run
    client.create_status repo, sha, state, options
  end
end
