FROM archlinux/base

RUN pacman -Sy --noconfirm shards crystal imagemagick librsvg \
    which pkgconf gcc ttf-liberation
# base-devel contains many other basic packages, that are normally assumed to already exist on a clean arch system

ADD . /invidious

WORKDIR /invidious

RUN sed -i 's/host: localhost/host: postgres/' config/config.yml && \
    shards && \
    crystal build src/invidious.cr

CMD [ "/invidious/invidious" ]
