# Use Debian Bookworm as the base image, a modern stable release.
FROM debian:bullseye-20251208-slim

# The shell in Debian is 'sh' by default.

# Add application files early
ADD ./start.sh /start.sh
ADD ./config.ini /config.ini
ADD ./requirements.txt /requirements.txt
COPY dependencies.json /tmp/dependencies.json

# Create the data directory
RUN mkdir /data

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core build tools (replaces apk's gcc, python3-dev, musl-dev, linux-headers)
    build-essential \
    python3-dev \
    # Other runtime dependencies
    jq \
    python3-pip \
    curl \
    # NEW DEBIAN PACKAGES REQUIRED BY start.sh:
    bridge-utils \
    iproute2 \
    iptables \
    dnsmasq \
    docker.io \
    # Clean up apt lists to keep the image size down
    && rm -rf /var/lib/apt/lists/*

# Install Python requirements
# The --break-system-packages flag is specific to modern Debian/Ubuntu Python policies.
# We no longer need the complex jq/xargs line from the Alpine version, 
# as we assume primary dependencies are listed in requirements.txt.
#RUN sed -i 's/^Components: main$/& contrib non-free/' /etc/apt/sources.list.d/debian.sources.list
RUN sed -i 's/main/main contrib non-free/g' /etc/apt/sources.list
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core build tools (replaces apk's gcc, python3-dev, musl-dev, linux-header>
    dynamips \
    cpulimit dnsmasq  qemu-system-x86 qemu-utils tigervnc-standalone-server util-linux vpcs \
    git \
    libpcap-dev \
    # libcap-dev is the correct dev package name for libcap utilities
    libcap-dev \
    # Clean up apt lists to keep the image size down
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/GNS3/ubridge.git /usr/local/src/ubridge && \
    cd /usr/local/src/ubridge && \
    make && \
    make install

RUN ln -s /usr/local/bin/ubridge /usr/bin/ubridge

RUN  dpkg --add-architecture i386 && \
	apt update && \
     apt install -y wget libc6:i386 libstdc++6:i386 libssl1.1:i386 && \

     rm -rf /var/lib/apt/lists/*
RUN ln -s /usr/lib/i386-linux-gnu/libcrypto.so.1.1 /usr/lib/i386-linux-gnu/libcrypto.so.4		
#RUN pip install -r /requirements.txt --break-system-packages
RUN pip install -r /requirements.txt 

RUN git clone https://github.com/GNS3/vpcs.git \
  && cd vpcs/src \
  && ./mk.sh 64 \
  &&  mv vpcs /usr/bin/vpcs \
  && chmod +x /usr/bin/vpcs

RUN ln -s /bin/busybox  /usr/local/lib/python3.9/dist-packages/gns3server/compute/docker/resources/bin/busybox

# The GNS3 BusyBox workaround is unnecessary on Debian because Debian uses real symlinks 
# and standard system binaries, not BusyBox.

# Set the working directory and volume
WORKDIR /data
VOLUME ["/data"]

# Set the entry point
CMD [ "/start.sh" ]
