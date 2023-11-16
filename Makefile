include env
ENV_FILE:=env

USER:=isucon
SERVICE_NAME:=isuports.service

DB_PATH:=/etc/mysql
MYSQL_LOG:=/var/log/mysql/slow.log

NGINX_PATH:=/etc/nginx
NGINX_LOG:=/var/log/nginx/access.log

PROJECT_ROOT:=/home/isucon
BUILD_DIR:=/home/isucon/isuumo/webapp/node

ALP_LOG:=/home/isucon/logs/alp.txt
PT_QUERY_LOG:=/home/isucon/logs/pt-query-digest.txt


.PHONY: restart
restart:
	sudo systemctl daemon-reload
	sudo systemctl restart $(SERVICE_NAME)

.PHONY: bench
bench: before log

.PHONY: log
log:
	sudo journalctl -u $(SERVICE_NAME) -n10 -f

.PHONY: maji
bench: before restart

.PHONY: analyse
analyse: slow alp

.PHONY: before
before:
	$(eval when := $(shell date "+%s"))
	mkdir -p ~/logs/$(when)
	sudo touch $(NGINX_LOG);
	sudo mv -f $(NGINX_LOG) ~/logs/$(when)/ ;
	sudo touch $(MYSQL_LOG);
	sudo mv -f $(MYSQL_LOG) ~/logs/$(when)/ ;
	sudo cp -rf $(PROJECT_ROOT)/mysql /etc/mysql
	sudo cp -rf $(PROJECT_ROOT)/nginx /etc/nginx
	sudo systemctl restart nginx
	sudo systemctl restart mysql

.PHONY: slow
slow:
	sudo pt-query-digest $(MYSQL_LOG)

.PHONY: slow-slack
slow-slack:
	sudo pt-query-digest $(MYSQL_LOG) > $(PT_QUERY_LOG) | slack_notify $(PT_QUERY_LOG)

.PHONY: alp
alp:
	sudo alp ltsv --file=$(NGINX_LOG) --config=/home/isucon/tool/alp/config.yml

.PHONY: alp-slack
alp-slack:
	sudo alp ltsv --file=$(NGINX_LOG) --config=/home/isucon/tool/alp/config.yml > $(ALP_LOG) | slack_notify $(ALP_LOG)

.PHONY: access-db
access-db:
	mysql -h $(ISUCON_DB_HOST) -P $(ISUCON_DB_PORT) -u $(ISUCON_DB_USER) -p$(ISUCON_DB_PASSWORD) $(ISUCON_DB_NAME)

.PHONY: setup
setup: install-tool get-db-conf get-nginx-conf git-setup get-env

.PHONY: install-tool
install-tool:
	sudo apt-get update
	sudo apt-get install htop unzip jq

	# pt-query-digest
	wget https://github.com/percona/percona-toolkit/archive/refs/tags/v3.5.5.tar.gz
	tar zxvf v3.5.5.tar.gz
	sudo install ./percona-toolkit-3.5.5/bin/pt-query-digest /usr/local/bin
	# alp
	wget https://github.com/tkuchiki/alp/releases/download/v1.0.3/alp_linux_amd64.zip
	unzip alp_linux_amd64.zip
	sudo mv alp /usr/local/bin/
	# slack_notify
	wget https://github.com/catatsuy/notify_slack/releases/download/v0.4.14/notify_slack-linux-amd64.tar.gz
	tar zxvf notify_slack-linux-amd64.tar.gz
	sudo mv notify_slack /usr/local/bin/

	rm -rf v3.5.5.tar.gz percona-toolkit-3.5.5 alp_linux_amd64.zip notify_slack-linux-amd64.tar.gz LICENSE README.md CHANGELOG.md

.PHONY: git-setup
git-setup:
	# git用の設定は適宜変更して良い
	git config --global user.email "isucon@example.com"
	git config --global user.name "isucon"

.PHONY: set-as-s1
set-as-s1:
	echo "" >> $(ENV_FILE)
	echo "SERVER_ID=s1" >> $(ENV_FILE)

.PHONY: set-as-s2
set-as-s2:
	echo "" >> $(ENV_FILE)
	echo "SERVER_ID=s2" >> $(ENV_FILE)

.PHONY: set-as-s3
set-as-s3:
	echo "" >> $(ENV_FILE)
	echo "SERVER_ID=s3" >> $(ENV_FILE)

.PHONY: get-db-conf
get-db-conf:
	mkdir -p /home/isucon/$(SERVER_ID)/etc
	mkdir -p /home/isucon/backup/etc
	sudo cp -r /etc/mysql /home/isucon/backup/etc
	sudo mkdir -p /home/isucon/$(SERVER_ID)/etc/mysql/conf.d
	sudo mkdir -p /home/isucon/$(SERVER_ID)/etc/mysql/mysql.conf.d
	sudo ln /etc/mysql/conf.d/mysql.cnf /home/isucon/$(SERVER_ID)/etc/mysql/conf.d/mysql.cnf
	sudo ln /etc/mysql/conf.d/mysqldump.cnf /home/isucon/$(SERVER_ID)/etc/mysql/conf.d/mysqldump.cnf
	sudo ln /etc/mysql/mysql.conf.d/mysql.cnf /home/isucon/$(SERVER_ID)/etc/mysql/mysql.conf.d/mysql.cnf
	sudo ln /etc/mysql/mysql.conf.d/mysqld.cnf /home/isucon/$(SERVER_ID)/etc/mysql/mysql.conf.d/mysqld.cnf
	sudo chmod 755 -R /home/isucon/$(SERVER_ID)/etc/mysql

.PHONY: get-nginx-conf
get-nginx-conf:
	mkdir -p /home/isucon/$(SERVER_ID)/etc
	mkdir -p /home/isucon/backup/etc
	cp -r /etc/nginx /home/isucon/backup/etc
	sudo mv /etc/nginx /home/isucon/$(SERVER_ID)/etc
	sudo ln -s /home/isucon/$(SERVER_ID)/etc/nginx /etc/nginx
	sudo chmod 775 -R /home/isucon/$(SERVER_ID)/etc/nginx

.PHONY: get-env
get-env:
	mkdir -p  ~/$(SERVER_ID)/home/isucon
	ln ~/$(ENV_FILE) ~/$(SERVER_ID)/home/isucon/$(ENV_FILE)

.PHONY: check-server-id
check-server-id:
ifdef SERVER_ID
	@echo "SERVER_ID=$(SERVER_ID)"
else
	@echo "SERVER_ID is unset"
	@exit 1
endif

.SILENT: mspec
mspec:
	(grep processor /proc/cpuinfo; free -m)

