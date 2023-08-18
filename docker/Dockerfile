FROM @BASE_IMAGE_NAME@
RUN dnf --enablerepo=powertools install -y popt-devel nspr-devel nss-devel \
        gettext-devel python3-devel cmake bison bison-devel && \
    dnf clean all
