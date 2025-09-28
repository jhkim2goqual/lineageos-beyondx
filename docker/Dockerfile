FROM ubuntu:20.04

LABEL maintainer="junghanacs"
LABEL description="LineageOS build environment for Samsung Galaxy S10 5G (beyondx)"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Seoul \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Create builder user to avoid running as root
RUN useradd -m -s /bin/bash builder && \
    echo 'builder ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Update and install base packages
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    wget \
    git \
    git-lfs \
    gnupg \
    locales \
    software-properties-common \
    tzdata \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Install build dependencies as per LineageOS requirements
RUN apt-get update && apt-get install -y \
    bc \
    bison \
    build-essential \
    ccache \
    curl \
    flex \
    g++-multilib \
    gcc-multilib \
    git \
    git-lfs \
    gnupg \
    gperf \
    imagemagick \
    lib32ncurses5-dev \
    lib32readline-dev \
    lib32z1-dev \
    libelf-dev \
    libdw-dev \
    liblz4-tool \
    libncurses5 \
    libncurses5-dev \
    libsdl1.2-dev \
    libssl-dev \
    libxml2 \
    libxml2-utils \
    lzop \
    pngcrush \
    rsync \
    schedtool \
    squashfs-tools \
    xsltproc \
    zip \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3 and set as default
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-protobuf \
    protobuf-compiler \
    python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

# Install OpenJDK 11 (required for LineageOS 18.1+)
RUN apt-get update && apt-get install -y \
    openjdk-11-jdk \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    PATH=$JAVA_HOME/bin:$PATH

# Install platform-tools (adb, fastboot)
RUN mkdir -p /opt/platform-tools && \
    cd /opt/platform-tools && \
    wget -q https://dl.google.com/android/repository/platform-tools-latest-linux.zip && \
    unzip -q platform-tools-latest-linux.zip && \
    rm platform-tools-latest-linux.zip && \
    ln -s /opt/platform-tools/platform-tools/adb /usr/local/bin/adb && \
    ln -s /opt/platform-tools/platform-tools/fastboot /usr/local/bin/fastboot

# Install repo tool
RUN curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo

# Setup ccache
RUN echo "export USE_CCACHE=1" >> /etc/profile.d/ccache.sh && \
    echo "export CCACHE_EXEC=/usr/bin/ccache" >> /etc/profile.d/ccache.sh && \
    echo "export CCACHE_DIR=/home/builder/.ccache" >> /etc/profile.d/ccache.sh

# Configure git for repo
RUN git config --global user.email "builder@localhost" && \
    git config --global user.name "LineageOS Builder" && \
    git config --global trailer.changeid.key "Change-Id" && \
    git lfs install

# Switch to builder user
USER builder
WORKDIR /home/builder

# Setup environment directories
RUN mkdir -p ~/android/lineage && \
    mkdir -p ~/.ccache && \
    mkdir -p ~/bin && \
    mkdir -p ~/output

# Configure ccache for builder (50GB)
RUN ccache -M 50G && \
    ccache -o compression=true

# Add local bin to PATH
ENV PATH=/home/builder/bin:$PATH

# Set build environment variables
ENV USE_CCACHE=1 \
    CCACHE_EXEC=/usr/bin/ccache \
    CCACHE_DIR=/home/builder/.ccache \
    ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx16g"

# Copy and setup entrypoint script
COPY --chown=builder:builder entrypoint.sh /home/builder/
RUN chmod +x /home/builder/entrypoint.sh

# Default working directory
WORKDIR /home/builder/android/lineage

# Entry point
ENTRYPOINT ["/home/builder/entrypoint.sh"]
CMD ["/bin/bash"]