#!/bin/bash
linux_deps_required(){
    step "Instalando dependência"
        try yum install -y epel-release > /dev/null 2>&1
        try yum install -y yum-utils unzip wget git > /dev/null 2>&1
    next
}