#!/usr/bin/bash

set +e

restore_folder() {
    local tgt="$1"
    local loc="$2"
    
    if [[ -L "$tgt" ]]; then
        rm "$tgt"
    fi


}


restore_folder /mnt /var
restore_folder /opt /var
restore_folder /root /home
restore_folder /srv /var
restore_folder /usr/local /var
restore_folder /usr/tmp /var
