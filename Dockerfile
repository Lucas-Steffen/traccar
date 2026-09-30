# syntax=docker/dockerfile:1
#
# Builds Traccar directly from source (this fork), instead of downloading the
# official pre-built release zip. Meant for EasyPanel (or any Git-based
# build) pointed at this repository.
#
# The traccar-web frontend is NOT read from the git submodule checkout -
# it's cloned fresh from WEB_REPO/WEB_REF below. This avoids depending on
# whether the build platform initializes git submodules recursively.
# Override the build args if you fork/rename traccar-web again.

ARG WEB_REPO=https://github.com/VFPAR/traccar-web.git
ARG WEB_REF=feat/micodus-integration

# ---- Stage 1: build the Java server (this repo) ----
FROM eclipse-temurin:25 AS server-build
WORKDIR /src
COPY . .
RUN chmod +x ./gradlew && ./gradlew assemble --no-daemon

# ---- Stage 2: build the web UI (separate clone, not the submodule checkout) ----
FROM node:22 AS web-build
ARG WEB_REPO
ARG WEB_REF
WORKDIR /src
RUN git clone --branch "$WEB_REF" --depth 1 "$WEB_REPO" . \
    && npm ci \
    && npm run build

# ---- Stage 3: stage the release payload (mirrors the official out/ layout) ----
FROM alpine AS stage
WORKDIR /out
COPY --from=server-build /src/target/tracker-server.jar ./
COPY --from=server-build /src/target/lib/ ./lib/
COPY --from=server-build /src/schema/ ./schema/
COPY --from=server-build /src/templates/ ./templates/
COPY --from=server-build /src/setup/traccar.xml ./conf/traccar.xml
COPY --from=web-build /src/build/ ./web/
COPY --from=web-build /src/src/resources/l10n/ ./templates/translations/
RUN mkdir -p ./data ./logs

# ---- Stage 4: slim JRE (same as docker/Dockerfile.alpine) ----
FROM eclipse-temurin:25-alpine AS jdk
RUN jlink --add-modules java.se,jdk.charsets,jdk.crypto.ec,jdk.net,jdk.unsupported \
    --strip-debug --no-header-files --no-man-pages --compress=2 --output /jre

# ---- Stage 5: final runtime image ----
FROM alpine
COPY --from=stage /out /opt/traccar
COPY --from=jdk /jre /opt/traccar/jre
WORKDIR /opt/traccar
EXPOSE 8082
VOLUME ["/opt/traccar/data", "/opt/traccar/logs"]
ENTRYPOINT ["/opt/traccar/jre/bin/java", "-XX:+ExitOnOutOfMemoryError"]
CMD ["-jar", "tracker-server.jar", "conf/traccar.xml"]
