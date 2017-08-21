FROM centos:7
MAINTAINER Brian Ogden

# MySQL image
#
# Volumes:
#  * /var/lib/mysql - Datastore for MySQL
# Environment:
#  * $MYSQL_USER - Database user name
#  * $MYSQL_PASSWORD - User's password
#  * $MYSQL_DATABASE - Name of the database to create
#  * $MYSQL_ROOT_PASSWORD (Optional) - Password for the 'root' MySQL account

ENV MYSQL_VERSION=5.7

ENV SUMMARY="MySQL 5.7 SQL database server" \
    DESCRIPTION="MySQL is a multi-user, multi-threaded SQL database server. The container \
image provides a containerized packaging of the MySQL mysqld daemon and client application. \
The mysqld server daemon accepts connections from clients and provides access to content from \
MySQL databases on behalf of the clients."

RUN yum update -y && \
         yum clean all

RUN yum install -y \
    wget \
    epel-release && \
    yum clean all

#this package intermittently failed to install on 8-4-2017, the mirrors were all down in seemed, separated out for more precise error message
#if happens again
RUN yum install -y dpkg && \
	yum clean all

# add gosu for easy step-down from root
ENV GOSU_VERSION 1.10
RUN set -ex; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /tmp/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	\
# verify the signature
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 0xB42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /tmp/gosu.asc /usr/bin/gosu; \
	rm -r "$GNUPGHOME" /tmp/gosu.asc; \
	\
	chmod +x /usr/bin/gosu; \
# verify that the binary works
	gosu nobody true;

# Download and add MySQL Yum repository
RUN wget https://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm

# Install the downloaded package
RUN yum localinstall -y mysql57-community-release-el7-9.noarch.rpm

# Install MySQL 5.7
RUN yum install -y mysql-community-server


#remove packages only used for image init
RUN yum -y remove \ 
    dpkg \
    wget && \
	yum clean all

#setup mysql permissions - mysql user already exists,created with mysql-community-server install above
#RUN usermod -u 27 mysql #not needed, already uid 27

# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath 
#besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
RUN rm -rf /var/lib/mysql
RUN mkdir -p /var/lib/mysql /var/run/mysqld
RUN chown -R mysql:mysql /var/lib/mysql /var/run/mysqld
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
RUN chmod 777 /var/run/mysqld

#volume instead defined in docker-compose.yml files
#VOLUME ["/var/lib/mysql"]

COPY my.cnf /etc/my.cnf
COPY docker-entrypoint.sh /usr/bin/
RUN chown -R mysql:mysql /usr/bin
RUN chmod +x /usr/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["mysqld"]
