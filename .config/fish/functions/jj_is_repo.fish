function jj_is_repo -d "Test if the current directory is a Jujutsu repository"
    if not command jj root > /dev/null 2>/dev/null
        return 1
    end
end