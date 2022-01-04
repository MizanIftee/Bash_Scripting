#!/bin/bash
echo "***********************************"
PS3='Choose your option: '
options=("Zabbix Agent Installation" "Zabbix Server Installation" "Nginx Installation" "Haproxy Installation" "ElasticSearch Installation" "Kibana Installation" "Logstash Installation" "FileBeats Installation" "Quit")
select opt in "${options[@]}";
do
    case $opt in
        "Zabbix Agent Installation")
						#read -p 'Zabbix Server Name: ' zs
						#read -p 'HostName Where Agent will be installed: ' ag
                        zabbix_agent_conf_file="/etc/zabbix/zabbix_agentd.conf"
						zabbix_release_check=$(rpm -qa | grep zabbix-release)
						if [[ $zabbix_release_check == "" ]]; then
                        rpm -Uvh https://repo.zabbix.com/zabbix/4.2/rhel/7/x86_64/zabbix-agent-4.2.5-1.el7.x86_64.rpm
						fi
						yum -y install zabbix-agent
                        #exec < input.csv
						#read header
                        #SAVEIFS=$IFS
                        IFS=","
                        while read -r rec_column1 rec_column2 rec_column3;do
						if [[ $rec_column1 != "" && $rec_column2 != "" ]]; then
						sed -i "s/Server=127.0.0.1/Server=$rec_column1/g" $zabbix_agent_conf_file
                        sed -i "s/ServerActive=127.0.0.1/ServerActive=$rec_column1/g" $zabbix_agent_conf_file
                        sed -i "s/Hostname=Zabbix server/Hostname=$rec_column2/g" $zabbix_agent_conf_file
						fi
                        iptables -A INPUT -p tcp -s $rec_column1 --dport 10050 -m state --state NEW,ESTABLISHED -j ACCEPT
                        firewall-cmd --permanent --add-service=http
                        firewall-cmd --permanent --zone=public --add-port=10051/tcp
                        firewall-cmd --permanent --zone=public --add-port=10050/tcp
                        firewall-cmd --reload
                        systemctl restart zabbix-agent
                        done < <(awk -F, 'NR==3{print}' conf.csv)
						echo "Zabbix Agent is installed"

            ;;
		"Zabbix Server Installation")
		                yum -y install httpd
                        systemctl start httpd
                        systemctl enable httpd
						#Step 2 - Install and Configure PHP 7.2
						epel_check=$(rpm -qa | grep epel-release)
						php_check=$(rpm -qa | grep php72w)
						if [[ $epel_check == "" ]]; then
						yum -y install epel-release
						fi
						if [[ $php_check == "" ]]; then
                        rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
                        yum -y install mod_php72w php72w-cli php72w-common php72w-devel php72w-pear php72w-gd php72w-mbstring php72w-mysql php72w-xml php72w-bcmath
                        fi
						# add some params to the configure file of php
						PHP_CONF="/etc/php.ini"
						if [[ -f $PHP_CONF ]]; then
						sed -i "s/max_execution_time = 30/max_execution_time = 600/g" $PHP_CONF
						sed -i "s/max_input_time = 60/max_input_time = 600/g" $PHP_CONF
						sed -i "s/memory_limit = 128M/memory_limit = 256M/g" $PHP_CONF
						sed -i "s/post_max_size = 8M/post_max_size = 32M/g" $PHP_CONF
						sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 16M/g" $PHP_CONF
						sed -i "s/;date.timezone =/date.timezone = Asia\/Dhaka/g" $PHP_CONF
						fi
						systemctl restart httpd
						
						#Step 3 - Install and Configure MariaDB
						mariadb_check=$(rpm -qa | grep mariadb-server)
						IFS=","
						while read -r rec_column1 rec_column2 rec_column3 rec_column4 rec_column5 rec_column6;do
						if [[ $mariadb_check == "" ]]; then
                        #MYSQL_ROOT=rec_column1
						#MYSQL_PASS=rec_column2
						#DB_NAME=rec_column3
						yum -y install mariadb-server
                        systemctl start mariadb
                        systemctl enable mariadb
                        mysql -u $rec_column1 <<-EOF
						UPDATE mysql.user SET Password=PASSWORD('$rec_column2') WHERE User='$rec_column1';
						DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
						DELETE FROM mysql.user WHERE User='';
						DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
						FLUSH PRIVILEGES;
						EOF
						fi
                        Q1="CREATE DATABASE IF NOT EXISTS ${rec_column3};"
                        Q2="grant all privileges on $rec_column3.* to $rec_column4@'localhost' identified by '$rec_column5';"
                        Q3="grant all privileges on $rec_column3.* to $rec_column4@'%' identified by '$rec_column5';"
                        Q4="FLUSH PRIVILEGES;"
                        mysql --user="$rec_column1" --password="$rec_column2" -e "${Q1}${Q2}${Q3}${Q4}"
						
						yum -y install http://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-2.el7.noarch.rpm
                        yum -y install zabbix-get zabbix-server-mysql 
						
						sql_location="/usr/share/doc/zabbix-server-mysql-*"
                        gunzip $sql_location/create.sql.gz
						mysql -u $rec_column1 -p$rec_column2 $rec_column3 < $sql_location/create.sql

						#Configure Zabbix Server
						zabbix_server_conf="/etc/zabbix/zabbix_server.conf";
						sed -i "s/# DBHost=localhost/DBHost=localhost/g" $zabbix_server_conf
						sed -i "s/DBName=zabbix/DBName=$rec_column3/g" $zabbix_server_conf
						sed -i "s/DBUser=zabbix/DBUser=$rec_column4/g" $zabbix_server_conf
						sed -i "s/# DBPassword=/DBPassword=$rec_column5/g" $zabbix_server_conf
						done < <(awk -F, 'NR==7{print}' conf.csv)

                        systemctl start zabbix-server
                        systemctl enable zabbix-server
                        systemctl status zabbix-server
                        #Zabbix-server and Zabbix agent (port 10051 and 10050).
                        firewall-cmd --add-service={http,https} --permanent
                        firewall-cmd --add-port={10051/tcp,10050/tcp} --permanent
                        firewall-cmd --reload
                        firewall-cmd --list-all
						#Step 6 - Zabbix Initial Setup
                        systemctl restart zabbix-server
                        systemctl restart zabbix-agent
                        systemctl restart httpd
		;;
		
		"Nginx Installation")
						epel_check=$(rpm -qa | grep epel-release)
						if [[ $epel_check == "" ]]; then
						yum -y install epel-release
						fi
						yum install nginx -y
						systemctl start nginx
						systemctl enable nginx
						#If you are running a firewall
						yum install firewalld -y
						systemctl start firewalld
						systemctl enable firewalld
						firewall-cmd --permanent --add-service=http
						firewall-cmd --permanent --add-service=https
						firewall-cmd --reload
;;
		"Haproxy Installation")
						yum info haproxy
						# ( cc is an alias for the GNU C compiler (gcc). You can install it as follows:)
						gcc_check="rpm -qa | egrep gcc|pcre"
						if [[ $gcc_check == "" ]]; then
                        yum -y install gcc
						yum -y install pcre
						yum -y install pcre-devel
						fi
						yum -y install haproxy
						firewall-cmd --permanent --add-service=http
						firewall-cmd --permanent --add-port=8181/tcp
						firewall-cmd --reload
						firewall-cmd --list-all
						  
						  systemctl restart haproxy
						  systemctl enable haproxy
						  systemctl status haproxy						
                ;;
		"ElasticSearch Installation")
							#Elasticsearch
							shacheck=$(rpm -qa | grep perl-Digest-SHA)
							if [[ $shacheck == "" ]]
							then
							yum install -y perl-Digest-SHA
							fi

							maxmapcount=$(cat /etc/sysctl.conf | grep "vm.max_map_count = 262144")
							if [[ $maxmapcount == "" ]]
							then
							echo "vm.max_map_count = 262144" >> /etc/sysctl.conf
							sysctl -w vm.max_map_count=262144
							fi

							elkusercheck=$(cat /etc/security/limits.conf | grep "elasticsearch")
							if [[ $elkusercheck == "" ]]
							then
							useradd -r -s /sbin/nologin elasticsearch
							echo "elasticsearch  -  nofile  65535" >> /etc/security/limits.conf
							sysctl -w fs.file-max=500000
							fi


							IFS=","
							while read -r rec_column1 rec_column2 rec_column3 rec_column4 rec_column5 rec_column6;do
								if [[ $rec_column1 != "" && $rec_column2 != "" && $rec_column4 != "" && $rec_column5 != "" ]]
								then
								wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.8.0-linux-x86_64.tar.gz
								wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.8.0-linux-x86_64.tar.gz.sha512
								shasum -a 512 -c elasticsearch-7.8.0-linux-x86_64.tar.gz.sha512
								tar -xzf elasticsearch-7.8.0-linux-x86_64.tar.gz
								chown -R elasticsearch:elasticsearch elasticsearch-7.8.0
								e_dir=$(pwd)
								elastic_conf="$e_dir/elasticsearch-7.8.0/config/elasticsearch.yml"
								sed -i "s/#cluster.name: my-application/cluster.name: $rec_column1/g" $elastic_conf
								sed -i "s/#node.name: node-1/node.name: $rec_column2/g" $elastic_conf
								echo "node.master$rec_column3" >> $elastic_conf
								echo "node.data$rec_column3" >> $elastic_conf
								sed -i "s/#path.data: \/path\/to\/data/path.data: ${e_dir//\//\\/}\/elasticsearch-7.8.0\/lib/g" $elastic_conf
								sed -i "s/#path.logs: \/path\/to\/logs/path.logs: ${e_dir//\//\\/}\/elasticsearch-7.8.0\/logs/g" $elastic_conf
								sed -i "s/#network.host: 192.168.0.1/network.host: $rec_column4/g" $elastic_conf
								sed -i "s/#http.port: 9200/http.port: $rec_column5/g" $elastic_conf
								sed -i "s/#discovery.seed_hosts: \[\"host1\", \"host2\"\]/discovery.seed_hosts: \[\]/g" $elastic_conf
								sed -i "s/#cluster.initial_master_nodes: \[\"node-1\", \"node-2\"\]/cluster.initial_master_nodes: \[\"$rec_column2\"\]/g" $elastic_conf
								firewall-cmd --permanent --add-port=9200/tcp
								firewall-cmd --reload
								else
									echo "Please set all column in input csv file"
								fi
							done < <(awk -F, 'NR==11{print}' conf.csv)
				;;
		"Kibana Installation")

							IFS=","
							while read -r rec_column1 rec_column2 rec_column3 rec_column4 rec_column5 rec_column6 ;do
									if [[ $rec_column1 != "" && $rec_column2 != "" && $rec_column3 != "" && $rec_column4 != "" && $rec_column5 != "" ]]
									then
									curl -O https://artifacts.elastic.co/downloads/kibana/kibana-7.8.0-linux-x86_64.tar.gz
									curl https://artifacts.elastic.co/downloads/kibana/kibana-7.8.0-linux-x86_64.tar.gz.sha512 | shasum -a 512 -c -
									tar -xzf kibana-7.8.0-linux-x86_64.tar.gz
									e_dir=$(pwd)
									kibana_conf="$e_dir/kibana-7.8.0-linux-x86_64/config/kibana.yml"
									sed -i "s/#server.port: 5601/server.port: $rec_column2/g" $kibana_conf
									sed -i "s/#server.host: \"localhost\"/server.host: \"$rec_column3\"/g" $kibana_conf
									sed -i "s/#server.name: \"your-hostname\"/server.name: \"$rec_column1\"/g" $kibana_conf
									sed -i "s/#elasticsearch.hosts: \[\"http\:\/\/localhost\:9200\"\]/elasticsearch.hosts: \[${rec_column4//\//\\/}\]/g" $kibana_conf
									sed -i "s/#server.basePath: \"\"/server.basePath: \"${rec_column5//\//\\/}\"/g" $kibana_conf
									sed -i "s/#server.rewriteBasePath: false/server.rewriteBasePath: true/g" $kibana_conf
									firewall-cmd --permanent --add-port=5601/tcp
									firewall-cmd --reload
									else
											echo "Please set all column in input csv file"
									fi
							done < <(awk -F, 'NR==16{print}' conf.csv)
				;;
		"Logstash Installation")
									#Logstash
									e_dir=$(pwd)
									logstfile="$e_dir/logstash-7.8.0/config/logstash.yml"
									pipelinefile="$e_dir/logstash-7.8.0/config/pipelines.yml"
									logstash="$e_dir/logstash-7.8.0"
									inputconf="$e_dir/logstash-7.8.0/conf.d/input.conf"
									outconf="$e_dir/logstash-7.8.0/conf.d/out.conf"

									#Configuration update begain
									IFS=","
									while read -r rec_column1 rec_column2 rec_column3 rec_column4; do
									if [[ $rec_column1 != "" && $rec_column2 != "" && $rec_column3 != "" ]]; then
									if [ ! -d $logstash* ]; then
									wget https://artifacts.elastic.co/downloads/logstash/logstash-7.8.0.tar.gz
									tar -xzf logstash-7.8.0.tar.gz
									mkdir -p $e_dir/logstash-7.8.0/conf.d
									if [ ! -f $inputconf ]
									then
									touch $inputconf
									echo -e "input {\nbeats {\nport => $rec_column1\n}\n}" >> $inputconf
									fi

									if [ ! -f $outconf ]
									then

									touch $outconf
									echo -e "output {\nelasticsearch {\nhosts => [\"$rec_column2\"]\n#sniffing => true\nmanage_template => false\nindex => "%{index}-%{+YYYY.MM}"\n}\n}" >> $outconf
									fi
									cp -r $logstfile $logstfile.default
									cp -r $pipelinefile $pipelinefile.default
									>$logstfile
									>$pipelinefile
									echo -e "path.data: $e_dir/logstash-7.8.0/data" >> $logstfile
									echo -e "path.logs: $e_dir/logstash-7.8.0/logs" >> $logstfile
									echo -e "- pipeline.id: $rec_column3" >> $pipelinefile
									echo -e "  path.config: \"$e_dir/logstash-7.8.0/conf.d/*.conf\"" >> $pipelinefile
									# #out.cong vatiable
									
									else
											echo Logstash found.....
									fi

									else
											echo "Please set all column in input csv file"
									fi
									done < <(awk -F, 'NR==21{print}' conf.csv)
				;;
		"FileBeats Installation")
									#Filebeat
									repofile="/etc/yum.repos.d/filebeat.repo"

									if [[ ! -f $repofile ]]
									then
									touch $repofile

									echo "[elastic-7.x]
									name=Elastic repository for 7.x packages
									baseurl=https://artifacts.elastic.co/packages/7.x/yum
									gpgcheck=1
									gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
									enabled=1
									autorefresh=1
									type=rpm-md" >> $repofile
									fi

									filebeat_check=$(rpm -qa | grep filebeat)
									filebeat_conf="/etc/filebeat/filebeat.yml"

									if [[ $filebeat_check == "" ]]; then

									IFS=","
									while read -r rec_column1 rec_column2 rec_column3 rec_column4 rec_column5 rec_column6 rec_column7 rec_column8 rec_column9;do
									if [[ $rec_column1 != "" && $rec_column2 != "" && $rec_column3 != "" && $rec_column4 != "" && $rec_column5 != "" && $rec_column6 != "" && $rec_column7 != "" && $rec_column8 != "" && $rec_column9 != "" ]]; then

									yum install filebeat -y
									cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.bak
									> /etc/filebeat/filebeat.yml

									echo "filebeat.inputs: " >> $filebeat_conf
									echo "- type: $rec_column1" >> $filebeat_conf
									echo "  enabled$rec_column2" >> $filebeat_conf
									echo -e "  paths:\n    - $rec_column3" >> $filebeat_conf
									echo "  fields_under_root$rec_column4" >> $filebeat_conf
									echo "  fields: " >> $filebeat_conf
									echo "    index: [\"$rec_column5\"]" >> $filebeat_conf
									echo "  tags: [\"$rec_column6\"]" >> $filebeat_conf

									echo "filebeat.config.modules: " >> $filebeat_conf
									echo "  reload.enabled$rec_column8" >> $filebeat_conf

									echo "setup.template.settings: " >> $filebeat_conf
									echo "  index.number_of_shards: 5" >> $filebeat_conf

									echo "output.logstash: " >> $filebeat_conf
									echo "  hosts: [\"$rec_column10\"]" >> $filebeat_conf

									else
										echo "Please set all column in input csv file"
									fi
									done < <(awk -F, 'NR==26{print}' conf.csv)
									systemctl daemon-reload
									systemctl start filebeat
									systemctl enable filebeat
									firewall-cmd --reload
									else
									echo "Found filebeat rpm package, so don't install now"
									fi
				;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
	esac
        counter=1
    SAVEIFS=$IFS
    IFS=$(echo -en "\n\b")
    for i in ${options[@]};
    do
        echo $counter')' $i
        let 'counter+=1'
    done
    IFS=$SAVEIFS
done