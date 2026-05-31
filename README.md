# Social App

A full-featured social networking application built with **Flutter** for the frontend and **Node.js** (Express & WebSockets) backed by a permanent **PostgreSQL** database for the backend.

---

## 🚀 Tech Stack

### Front-end (Client)
* **Framework**: [Flutter](https://flutter.dev/) (supports Mobile & Web targets)
* **State Management**: `Provider` & `MultiProvider`
* **Real-time Audio/Video Calls**: `WebRTC` (P2P and Group call implementations)
* **Media Processing**: Video playback via `video_player`, audio playback via `audioplayers`, and voice note recording via `record`.

### Back-end (Server)
* **Runtime**: [Node.js](https://nodejs.org/) with [Express](https://expressjs.com/)
* **Real-time Communication**: `WebSockets` via the `ws` package (handles instant messages, WebRTC call signaling, and administrative events)
* **File Uploads**: `Multer` (manages uploads for images, video posts, and audio files)
* **Security & Auth**: `JSON Web Tokens (JWT)` for route guards, and `bcrypt` for secure password hashing.

### Database & Infrastructure
* **Database**: [PostgreSQL](https://www.postgresql.org/) (runs inside a Docker container with permanent volume mapping)
* **Infrastructure Containers**: `Docker Compose` (spins up PostgreSQL and Redis services)
* **Connection Tunneling**: `ngrok` (tunnels the local Express/WebSocket server to HTTPS/WSS for physical device testing)

---

## ✨ Core Features

### 1. Social Feed & Posts (Feed Tab)
* Browse interactive post cards with attached images and playing video files.
* Instantly toggle likes with animated states and real-time counter updates.
* View and reply to comments in an interactive bottom sheet replies feed.

### 2. Full-Screen Short Videos (Video Tab)
* Scroll vertically through short video posts in a full-screen swipeable feed (TikTok-style layout).
* Automatic video playback and looping for the active video, with shortcuts for likes, comments, and reporting/hiding options.

### 3. Public User Profiles
* Tap on any user's avatar or username from any screen (Chat, Feed, Explore, or Video) to open their public profile screen.
* Displays verified statistics: total posts, follower count, and following count.
* Offers an interactive **Follow / Unfollow** toggle with flight-loading indicators.
* Displays a dedicated feed of posts created solely by the target user.
* Automatically displays an "Edit Profile" button instead of Follow/Unfollow when viewing your own profile.

### 4. Interactive Public Chat (Public Chat Tab)
* A WebSocket-powered group chat room supporting real-time text messages and voice notes.
* Directly reply to other users' messages (shows a reply preview block above the input bar).
* Initiate a video call invitation to any online user directly from their chat bubble.

### 5. Creators Search & Explore (Explore Tab)
* Search creators dynamically by keyword matching their username or bio.
* Filter users by selecting trending topics hashtags (e.g. `#Flutter`, `#WebRTC`).

### 6. Video Calling Screens
* Full WebRTC integration supporting 1v1 calls and multi-peer group video calls.

### 7. Administrative Controls & Root Admin Account
* Pre-seeded root administrator account available at:
  * **Email**: `admin@social.app`
  * **Username**: `المسئوول`
  * **Password**: `adminPass`
* Root administrators are granted cascading permissions:
  * Delete any post or short video.
  * Delete any public chat message.
  * Delete any user account.
  * Issue **Warnings** to users from the Explore list or User Profiles. When a user reaches **3 warnings**, the server automatically and permanently deletes their account, along with all of their posts, replies, and messages.
  * Admin-exclusive badges displaying warning counts (`Warnings: X/3`) are rendered on profiles and search cards.

---

## 🛠️ Installation & Running

### 1. Setting Up the Backend Server

1. Navigate to the backend directory:
   ```bash
   cd c:\devlopment\social-app\backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Boot up the PostgreSQL and Redis containers:
   ```bash
   docker-compose up -d
   ```
4. Start the development server (runs nodemon for auto-reload):
   ```bash
   npm run dev
   ```
5. Tunnel the API for mobile device testing:
   ```bash
   ./start_ngrok.sh
   ```
   *(Copy the generated HTTPS address, e.g., `https://resistant-fondly-stylized.ngrok-free.dev`)*

---

### 2. Setting Up the Flutter Application

1. Navigate to the Flutter project directory:
   ```bash
   cd c:\devlopment\social_app
   ```
2. Open the `.env` file and configure the backend endpoints using your ngrok URL:
   ```env
   EXPO_PUBLIC_API_URL=https://<your-ngrok-subdomain>.ngrok-free.dev
   EXPO_PUBLIC_WS_URL=wss://<your-ngrok-subdomain>.ngrok-free.dev
   ```
3. Get package dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   * **Web target**:
     ```bash
     flutter run -d chrome
     ```
   * **Android target**:
     ```bash
     flutter run -d <device_id>
     ```

---

## 📦 Production Web Bundle Compilation

To build the final optimized web bundle for production deployments, run:
```bash
flutter build web
```
The compiled files ready for server deployment will be generated under:
`build/web/`
