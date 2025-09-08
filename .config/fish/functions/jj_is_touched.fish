function jj_is_touched -d "Test if there are any changes in the working copy"
    jj_is_repo; and command jj status 2>/dev/null | command grep -q "Working copy changes"
end