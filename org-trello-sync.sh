files=$(cat .org-trello-files)
for file in $files; do 
    emacs --batch --eval="(progn (load-file \"$HOME/.emacs.d/early-init.el\") (load-file \"$HOME/.emacs.d/init.el\" ) (find-file \"$file\") (org-trello-mode t) (org-trello-sync-buffer t))"
done