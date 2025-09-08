function jj_branch_name -d "Get the name of the current Jujutsu branch or change ID"
    set -l branch_name (command jj log --no-graph -r @ -T 'branches.join(" ")' 2>/dev/null | string trim)
    
    if test -z "$branch_name"
        command jj log --no-graph -r @ -T 'change_id.short()' 2>/dev/null
    else
        printf "%s\n" "$branch_name"
    end
end