#!/usr/bin/env bash

set -ex

deps=( "bsdtar" "recon-ng" "nmap" "remmina" "bloodhound" "crackmapexec" "responder" "eyewitness" "nikto" "burpsuite" "metasploit-framework" "john" "exploitdb" )
github_array=( "https://github.com/EmpireProject/Empire.git" )

bloodhound_func(){
  # variables
  neo4j_db_path='/usr/share/neo4j/data/databases'
  tmp_bloodhound_gh_path='/tmp/bloodhound'
  bloodhound_example_db='BloodHoundExampleDB.graphdb'
  neo4j_conf='/etc/neo4j/neo4j.conf'

  # doing initial neo4j setup
  cp $(which neo4j) /usr/bin/neo4j-admin
  sed -i 's,bin/neo4j,bin/neo4j-admin,' $(which neo4j-admin)
  # https://neo4j.com/docs/operations-manual/current/configuration/set-initial-password/
  neo4j-admin set-initial-password neo4j

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
  pushd $1
  echo 'P@$$w0rd' | ./setup/install.sh
  popd
}
main(){
  echo "installing all necessary packages for the class."

  # updating apt cache
  apt-get update

  # installing all tools for class
  apt-get install -y ${deps[@]}
  for package in "${deps[@]}" ; do
    if eval "${package}_func" 2>/dev/null ; then
      eval "${package}_func"
    fi
  done

  # preping for github projects
  pushd /opt

  # configuring all github projects
  for src in "${github_array[@]}" ; do
    project_name=$(echo $src | rev | cut -d '/' -f 1 | cut -d '.' -f 2 | rev )
    echo "Configuring $project_name"
    git clone --recursive "$src"
    eval "${project_name}_func" "$project_name"
  done

  # leaving /opt
  popd

}

main
