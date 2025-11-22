# Owncast avec support Intel VAAPI/QSV

Image Docker custom d'[Owncast](https://owncast.online/) avec support de l'accélération matérielle Intel VAAPI/QSV pour les GPU Intel Arc (A310, A380, A770, etc.) et autres GPU Intel récents.

## Pourquoi cette image ?

L'image officielle `owncast/owncast:latest` ne contient pas les pilotes VAAPI nécessaires pour l'encodage hardware avec les GPU Intel. Cette image ajoute tous les pilotes requis pour exploiter pleinement votre carte graphique Intel Arc lors du streaming.

## GPU supportés

- **Intel Arc** (A310, A380, A770) - Recommandé
- Intel Iris Xe (11e gen et supérieur)
- Intel UHD Graphics (11e gen et supérieur)
- Anciens GPU Intel (avec pilote i965)

## Prérequis

### Matériel
- Un GPU Intel compatible VAAPI
- Système Linux avec kernel 5.15+ (recommandé 6.0+ pour Intel Arc)

### Logiciels
- Docker et Docker Compose installés
- Pilotes Intel installés sur le système hôte :
  ```bash
  # Vérifier que votre GPU est détecté
  ls -la /dev/dri

  # Installer les pilotes sur l'hôte (exemple Ubuntu/Debian)
  sudo apt install intel-media-va-driver vainfo

  # Vérifier que VAAPI fonctionne sur l'hôte
  vainfo
  ```

### Permissions
Vérifier les GIDs des groupes `video` et `render` sur votre système :
```bash
getent group video render
```

Si les GIDs sont différents de 44 (video) et 109 (render), modifiez le `docker-compose.yaml` en conséquence.

## Installation

### Option 1 : Utiliser l'image pré-buildée (recommandé)

```bash
# Cloner ce repo
git clone https://github.com/chomiam/owncast-intel-vaapi.git
cd owncast-intel-vaapi

# Modifier docker-compose.yaml pour utiliser l'image pré-buildée
# Décommenter la ligne: image: ghcr.io/chomiam/owncast-intel-vaapi:latest
# Commenter la section: build:

# Lancer le conteneur
docker compose up -d
```

### Option 2 : Builder l'image localement

```bash
# Cloner ce repo
git clone https://github.com/chomiam/owncast-intel-vaapi.git
cd owncast-intel-vaapi

# Builder et lancer
docker compose up -d --build
```

## Utilisation

### Démarrage
```bash
docker compose up -d
```

### Vérifier que VAAPI fonctionne
```bash
# Vérifier les logs
docker compose logs owncast

# Tester VAAPI dans le conteneur
docker compose exec owncast vainfo
```

Vous devriez voir une liste de profils VAProfile supportés. Si vous voyez `VAProfileH264Main`, `VAProfileHEVCMain`, etc., c'est bon !

### Accéder à l'interface web
Ouvrez votre navigateur : `http://localhost:8080`

### Configuration d'Owncast pour utiliser l'accélération hardware

1. Connectez-vous à l'interface admin d'Owncast
2. Allez dans **Configuration** → **Video**
3. Modifiez vos paramètres de stream pour utiliser VAAPI :

#### Exemple de configuration FFmpeg avec VAAPI :

Pour l'encodage H.264 avec QSV :
```
-vaapi_device /dev/dri/renderD128 -hwaccel vaapi -hwaccel_output_format vaapi -i [INPUT] -vf 'format=nv12|vaapi,hwupload' -c:v h264_vaapi -b:v 3000k -maxrate 3500k -bufsize 6000k -c:a copy
```

Pour l'encodage H.265/HEVC avec QSV (plus efficace sur Intel Arc) :
```
-vaapi_device /dev/dri/renderD128 -hwaccel vaapi -hwaccel_output_format vaapi -i [INPUT] -vf 'format=nv12|vaapi,hwupload' -c:v hevc_vaapi -b:v 2500k -maxrate 3000k -bufsize 5000k -c:a copy
```

#### Variables de qualité recommandées par résolution :

**1080p60 (H.264)** :
- Bitrate: 4500-6000k
- Maxrate: 6500-8000k
- Bufsize: 9000-12000k

**1080p60 (H.265)** :
- Bitrate: 3000-4000k
- Maxrate: 4500-5500k
- Bufsize: 6000-8000k

**720p60 (H.264)** :
- Bitrate: 2500-3500k
- Maxrate: 3500-4500k
- Bufsize: 5000-7000k

### Arrêt
```bash
docker compose down
```

### Mise à jour
```bash
# Avec l'image pré-buildée
docker compose pull
docker compose up -d

# Avec le build local
git pull
docker compose up -d --build
```

## Structure du projet

```
.
├── Dockerfile              # Image Docker custom avec pilotes VAAPI
├── docker-compose.yaml     # Configuration Docker Compose
├── README.md              # Ce fichier
├── .dockerignore          # Fichiers à exclure du build
└── data/                  # Données Owncast (créé au premier lancement)
```

## Troubleshooting

### Le GPU n'est pas détecté

1. Vérifier que `/dev/dri` existe sur l'hôte :
   ```bash
   ls -la /dev/dri
   ```

2. Vérifier les permissions :
   ```bash
   # Ajouter votre utilisateur aux groupes video et render
   sudo usermod -aG video,render $USER
   # Redémarrer la session
   ```

3. Vérifier les GIDs dans docker-compose.yaml

### VAAPI ne fonctionne pas dans le conteneur

1. Tester VAAPI :
   ```bash
   docker compose exec owncast vainfo
   ```

2. Activer les logs VAAPI :
   ```bash
   # Modifier docker-compose.yaml
   environment:
     - LIBVA_DRIVER_NAME=iHD
     - LIBVA_MESSAGING_LEVEL=1

   # Redémarrer
   docker compose down && docker compose up -d
   ```

3. Pour les anciens GPU Intel, essayer le pilote i965 :
   ```bash
   # Modifier docker-compose.yaml
   environment:
     - LIBVA_DRIVER_NAME=i965
   ```

### Encodage toujours en CPU

1. Vérifier que les arguments FFmpeg sont corrects (voir section Configuration)
2. Vérifier les logs Owncast pour les erreurs FFmpeg
3. S'assurer que le codec est supporté par votre GPU (voir `vainfo`)

### Performance médiocre

1. Vérifier que le GPU n'est pas partagé avec un affichage graphique
2. Monitorer l'utilisation GPU :
   ```bash
   # Sur l'hôte
   intel_gpu_top

   # Ou
   sudo apt install intel-gpu-tools
   sudo intel_gpu_top
   ```

3. Ajuster les paramètres de bitrate/qualité

## Variables d'environnement

| Variable | Valeur par défaut | Description |
|----------|------------------|-------------|
| `LIBVA_DRIVER_NAME` | `iHD` | Pilote VAAPI à utiliser (`iHD` pour Intel Arc/récent, `i965` pour ancien) |
| `LIBVA_MESSAGING_LEVEL` | - | Niveau de log VAAPI (0-2, optionnel) |
| `LIBVA_TRACE` | - | Fichier de trace VAAPI (pour debug uniquement) |

## Build et publication de l'image

### Build manuel
```bash
docker build -t owncast-intel-vaapi:latest .
```

### Tag et push vers GitHub Container Registry
```bash
# Tag
docker tag owncast-intel-vaapi:latest ghcr.io/chomiam/owncast-intel-vaapi:latest

# Login à GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u chomiam --password-stdin

# Push
docker push ghcr.io/chomiam/owncast-intel-vaapi:latest
```

### Auto-build avec GitHub Actions
Ce repo inclut un workflow GitHub Actions qui build et publie automatiquement l'image à chaque push sur `main` et à chaque tag. Voir `.github/workflows/docker-build.yml`.

## Contribution

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou une pull request.

## Licence

MIT - Voir le fichier LICENSE

## Ressources

- [Owncast officiel](https://owncast.online/)
- [Documentation VAAPI](https://wiki.archlinux.org/title/Hardware_video_acceleration)
- [Intel Media Driver](https://github.com/intel/media-driver)
- [FFmpeg VAAPI](https://trac.ffmpeg.org/wiki/Hardware/VAAPI)

## Crédits

Basé sur l'image officielle [owncast/owncast](https://hub.docker.com/r/owncast/owncast)
