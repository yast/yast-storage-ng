FROM yastdevel/storage-ng
RUN zypper --gpg-auto-import-keys --non-interactive in yast2-partitioner
COPY . /usr/src/app

