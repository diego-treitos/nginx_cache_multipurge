FROM openresty/openresty:jammy AS builder

RUN apt-get update && apt-get install -y -q --no-install-recommends gcc make
RUN mkdir -p /code
COPY . /code
WORKDIR /code
RUN make