NAME ?= helioncf/concourse-github-pull-request:latest

SOURCES := \
	bin/ \
	lib/ \
	concourse-github-pull-request.gemspec \
	Gemfile \
	Gemfile.lock \
	Dockerfile \
	${NULL}

build:
	# Use tar to ensure we don't accidentally include unexpected files
	tar c ${SOURCES} | docker build -t ${NAME} -

push: build
	docker push ${NAME}

test: rspec rubocop inch

rspec:
	bundle install --with=test
	bundle exec rspec

rubocop:
	bundle install --with=test
	bundle exec rubocop

inch:
	bundle install --with=test
	bundle exec inch

.PHONY: build push test rspec rubocop inch
