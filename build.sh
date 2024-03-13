#!/bin/bash

# Custom Debian WSL toolkit Build Script
# building kali-environment on base debian distro

set -e

# Globals
# Change settings here to apply configuration to the system 
user=`cat /etc/passwd | grep 1000 | cut -d: -f1`
ipv4_address="0.0.0.0"
err_log="/tmp/install.log"


run_checks() {
    run_level=`ps aux | grep init | head -n1 | awk '{print $11}' | tr -d /`

    # Systemd check
    if [[ $run_level == "init" ]]
    then
        echo -e "[x] Must be running systemd to start"
        exit 1
    fi

    # run as root 

    if [[ `id -u` != 0 ]]
    then
        echo -e "[x] Script must be run as root"
        exit 1
    fi 
}


install_requirements() {
    # prerequisite packages
    requirements=( wget curl vim gpg zsh )

    echo -e "[*] Updating system.."

    apt-get update -yq -o Dpkg::Progress-Fancy="0" \
            -o APT::Color="0" \
            -o Dpkg::Use-Pty="0" 2> /dev/null \
            | tee $err_log

    apt-get full-upgrade -yq -o Dpkg::Progress-Fancy="0" \
            -o APT::Color="0" \
            -o Dpkg::Use-Pty="0" 2> /dev/null \
            | tee -a $err_log

    echo -e "[+] Done..\n"
    
    echo -e "[*] Installing required packages.."
    
    for pkg in ${requirements[@]}
    do
        echo -e "[*] Installing $pkg"
        apt-get install $pkg -yq -o Dpkg::Progress-Fancy="0" \
            -o APT::Color="0" \
            -o Dpkg::Use-Pty="0" 2> /dev/null \
            | tee -a $err_log
        sleep 1
    done

    echo -e "[+] Done.\n"
}


build_kali_repositories() {
    # https://www.kali.org/docs/development/live-build-a-custom-kali-iso/
    # Non-Kali Debian Based Environment

    # Installing kali archive keyring and packages
    keyring=`curl -s https://http.kali.org/pool/main/k/kali-archive-keyring/ \
        | grep "href=\"kali-archive-keyring_20**.*_all.deb\"" \
        | cut -d'"' -f4`
    build=`curl -s wget https://http.kali.org/pool/main/l/live-build/ \
        | grep -E "live-build_20***.*.*.*\+kali3_all.deb" \
        | cut -d'"' -f6`

    wget https://http.kali.org/pool/main/k/kali-archive-keyring/$keyring
    wget https://http.kali.org/pool/main/l/live-build/$build

    # Install keyring and build
    dpkg -i $keyring 
    dpkg -i $build

    # Clean directory
    rm -rf $keyring $build

    # Add repository in /etc/apt/sources.list and update
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    echo -e "\n# See https://www.kali.org/docs/general-use/kali-linux-sources-list-repositories/
deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware

# Additional line for source packages
# deb-src http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware" \
    | tee -a /etc/apt/sources.list

    apt-get update -yq -o Dpkg::Progress-Fancy="0" \
            -o APT::Color="0" \
            -o Dpkg::Use-Pty="0" 2> /dev/null \
            | tee $err_log

    apt-get --fix-broken install -yq -o Dpkg::Progress-Fancy="0" \
            -o APT::Color="0" \
            -o Dpkg::Use-Pty="0" 2> /dev/null \
            | tee $err_log
}


configure_wslconf() {
    # Configure defaults for wsl.conf
    echo "[boot]
systemd=true
command=systemctl start ssh
command=echo \"nameserver 1.1.1.1
nameserver 9.9.9.9\" > /etc/resolv.conf

[interop]
enabled=true
appendWindowsPath=true

[network]
generateResolvConf=false" | tee /etc/wsl.conf
}


configure_env() {
    # export PATH variables to profile 
    go="/opt/go/bin"
    rust="/opt/cargo/bin"
    kerbrute="/opt/kerbrute"
    impacket="/opt/impacket"
    netexec="/opt/netexec"
    responder="/opt/responder"
    nuclei="/opt/nuclei"
    bloodhound="/opt/bloodhound"

    tools_path=( $go 
                 $rust 
                 $kerbrute 
                 $impacket 
                 $netexec 
                 $nuclei 
                 $bloodhound
               )

    for path in ${tools_path[@]}
    do 
        # append paths to variable
        bin_path+="$path:"
        user_bin_path+="$path:"
    done

    bin_path+="$HOME/.local/bin"
    user_bin_path+="/home/$user/.local/bin"

    # export env root user
    echo -e "\nexport PATH=\"\$PATH:$bin_path\"" \
        | tee -a /root/.bashrc
    source $HOME/.profile

    # export env local user
    echo -e "\nexport PATH=\"\$PATH:$user_bin_path\"" \
        | tee -a /home/$user/.profile

}

configure_system() {

    # Fix ping in wsl
    os=`uname -a | grep -i wsl | awk -F- '{print $3,$5}' | cut -d' ' -f1,2`

    if [[ $os == "microsoft WSL2" ]]
    then
        setcap cap_net_raw+p /bin/ping
    fi

    # Configure shell
    usermod --shell /bin/zsh $user


}

install_additional_packages() {
    # Install libraries, and other APT utilities from the system
    lib_pkgs=( libpcap-dev libpq-dev libgbm-dev )
    utility_pkgs=( net-tools zip p7zip-full dnsutils mlocate chafa tmux duf )
    system_pkgs=( network-manager screenfetch zsh ssh )
    prog_pkgs=( python3-full python3-netifaces python3-pip pipx git gcc )
    other_pkgs=( firefox-esr )
    
    for pkg in ${lib_pkgs[@]}
    do 
        apt-get install $pkg -yq -o Dpkg::Progress-Fancy="0" \
            -o APT::Color="0" \
            -o Dpkg::Use-Pty="0" 2> /dev/null \
            | tee -a $err_log
    done

    for pkg in ${utility_pkgs[@]}
    do
        apt-get install $pkg -yq -o Dpkg::Progress-Fancy="0" \
            -o APT::Color="0" \
            -o Dpkg::Use-Pty="0" 2> /dev/null \
            | tee -a $err_log
    done

    for pkg in ${system_pkgs[@]}
    do
        apt-get install $pkg -yq -o Dpkg::Progress-Fancy="0" \
            -o APT::Color="0" \
            -o Dpkg::Use-Pty="0" 2> /dev/null \
            | tee -a $err_log
    done

    for pkg in ${prog_pkgs[@]}
    do
        apt-get install $pkg -yq -o Dpkg::Progress-Fancy="0" \
            -o APT::Color="0" \
            -o Dpkg::Use-Pty="0" 2> /dev/null \
            | tee -a $err_log
    done

    for pkg in ${other_pkgs[@]}
    do
        apt-get install $pkg -yq -o Dpkg::Progress-Fancy="0" \
            -o APT::Color="0" \
            -o Dpkg::Use-Pty="0" 2> /dev/null \
            | tee -a $err_log
    done
        
    # latest golang package
    latest_pkg=`curl -s https://go.dev/dl/ \
        | grep \<span\>go*.**.*.linux-amd64.tar.gz \
        | cut -d'<' -f2 \
        | sed -z s'/span>//'g`
    # Install go lang
    wget https://go.dev/dl/$latest_pkg
    tar -C /opt/ -xzf $latest_pkg
    source $HOME/.bashrc
    # clean downloaded pkg
    rm -rf $latest_pkg

    # Install rustc
    curl --proto '=https' \
    --tlsv1.2 \
    -sSf https://sh.rustup.rs \
    | sh -s -- -y
    mv $HOME/.cargo /opt/cargo
    # clean cargo envs
    sed -i s'/.*\$HOME.*//g' $HOME/.profile
    sed -i s'/.*\$HOME.*//g' $HOME/.profile
}

install_pentest_tools() {
    #########################
    # APT PT tools
    #########################

    pt_tools=( smbclient 
               bloodhound.py
             )

    for pkg in ${pt_tools[@]}
    do
        apt-get install $pkg -yq -o Dpkg::Progress-Fancy="0" \
            -o APT::Color="0" \
            -o Dpkg::Use-Pty="0" 2> /dev/null \
            | tee -a $err_log
    done

    #########################
    # IMPACKET
    #########################
    impacket_source_path="/home/$user/.local/share/pipx/venvs/impacket/lib/python3.11/site-packages"

    mkdir -p /opt/impacket
    
    user_pipx_dir="/home/$user/.local/bin"

    # Install impacket on user local and configure
    su - $user -c "pipx install impacket"
    su - $user -c "pipx ensurepath"

    # Rename .py to impacket- and move symlinks to /opt/impacket
    for x in `ls $user_pipx_dir`
    do 
        impacket_tool=`echo impacket-$x | sed s'/.py//'`
        mv $user_pipx_dir/$x $user_pipx_dir/$impacket_tool
    done

    # Make /opt direct path
    cp -a $user_pipx_dir/*impacket* /opt/impacket

    # Tool dependency (pcapy)
    # Fix pcapy dependencies
    # https://github.com/stamparm/pcapy-ng
    git clone https://github.com/stamparm/pcapy-ng $impacket_source_path/pcapy-ng
    cd $impacket_source_path/pcapy-ng
    python3 setup.py build
    cd -
    cp $impacket_source_path/pcapy-ng/build/lib.linux-x86_64-cpython-311/pcapy.cpython-311-x86_64-linux-gnu.so \
        $impacket_source_path/

    # Clean up
    rm -rf $user_pipx_dir/*impacket*

    #########################
    # NETEXEC
    #########################
    # modern crackmapexec
    mkdir -p /opt/netexec

    # Install on user local
    su - $user -c "pipx install git+https://github.com/Pennyw0rth/NetExec"

    # Make /opt direct path
    cp -a $user_pipx_dir/* /opt/netexec

    # Clean up
    rm -rf $user_pipx_dir/*

    #########################
    # KERBRUTE
    #########################
    # Install on user local
    mkdir -p /opt/kerbrute

    # Install impacket on user local
    su - $user -c "/opt/go/bin/go install github.com/ropnop/kerbrute@latest"

    mv /home/$user/go /home/$user/.local/

    # Create a symlink to /opt/kerbrute
    ln -s /home/$user/.local/go/bin/kerbrute /opt/kerbrute/

    #########################
    # igandx-Responder
    #########################
    responder_source_path="/home/$user/.local"

    mkdir -p /opt/responder

    git clone https://github.com/camopants/igandx-Responder.git $responder_source_path/igandx-Responder

    # Create a symlink to /opt/responder
    ln -s /home/$user/.local/igandx-Responder/Responder.py /opt/responder/responder

    #########################
    # Bloodhound and Ingestors
    #########################

    # Docker Installation
    # check clean
    container_pkgs=( docker.io docker-doc docker-compose podman-docker containerd runc )
    for pkg in ${container_pkgs[@]}
    do 
        apt-get remove -yq -o Dpkg::Progress-Fancy="0" \
            -o APT::Color="0" \
            -o Dpkg::Use-Pty="0" 2> /dev/null \
            | tee -a $err_log
    done

    # docker official gpg keys
    apt-get update -yq -o Dpkg::Progress-Fancy="0" \
        -o APT::Color="0" \
        -o Dpkg::Use-Pty="0" 2> /dev/null \
        | tee -a $err_log
        
    apt-get install -yq install ca-certificates \
        -o Dpkg::Progress-Fancy="0" \
        -o APT::Color="0" \
        -o Dpkg::Use-Pty="0" 2> /dev/null \
        | tee -a $err_log

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg \
         -o /etc/apt/keyrings/docker.asc 
    chmod a+r /etc/apt/keyrings/docker.asc

    # add to repositories
    echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update -yq -o Dpkg::Progress-Fancy="0" \
        -o APT::Color="0" \
        -o Dpkg::Use-Pty="0" 2> /dev/null \
        | tee -a $err_log

    apt-get install -yq docker-ce docker-ce-cli containerd.io \
         docker-buildx-plugin docker-compose docker-compose-plugin \
        -o Dpkg::Progress-Fancy="0" \
        -o APT::Color="0" \
        -o Dpkg::Use-Pty="0" 2> /dev/null \
        | tee -a $err_log

    # Bloodhound Installation
    git clone https://github.com/SpecterOps/BloodHound.git /opt/bloodhound
    cd /opt/bloodound/
    cp examples/docker-compose/* ./

    # Create a symlink to execute bloodhound-ce
    cat >> /usr/bin/bloodhound << EOF
#!/bin/bash

# run bloodhound-ce docker compose
cd /opt/bloodhound
docker-compose up -d
EOF

    cat >> /usr/bin/bloodhound-kill << EOF
#/bin/bash

# terminates all bloodhound-ce docker instances
cd /opt/bloodhound
docker-compose down
EOF

}

main() {
    run_checks
    install_requirements
    build_kali_repositories
    configure_wslconf
    configure_env
    configure_system
    install_additional_packages
    install_pentest_tools
}

main
