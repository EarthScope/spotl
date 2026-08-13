# Builds SPOTL (Some Programs for Ocean-Tide Loading, D.C. Agnew/Scripps)
# from the upstream source tarball: https://igppweb.ucsd.edu/~agnew/Spotl/spotlmain.html

ARG BUILDER_IMAGE=ubuntu:22.04
ARG RUNTIME_IMAGE=${BUILDER_IMAGE}

# ---- Build stage -----------------------------------------------------------
FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gfortran \
        gcc \
        make \
        wget \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

ARG SPOTL_URL=https://igppweb.ucsd.edu/~agnew/Spotl/spotl.tar.gz

# Separate RUN layers from here on: this is a multi-stage build and only
# /opt/spotl is copied into the runtime image, so extra builder layers cost
# nothing in the final image -- and they mean changing a compiler flag doesn't
# re-download 200MB+ of tarball.
RUN wget -q "$SPOTL_URL" -O spotl.tar.gz \
    && tar -xzf spotl.tar.gz \
    && rm spotl.tar.gz

# Build SPOTL
ARG FFLAGS="-O3 -Wuninitialized -fno-f2c -fno-automatic -fno-range-check -fno-backslash -fallow-argument-mismatch"
RUN cd /opt/spotl/src \
    && make all \
        FTN=gfortran \
        FFLAGS="$FFLAGS" \
        CC=/usr/bin/gcc \
        CFLAGS=-c \
    && ls -l ../bin

# install.rest converts the ASCII tide models and land-sea database to local
# binary form. Three BSD-isms/portability fixes are needed first:
#   * gzcat -> gunzip -c          (gzcat is BSD; not present on Ubuntu)
#   * Tobinary -> ./Tobinary      (not on PATH)
#   * rm -> rm -f                 (install.rest rm's files that don't exist
#                                   yet on a fresh tree)
RUN cd /opt/spotl/tidmod/ascii \
    && sed -i 's/gzcat/gunzip -c/g' Tobinary \
    && cd /opt/spotl \
    && sed -i 's|^Tobinary$|./Tobinary|; s/gzcat/gunzip -c/g; s/^rm /rm -f /' install.rest \
    && ./install.rest

# The stock example scripts hardcode a 'spotl/' path prefix that doesn't match
# this layout, and ex5.scr invokes itself without './'.
RUN cd /opt/spotl/working/Exampl/ \
    && for f in ex1.scr ex2.scr ex3.scr ex4.scr ex5.scr ex6.scr; do \
        sed -i 's/spotl//g' "$f"; \
        done \
    && sed -i 's/ex5.scr/.\/ex5.scr/g' ex5.scr

RUN mkdir -p /opt/spotl/results

COPY working /opt/spotl/working/

# ---- Runtime stage ---------------------------------------------------------
FROM ${RUNTIME_IMAGE} AS runtime

# libgfortran5 is the only runtime dependency of the compiled binaries.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgfortran5 ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash spotl

COPY --from=builder --chown=spotl:spotl /opt/spotl /opt/spotl
RUN mkdir -p /opt/spotl/results && chown spotl:spotl /opt/spotl/results

ENV PATH="/opt/spotl/bin:/opt/spotl/working:${PATH}"

USER spotl
WORKDIR /opt/spotl/working

CMD ["echo", "enter 'docker run -it <image> /bin/bash' to access interactive terminal"]
