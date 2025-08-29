# Minecraft Infrastructure on Kubernetes

A complete, production-ready Minecraft server infrastructure deployed on Kubernetes using modern best practices.

## 🏗️ Architecture

- **Velocity Proxy**: Minecraft proxy server with NodePort service for stable external access
- **Purpur Server**: High-performance Minecraft server implementation
- **PostgreSQL**: Persistent database for player data and economy
- **Redis**: High-performance cache and session storage
- **Economy API**: Microservice for in-game economy management
- **Local Registry**: Docker registry for custom images

## ✨ Features

- **No Port-Forward**: Uses NodePort service for automatic external access
- **Automatic Recovery**: Kubernetes handles pod restarts and scaling
- **Persistent Storage**: Data survives pod restarts and deployments
- **Plugin Support**: Automatic plugin deployment and updates
- **Economy System**: Built-in economy API with Redis caching
- **Production Ready**: Follows Kubernetes best practices

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (OrbStack, minikube, or cloud provider)
- `kubectl` configured and connected to cluster
- `helm` installed
- Internet access for image downloads

### Deployment

```bash
# Deploy entire infrastructure
./deploy.sh

# Clean up all deployments
./deploy.sh --cleanup

# Show help
./deploy.sh --help
```

### Connection

After deployment, connect to your Minecraft server at:
```
localhost:30000
```

The port 30000 is fixed and won't change between deployments.

## 📁 Project Structure

```
repo/
├── deploy.sh                 # Main deployment script
├── upload-plugin.sh          # Plugin deployment script
├── deploy-economy-api.sh     # Economy API deployment
├── dev-economy-api.sh        # Development workflow
├── helm/                     # Helm charts
│   ├── velocity/            # Velocity proxy chart
│   ├── purpur-shard/        # Purpur server chart
│   ├── postgres/            # PostgreSQL chart
│   ├── redis/               # Redis chart
│   └── registry/            # Local Docker registry
├── plugin/                   # Minecraft plugin source
│   └── purpur-plugin/       # Economy plugin
└── services/                 # Microservices
    └── economy-api/          # Economy API service
```

## 🛠️ Scripts Overview

### Core Scripts

#### `deploy.sh` - Main Deployment Script
**Purpose**: Deploys entire Minecraft infrastructure on Kubernetes
**Features**:
- Creates namespace and all components
- Deploys PostgreSQL, Redis, Velocity, Purpur
- Installs plugin and economy-api
- Configures NodePort service for external access
- Provides cleanup functionality

**Usage**:
```bash
./deploy.sh              # Deploy infrastructure
./deploy.sh --cleanup    # Remove all deployments
./deploy.sh --help       # Show help
```

#### `upload-plugin.sh` - Plugin Deployment Script
**Purpose**: Builds and deploys Minecraft plugin to Purpur server
**Features**:
- Maven compilation and packaging
- Automatic plugin upload to server pod
- Pod restart for plugin activation
- Plugin functionality verification

**Usage**:
```bash
./upload-plugin.sh        # Build and deploy plugin
```

#### `deploy-economy-api.sh` - Production Deployment
**Purpose**: Simple, reliable deployment for production use
**Features**:
- Maven compilation and Docker image building
- Image push to local registry
- Kubernetes deployment creation/update
- Basic health check verification
- Simple and reliable workflow

**Usage**:
```bash
./deploy-economy-api.sh           # Deploy economy-api
./deploy-economy-api.sh --force   # Force redeployment
```

**When to use**: Production deployments, CI/CD pipelines, simple updates

#### `dev-economy-api.sh` - Development Workflow
**Purpose**: Full development cycle with automation and monitoring
**Features**:
- Multiple operation modes (build, docker, deploy, watch, health, logs)
- Automatic file watching and hot reload
- Comprehensive health monitoring
- Log monitoring and debugging
- Development environment management

**Usage**:
```bash
./dev-economy-api.sh --deploy     # Build and deploy
./dev-economy-api.sh --watch      # Auto-reload on file changes
./dev-economy-api.sh --health     # Check API health
./dev-economy-api.sh --logs       # Monitor logs
./dev-economy-api.sh --help       # Show all options
```

**When to use**: Active development, debugging, testing, continuous development workflow

### **Script Selection Guide**

| Use Case | Recommended Script | Why |
|----------|-------------------|-----|
| **Production deployment** | `deploy-economy-api.sh` | Simple, reliable, production-ready |
| **CI/CD pipeline** | `deploy-economy-api.sh` | Minimal dependencies, predictable |
| **Initial infrastructure** | `deploy.sh` (calls `deploy-economy-api.sh`) | Automated full deployment |
| **Active development** | `dev-economy-api.sh --watch` | Auto-reload, comprehensive monitoring |
| **Debugging issues** | `dev-economy-api.sh --logs` | Real-time log monitoring |
| **Health checks** | `dev-economy-api.sh --health` | Detailed health information |
| **Quick testing** | `dev-economy-api.sh --deploy` | Fast build and deploy cycle |

### **Deployment Flow**

```
deploy.sh (Main Infrastructure)
    ├── PostgreSQL, Redis, Velocity, Purpur
    ├── Plugin installation (upload-plugin.sh)
    └── Economy API (deploy-economy-api.sh) ← Production deployment
```

**Note**: `deploy.sh` uses `deploy-economy-api.sh` for production deployment, not `dev-economy-api.sh`

### **Error Handling**

- **If economy-api deployment fails**: `deploy.sh` shows warning but continues
- **Manual recovery**: Run `./deploy-economy-api.sh` manually
- **Development mode**: Use `./dev-economy-api.sh --deploy` for active development

## 🔧 Components

### Velocity Proxy
- **Type**: NodePort Service
- **Port**: 30000 (external), 25565 (internal)
- **Features**: Player forwarding, modern protocol support
- **Access**: `localhost:30000`

### Purpur Server
- **Type**: Internal ClusterIP
- **Port**: 25565
- **Features**: Plugin support, performance optimizations
- **Storage**: Persistent volume for world data

### Economy API
- **Type**: Internal ClusterIP
- **Port**: 8080
- **Features**: Player wallet management, Redis caching
- **Database**: PostgreSQL integration

## 🎮 Plugin System

The infrastructure includes a custom economy plugin that:
- Creates player wallets on first join
- Provides `/balance` command
- Integrates with Economy API
- Uses Redis for caching

### Plugin Commands
- `/balance` - Check your balance
- Automatic wallet creation on join

## 🗄️ Data Persistence

- **World Data**: Stored in persistent volumes
- **Player Data**: Stored in PostgreSQL
- **Cache**: Redis for performance optimization
- **Backups**: Kubernetes handles volume management

## 🔄 Development Workflow

### Update Plugin
```bash
./upload-plugin.sh
```

### Update Economy API
```bash
./dev-economy-api.sh --deploy
```

### View Logs
```bash
# Velocity logs
kubectl logs -n minecraft -l app.kubernetes.io/name=velocity

# Purpur logs
kubectl logs -n minecraft -l app.kubernetes.io/name=purpur-shard

# Economy API logs
kubectl logs -n minecraft -l app.kubernetes.io/name=economy-api
```


## Troubleshooting

### Can't Connect to Server
1. Check if pods are running: `kubectl get pods -n minecraft`
2. Verify service status: `kubectl get svc -n minecraft`
3. Check logs for errors: `kubectl logs -n minecraft -l app.kubernetes.io/name=velocity`

### Plugin Not Working
1. Verify plugin installation: `./upload-plugin.sh`
2. Check plugin logs in Purpur
3. Ensure Economy API is running

### Database Issues
1. Check PostgreSQL pod status
2. Verify database connectivity
3. Check init scripts in Helm chart

## 🧹 Cleanup Notes

**Removed Files** (no longer needed):
- `port-forward.log` - Port-forwarding logs (anti-pattern)
- `velocity.toml` - Velocity config (now managed by Helm)
- `forwarding.secret` - Secret file (now managed by Helm)
- `.port-forward.pid` - Port-forward PID file (anti-pattern)

**Why Removed**:
- Port-forwarding is an anti-pattern for production
- Configuration files are now managed by Helm charts
- Secrets are handled by Kubernetes secrets
- PID files are not needed with proper service architecture

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Velocity Documentation](https://docs.papermc.io/velocity/)
- [Purpur Documentation](https://purpurmc.org/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `./deploy.sh --cleanup && ./deploy.sh`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
