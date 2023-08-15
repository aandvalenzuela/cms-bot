FROM library/almalinux:8
RUN dnf install -y git
RUN dnf --enablerepo=powertools install -y rpm-build && \
    dnf clean all
