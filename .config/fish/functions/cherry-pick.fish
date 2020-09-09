function cherry-pick
  set name "rambundle-improvements"
  set -l branches "master"
  set -l commits "0269b7f200a" "c036f293075" "3aa0505dfa0"

  for commit in $commits
    git --no-pager show $commit --oneline --stat
    echo
  end
  echo "cherry-pick those commits into $branches"
  wait-for-enter

  for branch in $branches
    echo "branch" $branch

    git reset --hard
    git checkout master
    git reset --hard
    git branch -D amonks/$name-$branch
    git checkout -b amonks/$name-$branch
    git reset --hard origin/driver2/$branch

    for commit in $commits
      git cherry-pick $commit
      or wait-for-enter
    end

    git p
  end

  for branch in $branches
    echo https://github.com/samsara-dev/backend/compare/driver2/$branch...amonks/$name-$branch
  end
end

