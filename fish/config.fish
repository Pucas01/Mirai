if status is-interactive
    set -g fish_greeting
    set -gx STARSHIP_CONFIG (status dirname (status current-filename))/starship.toml
    starship init fish | source

    set -g fish_color_normal d0d0d0
    set -g fish_color_command 39c5bb
    set -g fish_color_keyword 80e0e0
    set -g fish_color_quote e0c05a
    set -g fish_color_redirection d0d0d0
    set -g fish_color_end 39c5bb
    set -g fish_color_error ff6b6b
    set -g fish_color_param d0d0d0
    set -g fish_color_comment 666666
    set -g fish_color_selection --background=2a8a8a
    set -g fish_color_search_match --background=2a2a2a
    set -g fish_color_operator 80e0e0
    set -g fish_color_escape 80e0e0
    set -g fish_color_autosuggestion 555555
    set -g fish_color_cwd 39c5bb
    set -g fish_color_cwd_root ff6b6b
    set -g fish_pager_color_prefix 39c5bb
    set -g fish_pager_color_completion d0d0d0
    set -g fish_pager_color_description 666666
    set -g fish_pager_color_selected_background --background=2a8a8a

    if status is-command-substitution
    else if not set -q FASTFETCH_SHOWN
        set -gx FASTFETCH_SHOWN 1
        ff
    end
end
