# Deployment and Setup Guide

This guide covers how to run the Voxel project locally and how to deploy it to production using **Render** (for the Go backend) and **Vercel** (for the Flutter web frontend).

---

## 🚀 Local Development

### 1. Backend (Go)
The backend requires a MongoDB connection. By default, it uses a pre-configured MongoDB Atlas URI, but you can override it using environment variables.

1. Navigate to the server directory:
   ```bash
   cd server
   ```
2. Start the server:
   ```bash
   go run cmd/api/main.go
   ```
   The server will start on `http://localhost:8080`.

### 2. Frontend (Flutter)
1. Ensure you have Flutter installed.
2. Navigate to the voxel directory:
   ```bash
   cd voxel
   ```
3. Fetch dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run -d chrome # For web
   # OR
   flutter run # For mobile (Android/iOS)
   ```

---

## 🌐 Backend Deployment (Render)

Render is ideal for hosting the Go backend.

1. **Connect Repository**: Create a new **Web Service** on Render and connect your GitHub repository.
2. **Configuration**:
   - **Environment**: `Go`
   - **Build Command**: `go build -o server_bin cmd/api/main.go`
   - **Start Command**: `./server_bin`
3. **Environment Variables**:
   Update these in the Render dashboard under **Environment**:
   - `MONGO_URI`: Your MongoDB connection string.
   - `PORT`: Leave as is (Render sets this automatically).
4. **Networking**: Render provides a public URL (e.g., `https://voxel-server.onrender.com`). Use this in your frontend configuration.

---

## 🎨 Frontend Deployment (Vercel)

Vercel is the best choice for hosting the Flutter Web build.

### Step 1: Build for Web
In the `voxel` directory, run:
```bash
flutter build web --release --dart-define=WS_URL=wss://your-render-url.onrender.com/ws
```

### Step 2: Deploy to Vercel
1. **Direct Upload**:
   - Install Vercel CLI: `npm i -g vercel`
   - Deploy from the build folder:
     ```bash
     cd build/web
     vercel --prod
     ```
2. **CI/CD (GitHub)**:
   - Connect your repo to Vercel.
   - Set the **Root Directory** to `voxel`.
   - Set the **Build Command**: `flutter build web --release`
   - Set the **Output Directory**: `build/web`
   - **Note**: You may need a Vercel [build image](https://vercel.com/docs/concepts/projects/environment-variables#system-environment-variables) that supports Flutter, or use a GitHub Action to build and deploy.

### Handling Client-Side Routing
Create a `vercel.json` file in `build/web` (or your root if using CI/CD) to handle SPA routing:
```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

---

## 🛠 Troubleshooting

- **CORS Issues**: The backend already includes a CORS middleware that allows all origins. If you restrict this, ensure your Vercel URL is added.
- **WebSocket URL**: Ensure you use `wss://` for production instead of `ws://` to comply with SSL requirements.
- **NGROK**: Use `ngrok http 8080` only for local testing. Always use the production URL for deployment.
