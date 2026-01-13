function append_pathvar
  set -f element $argv[1]
  set -f pathvar $argv[2]
  if not contains $element $$pathvar
      set -a $pathvar $element
  end
end
