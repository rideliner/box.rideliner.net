#!/usr/bin/env ruby

require 'yaml'

class MetaDataAccessor
  def initialize(file)
    @filename = file
  end

  def stat
    @stat ||= File.stat(@filename)
  end

  def file
    @file ||= File.new(@filename)
  end

  def get(meta)
    case meta
    when :mtime
      stat.mtime.utc
    when :atime
      stat.atime.utc
    when :mode
      stat.mode
    when :uid
      stat.uid
    when :gid
      stat.gid
    end
  end

  def set(meta, value)
    case meta
    when :mtime
      file.utime(nil, value)
    when :atime
      file.utime(value, nil)
    when :mode
      file.chmod(value)
    when :uid
      file.chown(value, nil)
    when :gid
      file.chown(nil, value)
    end
  end

  def to_metadata(fields)
    fields
      .map { |field| [field, get(field)] }
      .to_h
  end
end

class GitMetaStore
  CONFIG_FILE = File.join(__dir__, 'git-meta.config.yml')
  STORE_FILE = File.join(__dir__, 'git-meta.store.yml')
  META_DATA_FIELDS = %w[mtime atime mode uid gid]

  def self.load_file(file)
    File.exist?(file) && YAML.load_file(file) || {}
  end

  def initialize
    @config = self.class.load_file(CONFIG_FILE)
    default_config_options
    @store = self.class.load_file(STORE_FILE)

    @metadata = (@config['fields'] & META_DATA_FIELDS).map(&:to_sym)
  end

  def default_config_options
    @config['fields'] = META_DATA_FIELDS unless @config.key?('fields')
    @config['exclude'] = [] unless @config.key?('exclude')
  end

  def store
    files = get_files

    @store.select! { |f| files.include?(f) }

    data = files
      .map do |file|
        [file, MetaDataAccessor.new(file).to_metadata(@config['fields'])]
      end
      .to_h

    modified = get_modified_files

    data.each do |(file, metadata)|
      if modified.include?(file) || !@store.key?(file)
        @store[file] = metadata
      end
    end

    @store.select! { |f| files.include?(f) && !excluded?(f) }

    File.write(STORE_FILE, @store.to_yaml)
  end

  def apply
    @store.each do |file, data|
      metadata = MetaDataAccessor.new(file)
      data.each do |field, value|
        metadata.set(field, value)
      end
    end
  end

  def get_files
    `git ls-files -z`.split("\0")
  end

  def get_modified_files
    `git diff --cached --name-only -z`.split("\0")
  end

  def excluded?(file)
    @config['exclude'].any? do |glob|
      File.fnmatch(glob, file)
    end
  end
end

case ARGV[0]
when 'store'
  store = GitMetaStore.new
  store.store
when 'apply'
  store = GitMetaStore.new
  store.apply
else
  $stderr.puts <<~EOF
    Usage:
      #{$0} store
      #{$0} apply
  EOF
end
