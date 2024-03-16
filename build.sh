#!/bin/bash

# Custom Debian WSL toolkit Build Script
# building kali-environment on base debian distro

set -e

# Globals
# Change settings here to apply configuration to the system 
user=`cat /etc/passwd | grep 1000 | cut -d: -f1`
ipv4_address="0.0.0.0"
err_log="/tmp/install.log"
hostname="debian"
os=`uname -a | grep -i wsl | awk -F- '{print $2,$4}' | cut -d' ' -f1,2 | sed s'/.$//'`
legacy_tools=1


banner="
         _,met\$\$\$\$\$gg.           
      ,g\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$P.        || Custom Debian Installation ||
    ,g\$\$P\"\"       \"\"\"Y\$\$.\".      	  S C R I P T
   ,\$\$P'              \`\$\$\$.
  ',\$\$P       ,ggs.     \`\$\$b:
  \`d\$\$'     ,\$P\"'   .    \$\$\$
   \$\$P      d$'     ,    \$\$P
   \$\$:      \$\$.   -    ,d\$\$'
   \$\$\;      Y\$b._   _,d\$P'
   Y\$\$.    \`.\`\"Y\$\$\$\$P\"' 
   \`\$\$b      \"-.__   
    \`Y\$\$  
     \`Y\$\$.
       \`\$\$b.
         \`Y\$\$b.
            \`\"Y\$b._
                \`\"\"\"\"
"


run_all_checks() {
    echo -e "$banner"
    sleep 2.25
    
    # run as root 

    if [[ `id -u` != 0 ]]
    then
        echo -e "[x] Script must be run as root"
        exit 1
    fi 
}


install_requirements() {
    # prerequisite packages
    requirements=( wget curl vim gpg debootstrap)

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
    # Check if system is running WSL
    # Globals:
    # $os
    os=`echo $os | awk '{print $2}'`

    if [[ $os == "WSL" ]]
    then
    # Configure defaults for wsl.conf
        echo "[boot]
systemd = true

[interop]
enabled = true
appendWindowsPath = true

[network]
hostname = $hostname
generateResolvConf = false" | tee /etc/wsl.conf
    fi
}

configure_system() {

    # Globals
    # $os
    os=$os
    
    if [[ $os == "microsoft WSL" ]]
    then
        setcap cap_net_raw+p /bin/ping
    fi

    # Configure .bashrc
    wget https://raw.githubusercontent.com/catx0rr/debian-custom/master/configs/bashrc \
        -O $HOME/.bashrc

    cp $HOME/.bashrc /home/$user/.bashrc
    chown $user:$user /home/$user/.bashrc
}

configure_env() {
    # Configure other aliases and such
    echo -e "\nalias tmux='tmux -u'" | tee -a /root/.bashrc
    echo -e "\nalias tmux='tmux -u'" | tee -a /home/$user/.bashrc

    # export PATH variables to profile 
    go="/opt/go/bin"
    rust="/opt/cargo/bin"
    kerbrute="/opt/kerbrute"
    impacket="/opt/impacket"
    netexec="/opt/netexec"
    responder="/opt/responder"
    nuclei="/opt/nuclei"
    bloodhound="/opt/bloodhound"
    bloodhound_legacy="/opt/bloodhound-legacy"
    plumhound="/opt/plumhound"
    rusthound="/opt/rusthound"
    crackmapexec="/opt/crackmapexec"
    ldaprelayscan="/opt/ldaprelayscan"
    projectdiscovery="/opt/projectdiscovery"

    tools_path=( $go 
                 $rust 
                 $kerbrute 
                 $impacket 
                 $netexec 
                 $nuclei 
                 $bloodhound
                 $bloodhound_legacy
                 $plumhound
                 $rusthound
                 $crackmapexec
                 $ldaprelayscan
                 $projectdiscovery
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
    echo -e "\nexport PATH=\"\$PATH:$bin_path\"" \
        | tee -a /root/.profile
    
    # export env local user
    echo -e "\nexport PATH=\"\$PATH:$user_bin_path\"" \
        | tee -a /home/$user/.bashrc
    echo -e "\nexport PATH=\"\$PATH:$user_bin_path\"" \
        | tee -a /home/$user/.profile

    source $HOME/.bashrc
}

install_additional_packages() {
    # Install libraries, and other APT utilities from the system
    lib_pkgs=( libpcap-dev
               libpq-dev
               libgbm-dev
               libclang-dev
               libgssapi-krb5-2
               libkrb5-dev
               libsasl2-modules-gssapi-mit
             )

    utility_pkgs=( net-tools 
                   zip p7zip-full
                   dnsutils
                   mlocate
                   chafa
                   tmux
                   duf
                   bsdutils
                   musl-tools 
                 )

    prog_pkgs=( python3-full
                python3-netifaces
                python3-pip pipx 
                git 
                gcc 
                clang 
                gcc-mingw-w64-x86-64
              )

    system_pkgs=( network-manager screenfetch zsh ssh )
    other_pkgs=( firefox-esr chromium )
    
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
    sed -i s'/.*\$HOME.*//g' /home/$user/.bashrc
    sed -i s'/.*\$HOME.*//g' /root/.profile
    sed -i s'/.*\$HOME.*//g' /root/.bashrc

    # Install pipx packages
    pipx install virtualenv
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
    git clone https://github.com/camopants/igandx-Responder.git \
        $responder_source_path/igandx-Responder
    # Create a symlink to /opt/responder
    ln -s /home/$user/.local/igandx-Responder/Responder.py \
        /opt/responder/responder

    #########################
    # ldaprelayscan
    #########################
    ldaprelayscan_path="/home/$user/.local/share/pipx/venvs/ldaprelayscan"

    mkdir -p /opt/ldaprelayscan
    git clone https://github.com/zyn3rgy/LdapRelayScan $ldaprelayscan_path
    # build python virtual environment to use
    virtualenv $ldaprelayscan_path/venv
    mv $ldaprelayscan_path/venv/bin $ldaprelayscan_path
    mv $ldaprelayscan_path/LdapRelayScan.py $ldaprelayscan_path/bin
    chmod +x $ldaprelayscan_path/bin/LdapRelayScan.py
    source $ldaprelayscan_path/bin/activate
    # install requirements
    for x in `cat $ldaprelayscan_path/requirements_exact.txt`
    do 
        pipx install $x
    done
    deactivate

    # add python env to interpret and create a symlink to /opt/
    sed -i '0,/^import.*/s/^import.*/\#\!\/usr\/bin\/env\ python3\n&/' \
        $ldaprelayscan_path/bin/LdapRelayScan.py
    ln -s $ldaprelayscan_path/bin/LdapRelayScan.py \
        /opt/ldaprelayscan/ldaprelayscan

    # clean envs
    rm -rf $ldaprelayscan_path/venv $ldaprelayscan_path/docker

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
    cd /opt/bloodhound/
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

    #########################
    # RustHound
    #########################
    # yet another bloodhound ingestor tool built in rust
    rusthound_path="/opt/rusthound"

    git clone https://github.com/NH-RED-TEAM/RustHound $rusthound_path
    cd $rusthound_path
    cargo build --release
    mv $rusthound_path/target/release/rusthound .

    #########################
    # nuclei tools
    #########################
    # network va scanner
    project_discovery_path="/opt/projectdiscovery"

    mkdir -p $project_discovery_path

    # install latest aquatone
    curl https://api.github.com/repos/michenriksen/aquatone/releases \
		| grep "browser_download_url.*_linux_amd64_*.*.*zip" \
		| head -n1 \
		| cut -d: -f2,3 \
		| tr -d '"' \
		| wget -qi - -P $project_discovery_path
    # cleanup
    unzip $project_discovery_path/aquatone_linux_amd64_*.*.*.zip \
        -d $project_discovery_path
    rm -rf $project_discovery_path/aquatone_linux_amd64_*.*.*.zip \
        $project_discovery_path/*.txt \
        $project_discovery_path/*.md

    # install latest nuclei
    curl https://api.github.com/repos/projectdiscovery/nuclei/releases \
		| grep "browser_download_url.*_linux_amd64.zip" \
		| head -n1 \
		| cut -d: -f2,3 \
		| tr -d '"' \
		| wget -qi - -P $project_discovery_path
    # cleanup
    unzip $project_discovery_path/nuclei_*.*.*_linux_amd64.zip \
        -d $project_discovery_path
        rm -rf $project_discovery_path/nuclei_*.*.*_linux_amd64.zip \
        $project_discovery_path/*.txt \
        $project_discovery_path/*.md

    # install latest httpx
    curl https://api.github.com/repos/projectdiscovery/httpx/releases \
		| grep "browser_download_url.*_linux_amd64.zip" \
		| head -n1 \
		| cut -d: -f2,3 \
		| sed 's/"//g' \
		| wget -qi - -P $project_discovery_path
    # cleanup
    unzip $project_discovery_path/httpx_*.*.*_linux_amd64.zip \
        -d $project_discovery_path
    rm -rf $project_discovery_path/httpx_*.*.*_linux_amd64.zip \
        $project_discovery_path/*.txt \
        $project_discovery_path/*.md
    # remove python3-httpx conflicting package
    apt-get remove -yq python3-httpx --purge \
        -o Dpkg::Progress-Fancy="0" \
        -o APT::Color="0" \
        -o Dpkg::Use-Pty="0" 2> /dev/null \
        | tee -a $err_log

    # install latest katana
    curl https://api.github.com/repos/projectdiscovery/katana/releases \
		| grep "browser_download_url.*_linux_amd64.zip" \
		| head -n1 \
		| cut -d: -f2,3 \
		| sed 's/"//g' \
		| wget -qi - -P $project_discovery_path
    # cleanup
    unzip $project_discovery_path/katana_*.*.*_linux_amd64.zip \
        -d $project_discovery_path
    rm -rf $project_discovery_path/katana_*.*.*_linux_amd64.zip \
        $project_discovery_path/*.txt \
        $project_discovery_path/*.md

    # install latest nuclei templates
    git clone https://github.com/projectdiscovery/nuclei-templates \
        $project_discovery_path/nuclei-templates

    # compile all .yaml files to "all" directory
    mkdir -p $project_discovery_path/nuclei-templates/all \
        2>/dev/null
    find $project_discovery_path/nuclei-templates \
        -type f -name *.yaml \
        | xargs -I % cp -rfv % $project_discovery_path/nuclei-templates/all \
        2>/dev/null
}

install_legacy_tools() {
    #########################
    # Plumhound
    #########################
    # Bloodhound reporting tool
    # This only works for old bloodhound
    plumhound_path="/home/$user/.local/share/pipx/venvs/plumhound"

    # installing plumhound from the repository
    mkdir -p /opt/plumhound
    git clone https://github.com/PlumHound/PlumHound $plumhound_path
    pip3 install -r requirements.txt

    chmod +x $plumhound_path/PlumHound.py

    # fix the env terminal interpreter on the file
    sed -i '0,/python/s//python3/' $plumhound_path/PlumHound.py
    # creating symlinks to the executable file
    ln -s $plumhound_path/PlumHound.py \
        /opt/plumhound/plumhound

    #########################
    # Bloodhound
    #########################
    # predecessor of bloodhound-ce
    bloodhound_legacy_path=/opt/bloodhound-legacy
    
    # Download latest package and unpack contents
    mkdir /opt/bloodhound-legacy
    curl -s https://api.github.com/repos/BloodHoundAD/BloodHound/releases \
        | grep "browser_download_url.*/download/.*.*.*/*-linux-x64*.zip" \
        | head -n1 \
        | cut -d: -f2,3 \
		| tr -d '"' \
        | wget -i - -P $bloodhound_legacy_path

    cd $bloodhound_legacy_path
    unzip BloodHound-linux-x64.zip

    # Cleanup path
    mv BloodHound-linux-x64/* .
    mv BloodHound bloodhound-legacy
    rm -rf BloodHound-linux-x64 BloodHound-linux-x64.zip

    # download neo4j
    apt-get install -yq neo4j \
        -o Dpkg::Progress-Fancy="0" \
        -o APT::Color="0" \
        -o Dpkg::Use-Pty="0" 2> /dev/null \
        | tee -a $err_log

    #########################
    # crackmapexec
    #########################
    # predecessor of netexec
    crackmapexec_path="/opt/crackmapexec"

    # install and build crackmapexec
    git clone --recursive \
        https://github.com/byt3bl33d3r/CrackMapExec $crackmapexec_path
    # old crackmapexec is being handled by poetry
    pipx install poetry
    cd $crackmapexec_path
    poetry install
    poetry run crackmapexec
    # create path to executable
    cat >> $crackmapexec_path/crackmapexec << EOF
#!/bin/bash

poetry run crackmapexec "$@"
EOF

}

main() {
    run_all_checks
    install_requirements
    build_kali_repositories
    configure_wslconf
    configure_env
    configure_system
    install_additional_packages
    install_pentest_tools

    # Optional install
    if [ $legacy_tools -eq 1 ]
    then
        install_legacy_tools
    fi
}

main
source $HOME/.bashrc