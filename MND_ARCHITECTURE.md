# MND — University Bus Routing System Architecture

**MND is a real-time multimodal route planning platform for SUST (Shahjalal University of Science and Technology) students in Sylhet, Bangladesh.** It combines university bus schedules with local transport options (CNG/rickshaw/walking) to find the optimal route from any city location to campus. Think Google Maps, but hyper-focused on a student's commute—with actual bus timings, fare estimates, and smart fallbacks when the bus doesn't go directly to your pickup point.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Backend Architecture](#backend-architecture)
   - [Graph Data Model](#graph-data-model)
   - [Route Planning Algorithm](#route-planning-algorithm)
   - [API Endpoints](#api-endpoints)
   - [Distance Matrix Integration](#distance-matrix-integration)
3. [Data Layer (JSON "Database")](#data-layer-json-database)
   - [nodes.json](#nodesjson)
   - [edges.json](#edgesjson)
   - [routes.json](#routesjson)
4. [Flutter Frontend Architecture](#flutter-frontend-architecture)
   - [Services Layer](#services-layer)
   - [Data Flow](#data-flow)
   - [State Management](#state-management)
5. [Maps & Visualization](#maps--visualization)
6. [Authentication System](#authentication-system)
7. [API Request/Response Flow](#api-requestresponse-flow)
8. [Tech Stack Summary](#tech-stack-summary)

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              MND SYSTEM                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌──────────────┐         HTTP/REST          ┌─────────────────────────┐   │
│   │              │ ◄─────────────────────────► │                         │   │
│   │   FLUTTER    │                             │    NODE.JS BACKEND      │   │
│   │     APP      │         JSON Payload        │                         │   │
│   │              │ ◄─────────────────────────► │   - Express Server      │   │
│   │  - Android   │                             │   - Graph Engine        │   │
│   │  - iOS       │                             │   - Route Planner       │   │
│   │  - Web       │                             │                         │   │
│   │              │                             └───────────┬─────────────┘   │
│   └──────┬───────┘                                         │                 │
│          │                                                 │                 │
│          │ Google Maps SDK                                 │ Google APIs     │
│          │ (Rendering)                                     │ (Data)          │
│          ▼                                                 ▼                 │
│   ┌──────────────┐                             ┌─────────────────────────┐   │
│   │   GOOGLE     │                             │   JSON DATA FILES       │   │
│   │  DIRECTIONS  │                             │                         │   │
│   │     API      │                             │   - nodes.json (19)     │   │
│   │              │                             │   - edges.json (3074)   │   │
│   │  (Polylines) │                             │   - routes.json (7)     │   │
│   └──────────────┘                             └─────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Backend Architecture

The backend is a **Node.js/Express** server that implements a graph-based route planning engine.

### File Structure

```
MND-backend/src/
├── server.ts              # Express app, middleware, route registration
├── api/
│   ├── routesController.ts    # /api/routes, /api/nodes endpoints
│   ├── authController.ts      # Magic link auth endpoints
│   ├── favoritesController.ts # User favorites CRUD
│   ├── upcomingController.ts  # Bus schedule queries
│   └── validation.ts          # Request validation middleware
├── core/
│   ├── graph.ts           # Graph data structure & Dijkstra implementation
│   ├── planner.ts         # Multi-modal route planning logic
│   └── types.ts           # TypeScript interfaces
├── data/
│   ├── nodes.json         # 19 locations in Sylhet
│   ├── edges.json         # 3074 connections between nodes
│   └── routes.json        # 7 bus routes with schedules
└── infra/
    └── distanceMatrixClient.ts  # Google Distance Matrix API wrapper
```

### Graph Data Model

The city is modeled as a **weighted directed graph**:

- **Nodes** = Physical locations (bus stops, intersections)
- **Edges** = Connections with travel time, cost, and transport mode
- **Routes** = Bus schedules with stops and departure times

```typescript
// Adjacency List Structure
adjacencyList: {
  "TILAGOR": [
    { to: "SHIBGONJ", mode: "bus", route_ids: ["bus1", "bus2"], time_min: 6, cost: 0 },
    { to: "SHIBGONJ", mode: "local", time_min: 8, cost: 30 },
    { to: "SHIBGONJ", mode: "walk", time_min: 25, cost: 0 }
  ],
  "SHIBGONJ": [...],
  ...
}
```

### Route Planning Algorithm

The `RoutePlanner` class in `planner.ts` implements **four strategies**:

| Strategy | Description | Example |
|----------|-------------|---------|
| **Direct Bus** | Single bus from origin → destination | Tilagor → Campus on Bus 1 |
| **Bus + Local** | Bus as far as possible, then CNG/walk | Bus to Ambarkhana, CNG to Chowhatta |
| **Transfer** | Multiple buses with connection | Bus 1 to Subidbazar, then Bus 5 |
| **Local Only** | Walk/CNG when no bus available | Dijkstra shortest path |

```typescript
async planRoute(from, to, requestTime) {
  // 1. Try direct bus on each route
  for (route of allRoutes) {
    directOption = await this.directBusRoute(route, from, to, requestTime);
  }
  
  // 2. Try bus + local hybrid
  for (route of allRoutes) {
    hybridOption = await this.busToLocalRoute(route, from, to, requestTime);
  }
  
  // 3. Try multi-leg transfers
  transferOptions = await this.findTransferRoutes(from, to, requestTime);
  
  // 4. Local-only fallback (Dijkstra)
  localOption = await this.localOnlyRoute(from, to);
  
  // 5. Rank and return options
  return this.compareRoutes(allOptions);
}
```

**Dijkstra's Algorithm** is used for local-only paths:

```typescript
localShortestPath(from: string, to: string, allowedModes: ['walk', 'local']) {
  // Standard Dijkstra with priority queue
  // Returns shortest path by time, respecting mode constraints
}
```

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/health` | GET | System status, node/route counts, API usage |
| `/api/nodes` | GET | List all 19 locations |
| `/api/routes/list` | GET | List all 7 bus routes |
| `/api/routes` | GET | **Main route planning** - takes `from`, `to`, `time` |
| `/api/buses/upcoming` | GET | Next buses from a stop |
| `/api/buses/schedule/:routeId` | GET | Full schedule for a bus |
| `/api/auth/send-link` | POST | Send magic link email |
| `/api/auth/verify` | GET | Verify magic link token |
| `/api/favorites` | GET/POST/DELETE | User saved routes |

### Distance Matrix Integration

For segments not in the graph (rare routes), the system falls back to **Google Distance Matrix API**:

```typescript
class DistanceMatrixClient {
  // Quota management (700/month, 50/day)
  private MONTHLY_LIMIT = 700;
  private DAILY_LIMIT = 50;
  
  // 7-day caching to minimize API calls
  private cache: Map<string, CacheEntry>;
  
  async getLocalSegment(originNodeId, destNodeId, mode) {
    // 1. Check cache
    // 2. Check quota
    // 3. Get node addresses from graph
    // 4. Call Google API
    // 5. Cache result
    return { distanceMeters, durationSeconds };
  }
}
```

---

## Data Layer (JSON "Database")

Instead of a traditional database, MND uses **JSON files** for simplicity and hackathon speed. This is sufficient for the ~20 nodes and static bus schedules.

### nodes.json

19 physical locations in Sylhet city:

```json
[
  {
    "id": "TILAGOR",
    "name": "Tilagor",
    "type": "stop",
    "gmaps_address": "Tilagor, Sylhet, Bangladesh"
  },
  {
    "id": "CAMPUS",
    "name": "Campus",
    "type": "stop",
    "gmaps_address": "Shahjalal University of Science and Technology, Sylhet, Bangladesh"
  },
  {
    "id": "AMBARKHANA",
    "name": "Ambarkhana",
    "type": "intersection",
    "gmaps_address": "Ambarkhana, Sylhet, Bangladesh"
  }
  // ... 16 more nodes
]
```

**Node Types:**
- `stop` - Bus pickup/dropoff point
- `intersection` - Major junction (transfer point)

### edges.json

3074 connections between nodes (bus, local, walk):

```json
[
  {
    "from": "TILAGOR",
    "to": "SHIBGONJ",
    "mode": "bus",
    "route_ids": ["bus1", "bus2"],
    "time_min": 6,
    "distance_meters": 2046,
    "cost": 0,
    "one_way": false,
    "source": "distance_matrix"
  },
  {
    "from": "AMBARKHANA",
    "to": "SUBIDBAZAR",
    "mode": "local",
    "time_min": 5,
    "cost": 20,
    "one_way": false
  }
]
```

**Transport Modes:**
| Mode | Description | Cost |
|------|-------------|------|
| `bus` | University shuttle | Free (0 BDT) |
| `local` | CNG/rickshaw | ~20-50 BDT |
| `walk` | Walking | Free |

### routes.json

7 university bus routes with schedules:

```json
{
  "route_id": "bus1",
  "name": "Bus 1",
  "trips": [
    {
      "trip_id": "bus1_0825",
      "direction": "to_campus",
      "stops": ["TILAGOR", "SHIBGONJ", "NAIORPUL", "KUMARPARA", 
                "SHAHI_EIDGAH", "AMBARKHANA", "SUBIDBAZAR", 
                "PATHANTULA", "MODINA_MARKET", "CAMPUS"],
      "departure_time": "08:25"
    },
    {
      "trip_id": "bus1_1710",
      "direction": "from_campus",
      "stops": ["CAMPUS", "SUBIDBAZAR", "AMBARKHANA", ...],
      "departure_time": "17:10"
    }
  ]
}
```

---

## Flutter Frontend Architecture

The mobile app is built with **Flutter** using a clean service-based architecture.

### File Structure

```
mnd_flutter/lib/
├── main.dart                 # App entry, dotenv loading
├── config/
│   ├── api_config.dart       # Base URL, timeouts, API keys
│   └── app_theme.dart        # Material theme
├── models/
│   ├── node.dart             # Location model
│   ├── route_option.dart     # Route result model
│   ├── route_leg.dart        # Single leg (bus/walk segment)
│   ├── bus_schedule.dart     # Schedule model
│   ├── favorite.dart         # Saved route model
│   └── user.dart             # User profile model
├── services/
│   ├── api_service.dart      # HTTP client with auth
│   ├── route_service.dart    # Route planning calls
│   ├── auth_service.dart     # Magic link auth
│   ├── bus_service.dart      # Schedule queries
│   ├── favorites_service.dart
│   └── directions_service.dart  # Google Directions API
├── providers/
│   └── auth_provider.dart    # Auth state (ChangeNotifier)
├── screens/
│   ├── home/                 # Main route planning screen
│   ├── buses/                # Bus schedules
│   ├── favorites/            # Saved routes
│   ├── auth/                 # Login screens
│   ├── profile/              # User profile
│   └── route_map/            # Map visualization
└── widgets/
    ├── route_card.dart       # Route option display
    └── ...
```

### Services Layer

**ApiService** - Base HTTP client:

```dart
class ApiService {
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? params}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint')
        .replace(queryParameters: params);
    
    final headers = await _buildHeaders();  // Adds auth token if available
    final response = await _client.get(uri, headers: headers)
        .timeout(ApiConfig.timeout);
    
    return json.decode(response.body);
  }
}
```

**RouteService** - Route planning:

```dart
class RouteService {
  final ApiService _api = ApiService();

  Future<List<RouteOption>> planRoute({
    required String from,
    required String to,
    required String time,
  }) async {
    final data = await _api.get('/routes', params: {
      'from': from,
      'to': to,
      'time': time,
    });
    
    return (data['options'] as List)
        .map((option) => RouteOption.fromJson(option))
        .toList();
  }
}
```

**DirectionsService** - Google polylines for map:

```dart
class DirectionsService {
  static Future<DirectionsResult?> getDirections({
    required String origin,      // "Tilagor, Sylhet, Bangladesh"
    required String destination, // "Ambarkhana, Sylhet, Bangladesh"
  }) async {
    final url = Uri.parse(
      '$_baseUrl?origin=${Uri.encodeComponent(origin)}'
      '&destination=${Uri.encodeComponent(destination)}'
      '&mode=driving'
      '&key=${ApiConfig.googleMapsApiKey}',
    );
    
    final response = await http.get(url);
    final data = json.decode(response.body);
    
    // Decode polyline and return LatLng points
    return DirectionsResult(
      polylinePoints: _decodePolyline(data['routes'][0]['overview_polyline']['points']),
      bounds: LatLngBounds(...),
      distanceMeters: ...,
      durationSeconds: ...,
    );
  }
}
```

### Data Flow

```
User Input (from, to, time)
         │
         ▼
┌─────────────────────┐
│   RouteService      │
│   planRoute()       │
└──────────┬──────────┘
           │ HTTP GET /api/routes?from=X&to=Y&time=Z
           ▼
┌─────────────────────┐
│   Backend           │
│   RoutePlanner      │
│   planRoute()       │
└──────────┬──────────┘
           │ JSON Response
           ▼
┌─────────────────────┐
│   RouteOption       │
│   List<RouteLeg>    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   RouteCard Widget  │
│   (UI Display)      │
└──────────┬──────────┘
           │ User taps map icon
           ▼
┌─────────────────────┐
│   RouteMapScreen    │
│   DirectionsService │
│   GoogleMap widget  │
└─────────────────────┘
```

### State Management

Using **Provider** with `ChangeNotifier`:

```dart
class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  bool get isAuthenticated => _user != null;
  
  Future<void> login(String email) async {
    _isLoading = true;
    notifyListeners();
    
    await _authService.sendMagicLink(email);
    
    _isLoading = false;
    notifyListeners();
  }
}
```

---

## Maps & Visualization

The map feature visualizes planned routes with **color-coded polylines**:

| Mode | Color | Hex |
|------|-------|-----|
| Bus | Blue | `#4285F4` |
| Local/CNG | Orange | `#FF9800` |
| Walking | Green | `#4CAF50` |

**How it works:**

1. User taps map icon on a `RouteCard`
2. `RouteMapScreen` receives the `RouteOption` with its `legs`
3. For each leg, we call Google Directions API with the `gmaps_address` from nodes
4. Polylines are decoded and drawn on `GoogleMap` widget
5. Markers placed at start/end points

```dart
for (final leg in widget.routeOption.legs) {
  final directions = await DirectionsService.getDirections(
    origin: '${leg.from}, Sylhet, Bangladesh',
    destination: '${leg.to}, Sylhet, Bangladesh',
  );
  
  polylines.add(Polyline(
    polylineId: PolylineId('leg_$index'),
    points: directions.polylinePoints,
    color: _getModeColor(leg.mode),  // Blue/Orange/Green
    width: 5,
  ));
}
```

---

## Authentication System

MND uses **magic link authentication** (passwordless):

```
1. User enters email
2. Backend generates token, stores with expiry
3. Email sent with link: /auth/verify?token=xyz
4. User clicks link
5. Backend validates token, returns JWT
6. Flutter stores JWT in SharedPreferences
7. All subsequent requests include Authorization header
```

```typescript
// Backend - authController.ts
async function sendMagicLink(req, res) {
  const token = crypto.randomBytes(32).toString('hex');
  magicTokens.set(token, { email, expiresAt: Date.now() + 15*60*1000 });
  
  await sendEmail(email, `Click to login: ${BASE_URL}/auth/verify?token=${token}`);
}

async function verifyMagicLink(req, res) {
  const { token } = req.query;
  const data = magicTokens.get(token);
  
  if (!data || Date.now() > data.expiresAt) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
  
  const jwt = generateJWT({ email: data.email });
  return res.json({ token: jwt, user: { email: data.email } });
}
```

---

## API Request/Response Flow

### Example: Planning a Route

**Request:**
```http
GET /api/routes?from=TILAGOR&to=CAMPUS&time=08:00
```

**Response:**
```json
{
  "from": "TILAGOR",
  "to": "CAMPUS",
  "requestTime": "08:00",
  "options": [
    {
      "label": "Bus 1 Direct",
      "category": "fastest",
      "type": "direct",
      "transfers": 0,
      "totalTimeMin": 45,
      "totalCost": 0,
      "localTimeMin": 0,
      "localDistanceMeters": 0,
      "legs": [
        {
          "mode": "bus",
          "route_id": "bus1",
          "trip_id": "bus1_0825",
          "from": "TILAGOR",
          "to": "CAMPUS",
          "departure": "08:25",
          "arrival": "09:10",
          "durationMin": 45,
          "cost": 0
        }
      ]
    },
    {
      "label": "Bus 1 + Local",
      "category": "alternative",
      "type": "hybrid",
      "transfers": 1,
      "totalTimeMin": 35,
      "totalCost": 30,
      "localTimeMin": 10,
      "localDistanceMeters": 1500,
      "legs": [
        {
          "mode": "bus",
          "from": "TILAGOR",
          "to": "SUBIDBAZAR",
          "departure": "08:25",
          "arrival": "08:50",
          "durationMin": 25,
          "cost": 0
        },
        {
          "mode": "local",
          "from": "SUBIDBAZAR",
          "to": "CAMPUS",
          "durationMin": 10,
          "cost": 30
        }
      ]
    },
    {
      "label": "Local Only",
      "category": "fallback",
      "type": "local",
      "totalTimeMin": 40,
      "totalCost": 120,
      "legs": [
        {
          "mode": "local",
          "from": "TILAGOR",
          "to": "CAMPUS",
          "durationMin": 40,
          "cost": 120
        }
      ]
    }
  ]
}
```

---

## Tech Stack Summary

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Frontend** | Flutter 3.x | Cross-platform mobile app |
| **State** | Provider | Reactive state management |
| **Maps** | google_maps_flutter | Map rendering |
| **Directions** | Google Directions API | Route polylines |
| **Backend** | Node.js + Express | REST API server |
| **Language** | TypeScript | Type-safe backend |
| **Database** | JSON files | Static data storage |
| **Algorithm** | Dijkstra | Shortest path finding |
| **Auth** | JWT + Magic Links | Passwordless authentication |
| **External API** | Google Distance Matrix | Real-time travel estimates |
| **Environment** | dotenv | Secret management |

---

## Why This Architecture?

1. **Hackathon-Friendly**: JSON files instead of database = zero setup time
2. **Offline-Capable**: Static schedules don't need constant internet
3. **Cost-Efficient**: Aggressive caching of Google API calls (700/month limit)
4. **Scalable Logic**: Graph structure supports easy addition of new routes
5. **Cross-Platform**: Single Flutter codebase for Android/iOS/Web
6. **Type-Safe**: TypeScript backend catches errors at compile time

---

*Built for SUST students who just want to catch the bus on time.* 🚌
