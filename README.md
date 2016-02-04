# concourse-github-pr-resource

This is an implementation of a [concourse](http://concourse.ci/) resource 
that deals with pull requests.

When a PR is made, this resource will fetch the PR into the requested directory.

It uses a check to ensure that it doesn't touch things twice, this effectively
stores state in Github and requires an access_token that can set these states
to function correctly.

## Source configuration
- `uri`: *Required* The uri to the github repo to check for pull requests.
- `access_token`: *Required* For talking to the API in the check step.
- `private_key`: *Optional* For fetching sources for private repositories.
- `branch`: *Optional* The branch to detect PR's against. If a PR is opened
but it's not against this branch it will not trigger.

## Behaviour

### `check`: Look for new commits against PR's.

Uses the github API to check if a commit it doesn't know about has landed in
a PR (the latest commit on any PR that doesn't have it's check).

### `in`: Fetch a ref from github

Pulls down a pull request ref from github.

### `out`: Upload an object to storage.

*None*.
