function cleanup_node_modules --description "Find and optionally delete node_modules directories"
    # Define script path - using the actual location
    set script_path "/Users/marco/Github/scripts-collection/mac/cleanup-node-modules.sh"
    
    # If script doesn't exist, warn the user
    if not test -f $script_path
        echo "Error: Script not found at $script_path"
        echo "Please copy cleanup-node-modules.sh to $script_path or adjust the path in this function"
        return 1
    end
    
    # Pass all arguments to the script
    bash $script_path $argv
end

# Add these lines to your ~/.config/fish/config.fish to make the function available:
# if test -f ~/.config/fish/functions/cleanup_node_modules.fish
#     source ~/.config/fish/functions/cleanup_node_modules.fish
# end
