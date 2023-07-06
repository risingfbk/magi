FROM httpd:2.4
RUN apt-get update && apt-get install -y python3 git && \
    rm -rf /var/lib/apt/lists/* \
    && apt-get clean
WORKDIR /
RUN git clone git@github.com:per9000/lorem.git
ENV PATH="/lorem:${PATH}"
RUN mkdir -p /usr/local/apache2/htdocs/public-html
COPY sample-foot.html /usr/local/apache2/htdocs/public-html
COPY sample-head.html /usr/local/apache2/htdocs/public-html
WORKDIR /usr/local/apache2/htdocs/public-html
RUN cat sample-head.html > index.html && \
    lorem -p 1000 >> index.html && \
    cat sample-foot.html >> index.html
