function ff --description "Run fastfetch with the configured logo"
    set -l logo_state ~/.cache/qs-fastfetch-logo-path
    set -l logo_path
    if test -f $logo_state
        set logo_path (string trim -- (cat $logo_state))
    end

    if test -n "$logo_path" -a -f "$logo_path"
        fastfetch --logo-type kitty-icat --logo "$logo_path" $argv
    else
        fastfetch $argv
    end
end
