# encoding: utf-8
# Copyright (c) 2016 Nathan Currier

require 'jekyll'
require 'rake/clean'

jekyll_config = Jekyll.configuration
jekyll_config['skip_config_files'] = true
jekyll_site = jekyll_config['destination']

CLEAN.include jekyll_site

if ENV['TRAVIS']
  require 'ghpages_deploy/rake_task'

  desc 'Deploy site to Github Pages'
  GithubPages::DeployTask.new(deploy: :build) do |t|
    t.source = '_site'

    t.init_jekyll

    # Don't delete CNAME
    t.handler.handle_precheck_delete? { |file| file != 'CNAME' }
  end
end

task build: :clean do
  Jekyll::Commands::Build.process(jekyll_config)
end

task preview: :build do
  Jekyll::Commands::Serve.process(jekyll_config)
end

task default: :preview
task ci: :deploy
