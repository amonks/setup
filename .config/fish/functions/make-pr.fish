# usage:
# - commits from stdin
# - branch from first arg
#
# eg
#     echo "abc123
#     def456" | make-prs cool-pr
function make-pr
  set branch $argv
  set commits

  while read -l commit_line
    set commit (echo $commit_line | cut -d' ' -f1)
    set -a commits $commit
  end

  echo
  echo "COMMITS"
  for commit in $commits
    git --no-pager show "$commit" --stat
  end
  echo
  echo "TARGET BRANCH $branch"

  git master
  git branch -D amonks/$branch
  git checkout -b amonks/$branch

  for commit in $commits
	  git cherry-pick $commit
  end
  git p
end

