function fish_prompt
  set -l last_command_status $status


  set -l normal_color     (set_color normal)

  set -l bold             (set_color normal --bold)
  set -l cyan             (set_color cyan --bold)
  set -l red              (set_color red --bold)
  set -l green            (set_color green --bold)
  set -l magenta          (set_color magenta --bold)
  set -l blue             (set_color blue --bold)

  set -l fish     "⋊>"

  set -l ahead    "↑"
  set -l behind   "↓"
  set -l diverged "⥄ "
  set -l dirty    $red"●"
  set -l none     "◦"

  if test -z "$machine_sigil"
    set machine_sigil "?"
  end
  # set -l caret    "$fish"
  set -l caret    ">"

  echo -n $bold"$machine_sigil "$normal_color
  echo -n $cyan(prompt_pwd) $normal_color

  if git_is_repo
    # git branch
    echo -n $bold(git_branch_name) $normal_color

    # git status
    if git_is_touched
      echo -n -s $dirty $normal_color
    else
      echo -n -s $bold (git_ahead $ahead $behind $diverged $none) $normal_color
    end
    echo -n " "
  end

  # prompt
  if test $last_command_status -eq 0
    echo -n -s $bold "$caret" $normal_color
  else
    echo -n -s $red "$caret" $normal_color
  end

  set_color $fish_color_cwd
  echo -n " "
end

