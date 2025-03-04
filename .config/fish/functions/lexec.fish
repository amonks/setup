function lexec
  set cmd (llm -m "4o-mini" "output a fish one-liner to perform the following task:\n\n$argv\n\noutput only the fish code, with no additional information or commentary. Do not output surrounding backticks: only the code.")
  if ! yes-or-no $cmd
    return 1
  end

  echo $cmd | source
end

