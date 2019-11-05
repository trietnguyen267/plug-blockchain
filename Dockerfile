# Note: We don't use Alpine and its packaged Rust/Cargo because they're too often out of date,
# preventing them from being used to build Substrate/Polkadot/Plug.

FROM phusion/baseimage:0.10.2 as builder
LABEL description="Pl^g build image: The Pl^g binary is built here."

ENV DEBIAN_FRONTEND=noninteractive

ARG PROFILE=release
WORKDIR /plug

COPY . /plug

RUN apt-get update && \
	apt-get dist-upgrade -y -o Dpkg::Options::="--force-confold" && \
	apt-get install -y \
	clang \
	cmake \
	git \
	libssl-dev \
	pkg-config  

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y && \
	export PATH="$PATH:$HOME/.cargo/bin" && \
	rustup target add wasm32-unknown-unknown && \
	rustup toolchain install nightly && \
	rustup target add wasm32-unknown-unknown --toolchain nightly && \
	rustup default stable && \
	cargo build "--$PROFILE"

# ===== SECOND STAGE ======

FROM phusion/baseimage:0.10.2
LABEL description="Pl^g runner image: A minimal image for running Pl^g."
ARG PROFILE=release

RUN mv /usr/share/ca* /tmp && \
	rm -rf /usr/share/*  && \
	mv /tmp/ca-certificates /usr/share/ && \
	mkdir -p /root/.local/share/Polkadot && \
	ln -s /root/.local/share/Polkadot /data && \
	useradd -m -u 1000 -U -s /bin/sh -d /plug plug

COPY --from=builder /plug/target/$PROFILE/plug /usr/local/bin

# checks
RUN ldd /usr/local/bin/plug && \
	/usr/local/bin/plug --version

# Shrinking
RUN rm -rf /usr/lib/python* && \
	rm -rf /usr/bin /usr/sbin /usr/share/man

USER plug
EXPOSE 30333 9933 9944
VOLUME ["/data"]

CMD ["/usr/local/bin/plug"]
