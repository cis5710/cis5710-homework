FROM gradescope/autograder-base:ubuntu-22.04-jdk17 AS base

# Set a build argument with a default value
# ARG BUILD_TYPE=base
# Use the build argument in your Dockerfile
#LABEL build_type=base

RUN apt-get update
RUN apt-get install --yes sudo git zip tmux emacs time
RUN apt-get install --yes gcc-riscv64-unknown-elf device-tree-compiler

# NB: Docker automagically extracts a local (not remote) tarball passed to the ADD command
# https://docs.docker.com/engine/reference/builder/#add
# COPY, however, just copies the tarball without extraction

# install verible
ADD https://github.com/chipsalliance/verible/releases/download/v0.0-3483-ga4d61b11/verible-v0.0-3483-ga4d61b11-linux-static-x86_64.tar.gz /
RUN tar xzf /verible-v0.0-3483-ga4d61b11-linux-static-x86_64.tar.gz
RUN cp /verible-v0.0-3483-ga4d61b11/bin/verible-* /usr/bin/
RUN rm -rf /verible-*/
RUN rm /verible-*.tar.gz

# install spike RISC-V ISA simulator
ADD https://launchpad.net/~jaxvanyang/+archive/ubuntu/spike/+files/spike_1.1.0-3_amd64.deb /
RUN dpkg -i /spike_1.1.0-3_amd64.deb
RUN rm /spike_1.1.0-3_amd64.deb
# NB: couldn't get the PPA setup correctly, maybe because it's for Lunar, not Jammy?
# tried to override in /etc/apt/sources.list with `deb [trusted=yes] https://ppa.launchpadcontent.net/jaxvanyang/spike/ubuntu lunar main` but that didn't work either
#RUN add-apt-repository "ppa:jaxvanyang/spike"
#RUN apt update # <-- fails here
#RUN apt-get install --yes spike

# Create a non-root user named `penn` with sudo privileges, and switch to them
RUN useradd -m -s /bin/bash penn && echo 'penn ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/penn
USER penn

# install Yosys OSS CAD Suite
# brings verilator, cocotb, nextpnr-ecp5, yosys, openFPGALoader
RUN sudo mkdir /tools
RUN sudo chown penn /tools
ADD https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2025-01-08/oss-cad-suite-linux-x64-20250108.tgz /tmp
RUN sudo chown penn /tmp/oss-cad-suite-*.tgz
RUN tar xzf /tmp/oss-cad-suite-*.tgz -C /tools
RUN rm /tmp/oss-cad-suite-*.tgz

# download sv2v binary
ADD https://github.com/zachjs/sv2v/releases/download/v0.0.12/sv2v-Linux.zip /tmp
WORKDIR /tmp
RUN sudo chown penn sv2v-Linux.zip
RUN sudo unzip sv2v-Linux.zip
RUN sudo cp sv2v-Linux/sv2v /tools/oss-cad-suite/bin/
RUN sudo chown penn /tools/oss-cad-suite/bin/sv2v
RUN sudo rm -rf /tmp/sv2v-Linux*

# add pytest script
ADD pytest /tools/oss-cad-suite/bin/
RUN sudo chmod 755 /tools/oss-cad-suite/bin/pytest
RUN sudo chown penn /tools/oss-cad-suite/bin/pytest

ENV PATH="$PATH:/tools/oss-cad-suite/bin"
WORKDIR /tools/oss-cad-suite
RUN bash -c "source environment && pip3 install git+https://github.com/cis5710/cocotbext-axi.git"
WORKDIR /home/penn
RUN echo "source /tools/oss-cad-suite/environment" >> /home/penn/.bashrc

# sanity checks
RUN which verible-verilog-syntax
RUN which spike
RUN which verilator
RUN which pytest
RUN which nextpnr-ecp5
RUN which sv2v
RUN which yosys
RUN which openFPGALoader
RUN bash -c "source /tools/oss-cad-suite/environment && python3 -c 'import cocotb, cocotbext.axi'"

CMD ["/bin/bash"]
