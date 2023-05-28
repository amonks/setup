#!/usr/bin/env fish

if ! gh auth status
  echo "not logged into github"
  exit 1
end

function backup --argument-names org
  for repo in (gh repo list --limit 500 "$org" | cut -f1 | cut -d'/' -f2)
    echo "org: $org; repo: $repo"
    if test -d "$backup_dir/$org/$repo"
      echo "pull $org/$repo"
      cd "$backup_dir/$org/$repo"
      git fetch --all
      git pull --all
    else
      echo "clone $org/$repo"
      mkdir -p "$backup_dir/$org"
      cd "$backup_dir/$org"
      git clone "git@github.com:$org/$repo.git"
    end
  end
end




set backup_dir /mypool/tank/mirror/github

set orgs_response (gh api graphql -f query='
  {
    viewer {
      login
      organizations(first: 100) {
        nodes {
          login
        }
      }
    }
  }
')

set orgs (echo $orgs_response | jq --raw-output .data.viewer.organizations.nodes[].login)

backup amonks

for org in $orgs
  backup $org
end

