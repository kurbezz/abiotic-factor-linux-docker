FROM ubuntu:24.04

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    echo steam steam/question select "I AGREE" | debconf-set-selections && \
    echo steam steam/license note '' | debconf-set-selections && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y wine64 steamcmd curl dos2unix && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="$PATH:/usr/games"
ENV UsePerfThreads=true
ENV NoAsyncLoadingThread=true
ENV AutoUpdate=true

WORKDIR /steamcmd

COPY ./entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh
ENTRYPOINT ["bash", "/entrypoint.sh"]
