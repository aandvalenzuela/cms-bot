FROM cmssw/el8:x86_64-buildtime
RUN dnf --enablerepo=powertools install -y popt-devel nspr-devel nss-devel \
    gettext-devel python3-devel cmake bison bison-devel && \
    dnf clean all
