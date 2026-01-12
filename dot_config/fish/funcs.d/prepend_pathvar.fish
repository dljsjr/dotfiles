function prepend_pathvar
  set -f element $argv[1]
  set -f pathvar $argv[2]
  if not contains $element $$pathvar
      set -p $pathvar $element
  end
end
