FROM owncast/owncast:latest

# Activer le repository community pour accéder aux pilotes VAAPI
# Décommenter ou ajouter la ligne community
RUN if grep -q "^#.*\/community$" /etc/apk/repositories; then \
        sed -i 's/^#\(.*\/community\)$/\1/' /etc/apk/repositories; \
    elif ! grep -q "\/community$" /etc/apk/repositories; then \
        echo "https://dl-cdn.alpinelinux.org/alpine/v3.22/community" >> /etc/apk/repositories; \
    fi

# Installer les pilotes VAAPI/QSV pour Intel Arc
# Note: Alpine Linux 3.22+ est requis pour un support complet d'Intel Arc
RUN apk update && apk add --no-cache \
    libva \
    libva-utils \
    libva-intel-driver \
    intel-media-driver \
    mesa-dri-gallium \
    mesa-va-gallium

# Définir le pilote VAAPI par défaut (iHD pour Intel Arc)
ENV LIBVA_DRIVER_NAME=iHD

# Labels pour metadata
LABEL org.opencontainers.image.title="Owncast with Intel VAAPI/QSV Support"
LABEL org.opencontainers.image.description="Owncast streaming server with Intel Arc GPU hardware acceleration support"
LABEL org.opencontainers.image.vendor="Community Build"
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="chomiam"

# Le reste de la configuration est hérité de l'image de base owncast/owncast:latest
# - Port exposé: 8080, 1935
# - Volume: /app/data
# - Workdir: /app
# - Entrypoint: défini dans l'image de base
