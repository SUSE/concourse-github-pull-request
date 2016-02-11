Gem::Specification.new do |s|
  s.name        = 'concourse-github-pr-resource'
  s.version     = '0.1'
  s.summary     = 'Github pull requests as a concourse resource'
  s.description = <<-EOF
    This is an implementation of a concourse (http://concourse.ci/) resource
    for accessing pull requests.
  EOF
  s.homepage    = 'https://github.com/hpcloud/concourse-github-pr-resource'
  s.authors     = ['Aaron L']
  s.email       = 'hcf-dev@hpe.com'
  s.files       = Dir.glob('lib/*')
  s.license     = 'Apache-2.0'
  s.executables << 'in' << 'out' << 'check'
  s.add_dependency 'octokit', '~> 4.2'
end
