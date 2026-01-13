function magit
  emacs -nw -f magit-status -f delete-other-windows --chdir "$(realpath "$(git rev-parse --show-toplevel)")"
end
