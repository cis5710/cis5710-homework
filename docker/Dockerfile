FROM gradescope/autograder-base:ubuntu-22.04-jdk17 as base

# Set a build argument with a default value
# ARG BUILD_TYPE=base
# Use the build argument in your Dockerfile
#LABEL build_type=base

RUN apt-get update && apt-get install --yes sudo git
RUN apt-get install --yes python3-venv python3-pytest
RUN apt-get install --yes gcc-riscv64-unknown-elf device-tree-compiler
RUN pip install cocotb cocotb-bus
# deps for building Verilator
RUN apt-get install --yes help2man perl python3 make g++ libfl2 libfl-dev zlib1g zlib1g-dev perl-doc autoconf flex bison
WORKDIR /

# NB: Docker automagically extracts a local (not remote) tarball passed to the ADD command
# https://docs.docker.com/engine/reference/builder/#add
# COPY, however, just copies the tarball without extraction

# install verible
ADD https://github.com/chipsalliance/verible/releases/download/v0.0-3483-ga4d61b11/verible-v0.0-3483-ga4d61b11-linux-static-x86_64.tar.gz /
RUN tar xzf verible-v0.0-3483-ga4d61b11-linux-static-x86_64.tar.gz
RUN cp /verible-v0.0-3483-ga4d61b11/bin/verible-* /usr/bin/
RUN rm -rf /verible-v0.0-3483-ga4d61b11/

# install spike RISC-V ISA simulator
ADD https://launchpad.net/~jaxvanyang/+archive/ubuntu/spike/+files/spike_1.1.0-3_amd64.deb /
RUN dpkg -i /spike_1.1.0-3_amd64.deb
# NB: couldn't get the PPA setup correctly, maybe because it's for Lunar, not Jammy?
# tried to override in /etc/apt/sources.list with `deb [trusted=yes] https://ppa.launchpadcontent.net/jaxvanyang/spike/ubuntu lunar main` but that didn't work either
#RUN add-apt-repository "ppa:jaxvanyang/spike"
#RUN apt update # <-- fails here
#RUN apt-get install --yes spike

# build Verilator
WORKDIR /tmp
RUN git clone https://github.com/verilator/verilator
WORKDIR /tmp/verilator
RUN git checkout v5.018
RUN autoconf
RUN ./configure
RUN make -j4
RUN make install
WORKDIR /
RUN rm -rf /tmp/verilator

# Create a non-root user named `penn` with sudo privileges, and switch to them
RUN useradd -m -s /bin/bash penn && echo 'penn ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/penn
USER penn
WORKDIR /home/penn


# The "full" image is much larger, and contains the Yosys OSS CAD Suite of formal tools.
# TODO: add Vivado?
FROM base as full

# install Yosys OSS CAD Suite
RUN mkdir /tools
ADD https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2024-01-20/oss-cad-suite-linux-x64-20240120.tgz /
RUN tar xzf oss-cad-suite-linux-x64-20240120.tgz -C /tools/
RUN rm /oss-cad-suite-linux-x64-20240120.tgz

# Create a non-root user named `penn` with sudo privileges, and switch to them
# NB: replicated from base image
RUN useradd -m -s /bin/bash penn && echo 'penn ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/penn
USER penn
WORKDIR /home/penn
