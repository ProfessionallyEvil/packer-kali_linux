#!/usr/bin/env bash

set -ex

deps=( "bsdtar" "recon-ng" "nmap" "remmina" "bloodhound" "crackmapexec" "responder" "eyewitness" "nikto" "burpsuite" "metasploit-framework" "john" "exploitdb" "wireshark")
github_array=( "https://github.com/EmpireProject/Empire.git" )
if [[ -d /vagrant ]] ; then
  script_dir='/vagrant'
else
  script_dir="$(dirname "$(realpath "${0}")")"
fi

convert_kali(){
  pushd "${script_dir}" || exit
  sudo bash debian-kali.sh
  popd
}
openvas_func(){
  if grep 'ID=debian' /etc/*release 1>/dev/null ; then
    if grep 'VERSION_ID="9"' /etc/*release 1>/dev/null  ; then
      pushd "${script_dir}" || exit
      ln -s "$(pwd)" /tmp/openvas
      # installing deps
      sudo bash openvas_setup.sh
      # debian specific
      convert_kali
      # installing openvas
      sudo bash get-openvas.sh
      popd
    else
      sudo DEBIAN_FRONTEND='noninteractive' apt install -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' -y openvas
      openvas-setup
      sed -i 's/--listen=127.0.0.1/--listen=0.0.0.0/' /lib/systemd/system/greenbone-security-assistant.service
      systemctl daemon-reload
      systemctl restart greenbone-security-assistant.service
      openvasmd --user=admin --new-password=admin
      # debian specific
      convert_kali
    fi
  else
    # other OS should be Kali
    sudo DEBIAN_FRONTEND='noninteractive' apt install -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'  -y openvas
    openvas-setup
    sed -i 's/--listen=127.0.0.1/--listen=0.0.0.0/' /lib/systemd/system/greenbone-security-assistant.service
    systemctl daemon-reload
    systemctl restart greenbone-security-assistant.service
    openvasmd --user=admin --new-password=admin
  fi
}

desk_func(){
  # marking plymouth to not be installed, because it screws up kernel hooks.
  sudo apt-mark hold plymouth

  sudo apt install -y xfce4 lxqt x2goserver
}
bloodhound_func(){
  # doing initial neo4j setupwhich
  cp "$(command -v neo4j)" /usr/bin/neo4j-admin
  sed -i 's,bin/neo4j,bin/neo4j-admin,' "$(command -v neo4j-admin)"
  # https://neo4j.com/docs/operations-manual/current/configuration/set-initial-password/
  neo4j-admin set-initial-password admin

  # adding example data

  # setting up as a service
  cat > /lib/systemd/system/neo4j.service <<EOF
  [Unit]
  Description=Neo4j Graph Database
  After=network-online.target
  Wants=network-online.target

  [Service]
  ExecStart=/usr/bin/neo4j console
  Restart=on-failure
  Environment="NEO4J_CONF=/etc/neo4j" "NEO4J_HOME=/usr/share/neo4j"
  LimitNOFILE=60000
  TimeoutSec=120

  [Install]
  WantedBy=multi-user.target
EOF

  # reloading services and enabling
  systemctl daemon-reload
  systemctl enable neo4j
}

Empire_func(){
  pushd "$1"
  # shellcheck disable=SC2016
  echo 'P@$$w0rd' | ./setup/install.sh
  popd
}
main(){
  echo "installing all necessary packages for the class."

  export DEBIAN_OPTIONS=" -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' "
  export DEBIAN_FRONTEND='noninteractive'

  sudo apt-get clean
  sudo apt-get update

  # openvas had to be seperate because it's openvas...
  openvas_func

  # updating apt cache
  sudo apt-get update

  # installing all tools for class
  sudo DEBIAN_FRONTEND='noninteractive' apt-get install -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' -y "${deps[@]}"
  for package in "${deps[@]}" ; do
    if eval "${package}_func" 2>/dev/null ; then
      eval "${package}_func"
    fi
  done

  # preping for github projects
  pushd /opt

  # configuring all github projects
  for src in "${github_array[@]}" ; do
    project_name=$(echo "$src" | rev | cut -d '/' -f 1 | cut -d '.' -f 2 | rev )
    rm -rf "${project_name}"
    echo "Configuring $project_name"
    git clone --recursive "$src"
    eval "${project_name}_func" "$project_name"
  done

  # leaving /opt
  popd

  # installing desktop env and remote access
  case "$(sudo dmidecode -s 'bios-vendor')" in
    "Amazon EC2")
      desk_func
      ;;
  esac

  if [ -f /var/run/reboot-required ] ; then
    echo 'Rebooting'
    sudo reboot
  fi

}

main
