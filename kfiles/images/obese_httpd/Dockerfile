FROM httpd:2.4
RUN apt-get update && apt-get install -y python-is-python3 python3 git && \
    rm -rf /var/lib/apt/lists/* \
    && apt-get clean
WORKDIR /
RUN git clone https://github.com/per9000/lorem
ENV PATH="/lorem:${PATH}"
RUN mkdir -p /usr/local/apache2/htdocs/public-html
COPY sample-foot.html /usr/local/apache2/htdocs/public-html
COPY sample-head.html /usr/local/apache2/htdocs/public-html
WORKDIR /usr/local/apache2/htdocs/public-html
RUN cat sample-head.html > index.html && \
    lorem -c 500000 >> index.html && \
    cat sample-foot.html >> index.html
