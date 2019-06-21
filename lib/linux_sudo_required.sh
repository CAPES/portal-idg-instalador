#!/bin/bash
linux_sudo_required(){
    if [[ $UID != 0 ]]; then
        echo
        echo "No mundo de hoje, sem SUDO, nada somos ;)"
        echo
        echo "sudo $0 $*"
        echo
        exit 1
    fi
}