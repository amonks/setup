function jj_ahead -a ahead behind diverged none
    set -l status_output (command jj log --no-graph -r '@-' -T 'if(remote_bookmarks, "has_remote", "no_remote")' 2>/dev/null)
    
    if test "$status_output" = "no_remote"
        printf "%s\n" "$none"
    else
        set -l log_output (command jj log --no-graph -r '@' -T 'if(ahead_behind.ahead > 0 && ahead_behind.behind > 0, "diverged", if(ahead_behind.ahead > 0, "ahead", if(ahead_behind.behind > 0, "behind", "none")))' 2>/dev/null)
        
        switch "$log_output"
            case "ahead"
                printf "%s\n" "$ahead"
            case "behind"  
                printf "%s\n" "$behind"
            case "diverged"
                printf "%s\n" "$diverged"
            case "*"
                printf "%s\n" "$none"
        end
    end
end